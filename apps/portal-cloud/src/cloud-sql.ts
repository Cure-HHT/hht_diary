/**
 * Cloud SQL PostgreSQL Configuration
 *
 * Creates Cloud SQL instance with:
 * - PostgreSQL database
 * - Automated backups
 * - Point-in-time recovery
 * - High availability (for prod)
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName, resourceLabels } from "./config";

/**
 * Create Cloud SQL PostgreSQL instance
 */
export function createCloudSqlInstance(
    config: StackConfig,
    serviceAccount: gcp.serviceaccount.Account
): gcp.sql.DatabaseInstance {
    const instanceName = resourceName(config, "db");

    // Determine tier based on environment
    const tier = config.environment === "production" ? "db-custom-2-7680" : "db-f1-micro";
    const availabilityType = config.environment === "production" ? "REGIONAL" : "ZONAL";

    const instance = new gcp.sql.DatabaseInstance(instanceName, {
        name: instanceName,
        databaseVersion: "POSTGRES_15",
        region: config.region,
        project: config.project,
        settings: {
            tier: tier,
            availabilityType: availabilityType,
            diskType: "PD_SSD",
            diskSize: config.environment === "production" ? 100 : 10,
            diskAutoresize: true,
            diskAutoresizeLimit: config.environment === "production" ? 500 : 50,

            // Backup configuration (required for FDA compliance)
            backupConfiguration: {
                enabled: true,
                startTime: "03:00", // 3 AM UTC
                pointInTimeRecoveryEnabled: true,
                transactionLogRetentionDays: 7,
                backupRetentionSettings: {
                    retainedBackups: config.environment === "production" ? 30 : 7,
                },
            },

            // IP configuration (private IP recommended for production)
            ipConfiguration: {
                ipv4Enabled: true, // Can be disabled for VPC-only access
                requireSsl: true,
            },

            // Maintenance window
            maintenanceWindow: {
                day: 7, // Sunday
                hour: 3, // 3 AM UTC
            },

            // Insights configuration for query performance
            insightsConfig: {
                queryInsightsEnabled: true,
                queryPlansPerMinute: 5,
                queryStringLength: 1024,
                recordApplicationTags: true,
                recordClientAddress: true,
            },

            // User labels for organization
            userLabels: resourceLabels(config),
        },
        deletionProtection: config.environment === "production",
    });

    // Create database
    const database = new gcp.sql.Database(`${instanceName}-clinical-diary`, {
        name: "clinical_diary",
        instance: instance.name,
        project: config.project,
    });

    // Create database user
    const dbUser = new gcp.sql.User(`${instanceName}-app-user`, {
        name: "app_user",
        instance: instance.name,
        password: config.dbPassword,
        project: config.project,
    });

    return instance;
}
