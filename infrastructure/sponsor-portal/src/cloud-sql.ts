/**
 * Cloud SQL PostgreSQL Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00013: PostgreSQL database with RLS
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Creates Cloud SQL instance with:
 * - PostgreSQL 15 database
 * - Private VPC networking (no public IP)
 * - Automated backups with point-in-time recovery
 * - High availability (for prod)
 * - pgaudit for FDA compliance audit logging
 * - Query insights for performance monitoring
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName, resourceLabels } from "./config";
import { VpcResult } from "./vpc";

/**
 * Cloud SQL configuration options
 */
export interface CloudSqlConfig {
    /** Database tier (default based on environment) */
    tier?: string;
    /** Initial disk size in GB */
    diskSizeGb?: number;
    /** Max disk size for autoresize in GB */
    maxDiskSizeGb?: number;
    /** Number of backups to retain */
    backupRetentionCount?: number;
    /** Enable public IP (false = VPC only, recommended) */
    enablePublicIp?: boolean;
}

/**
 * Create Cloud SQL PostgreSQL instance
 *
 * @param config Stack configuration
 * @param vpc VPC network result (for private IP connectivity)
 * @param sqlConfig Optional Cloud SQL configuration overrides
 */
export function createCloudSqlInstance(
    config: StackConfig,
    vpc?: VpcResult,
    sqlConfig?: CloudSqlConfig
): gcp.sql.DatabaseInstance {
    const instanceName = resourceName(config, "db");
    const labels = resourceLabels(config);

    // Determine tier based on environment
    const tier = sqlConfig?.tier ||
        (config.environment === "production" ? "db-custom-2-8192" : "db-f1-micro");
    const availabilityType = config.environment === "production" ? "REGIONAL" : "ZONAL";

    // Disk configuration
    const diskSize = sqlConfig?.diskSizeGb ||
        (config.environment === "production" ? 100 : 10);
    const maxDiskSize = sqlConfig?.maxDiskSizeGb ||
        (config.environment === "production" ? 500 : 50);

    // Backup retention
    const backupRetention = sqlConfig?.backupRetentionCount ||
        (config.environment === "production" ? 30 : 7);

    // IP configuration - prefer private IP via VPC
    const enablePublicIp = sqlConfig?.enablePublicIp ?? (vpc === undefined);

    const instance = new gcp.sql.DatabaseInstance(instanceName, {
        name: instanceName,
        databaseVersion: "POSTGRES_15",
        region: config.region,
        project: config.project,
        settings: {
            tier: tier,
            availabilityType: availabilityType,
            diskType: "PD_SSD",
            diskSize: diskSize,
            diskAutoresize: true,
            diskAutoresizeLimit: maxDiskSize,

            // Backup configuration (required for FDA compliance)
            backupConfiguration: {
                enabled: true,
                startTime: "02:00", // 2 AM UTC
                pointInTimeRecoveryEnabled: true,
                transactionLogRetentionDays: 7,
                backupRetentionSettings: {
                    retainedBackups: backupRetention,
                },
            },

            // IP configuration - private IP via VPC when available
            ipConfiguration: {
                ipv4Enabled: enablePublicIp,
                privateNetwork: vpc?.network.id,
                requireSsl: true,
            },

            // Maintenance window (Sunday 3 AM UTC)
            maintenanceWindow: {
                day: 7,
                hour: 3,
            },

            // Database flags for FDA compliance and security
            databaseFlags: [
                // Enable pgaudit for audit logging (FDA 21 CFR Part 11)
                { name: "cloudsql.enable_pgaudit", value: "on" },
                // Log all connections for audit trail
                { name: "log_connections", value: "on" },
                // Log all disconnections for audit trail
                { name: "log_disconnections", value: "on" },
                // Log checkpoints for performance monitoring
                { name: "log_checkpoints", value: "on" },
                // Log lock waits for debugging
                { name: "log_lock_waits", value: "on" },
                // Log statements taking longer than 1 second
                { name: "log_min_duration_statement", value: "1000" },
            ],

            // Query insights for performance monitoring
            insightsConfig: {
                queryInsightsEnabled: true,
                queryPlansPerMinute: 5,
                queryStringLength: 4096,
                recordApplicationTags: true,
                recordClientAddress: true,
            },

            // User labels for organization
            userLabels: labels,
        },
        deletionProtection: config.environment === "production",
    }, {
        dependsOn: vpc ? [vpc.privateVpcConnection] : undefined,
    });

    // Create database
    new gcp.sql.Database(`${instanceName}-clinical-diary`, {
        name: "clinical_diary",
        instance: instance.name,
        project: config.project,
        charset: "UTF8",
        collation: "en_US.UTF8",
    });

    // Create database user
    new gcp.sql.User(`${instanceName}-app-user`, {
        name: "app_user",
        instance: instance.name,
        password: config.dbPassword,
        project: config.project,
    });

    return instance;
}
