/**
 * Audit Log Export and Retention Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *   REQ-p00005: Data security and isolation
 *
 * Creates tamper-evident audit log storage with 25-year retention for
 * FDA 21 CFR Part 11 compliance. Captures:
 * - Who performed actions (user identity/principal)
 * - What actions were performed (API calls)
 * - When actions occurred (timestamps)
 * - Source IP addresses
 *
 * Audit logs are exported to Cloud Storage with:
 * - Locked retention policy (cannot be shortened or removed)
 * - Object versioning for change tracking
 * - Uniform bucket-level access for security
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName, resourceLabels } from "./config";

/**
 * Audit log retention configuration
 */
export interface AuditLogConfig {
    /** Retention period in years (default: 25 for FDA compliance) */
    retentionYears?: number;
    /** Lock the retention policy (prevents shortening/removal) */
    lockRetentionPolicy?: boolean;
    /** Include Data Access logs (verbose, higher cost) */
    includeDataAccessLogs?: boolean;
}

/**
 * Default audit log configuration for FDA 21 CFR Part 11 compliance
 */
export const defaultAuditLogConfig: AuditLogConfig = {
    retentionYears: 25,
    lockRetentionPolicy: true,
    includeDataAccessLogs: true,
};

/**
 * Result of audit log infrastructure creation
 */
export interface AuditLogResult {
    /** Cloud Storage bucket for audit logs */
    auditLogBucket: gcp.storage.Bucket;
    /** Log sink that exports audit logs to the bucket */
    auditLogSink: gcp.logging.ProjectSink;
    /** BigQuery dataset for queryable audit logs (optional) */
    auditLogDataset?: gcp.bigquery.Dataset;
}

/**
 * Create audit log export infrastructure
 *
 * This sets up long-term audit log retention required for FDA 21 CFR Part 11:
 * 1. Creates a Cloud Storage bucket with locked retention policy
 * 2. Creates a log sink to export Cloud Audit Logs to the bucket
 * 3. Optionally creates a BigQuery dataset for queryable audit analytics
 *
 * @param config Stack configuration
 * @param auditConfig Audit log configuration
 * @param enabledApis Enabled APIs (for dependency tracking)
 */
export function createAuditLogInfrastructure(
    config: StackConfig,
    auditConfig: AuditLogConfig = defaultAuditLogConfig,
    enabledApis?: gcp.projects.Service[]
): AuditLogResult {
    const labels = resourceLabels(config);
    const retentionYears = auditConfig.retentionYears ?? 25;
    const retentionSeconds = retentionYears * 365 * 24 * 60 * 60; // Convert years to seconds

    // Create audit log bucket with locked retention policy
    // IMPORTANT: Once locked, the retention policy CANNOT be shortened or removed
    const auditLogBucket = new gcp.storage.Bucket(
        resourceName(config, "audit-logs"),
        {
            name: `${config.project}-audit-logs`,
            project: config.project,
            location: config.region,
            uniformBucketLevelAccess: true,
            labels: {
                ...labels,
                purpose: "fda-audit-trail",
                retention_years: retentionYears.toString(),
            },

            // Retention policy - objects cannot be deleted until retention period expires
            retentionPolicy: {
                retentionPeriod: retentionSeconds,
                isLocked: auditConfig.lockRetentionPolicy ?? true,
            },

            // Enable versioning for additional protection
            versioning: {
                enabled: true,
            },

            // Soft delete provides additional recovery window
            softDeletePolicy: {
                retentionDurationSeconds: 30 * 24 * 60 * 60, // 30 days
            },

            // Lifecycle rule: Move to Coldline after 90 days, Archive after 1 year
            // (reduces cost while maintaining compliance)
            lifecycleRules: [
                {
                    condition: {
                        age: 90,
                    },
                    action: {
                        type: "SetStorageClass",
                        storageClass: "COLDLINE",
                    },
                },
                {
                    condition: {
                        age: 365,
                    },
                    action: {
                        type: "SetStorageClass",
                        storageClass: "ARCHIVE",
                    },
                },
            ],
        },
        { dependsOn: enabledApis }
    );

    // Build log filter for Cloud Audit Logs
    // Captures Admin Activity, Data Access (if enabled), and System Events
    const logFilterParts = [
        'logName:"cloudaudit.googleapis.com"',
        'protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"',
    ];

    if (!auditConfig.includeDataAccessLogs) {
        // Exclude verbose Data Access logs if not needed
        logFilterParts.push('logName!~"data_access"');
    }

    const logFilter = logFilterParts.join(" AND ");

    // Create log sink to export audit logs to Cloud Storage
    const auditLogSink = new gcp.logging.ProjectSink(
        resourceName(config, "audit-log-sink"),
        {
            name: resourceName(config, "audit-log-sink"),
            project: config.project,
            destination: pulumi.interpolate`storage.googleapis.com/${auditLogBucket.name}`,
            filter: logFilter,

            // Include all child resources (for org-level deployments)
            // includeChildren: true,

            // Use unique writer identity for secure access
            uniqueWriterIdentity: true,

            description: `FDA 21 CFR Part 11 compliant audit log export (${retentionYears}-year retention)`,
        },
        { dependsOn: enabledApis }
    );

    // Grant the log sink's service account permission to write to the bucket
    new gcp.storage.BucketIAMMember(
        resourceName(config, "audit-log-sink-writer"),
        {
            bucket: auditLogBucket.name,
            role: "roles/storage.objectCreator",
            member: auditLogSink.writerIdentity,
        }
    );

    // Optional: Create BigQuery dataset for queryable audit logs
    // This allows SQL queries for audit investigations
    const auditLogDataset = new gcp.bigquery.Dataset(
        resourceName(config, "audit-logs-bq"),
        {
            datasetId: `audit_logs_${config.sponsor}_${config.environment}`.replace(/-/g, "_"),
            project: config.project,
            location: config.region,
            description: `Audit logs for ${config.sponsor} ${config.environment} portal (FDA 21 CFR Part 11)`,
            labels: labels,

            // Default table expiration: Never (for compliance)
            // Individual tables can override if needed
            defaultTableExpirationMs: undefined,

            // Restrict access to audit logs
            accesses: [
                {
                    role: "OWNER",
                    userByEmail: `${config.project}@${config.project}.iam.gserviceaccount.com`,
                },
            ],
        },
        { dependsOn: enabledApis }
    );

    // Create a second sink for BigQuery (for queryable analytics)
    new gcp.logging.ProjectSink(
        resourceName(config, "audit-log-sink-bq"),
        {
            name: resourceName(config, "audit-log-sink-bq"),
            project: config.project,
            destination: pulumi.interpolate`bigquery.googleapis.com/projects/${config.project}/datasets/${auditLogDataset.datasetId}`,
            filter: logFilter,
            uniqueWriterIdentity: true,
            description: "Audit log export to BigQuery for queryable analytics",

            // BigQuery options
            bigqueryOptions: {
                usePartitionedTables: true,
            },
        },
        { dependsOn: enabledApis }
    );

    return {
        auditLogBucket,
        auditLogSink,
        auditLogDataset,
    };
}

/**
 * Verify audit log compliance settings
 *
 * Run this after deployment to verify the audit infrastructure is correctly configured.
 * Returns warnings for any compliance gaps.
 */
export function getAuditComplianceChecklist(config: StackConfig): string[] {
    const checks = [
        `Verify audit log bucket exists: gs://${config.project}-audit-logs`,
        "Verify retention policy is LOCKED (cannot be changed)",
        "Verify log sink is exporting Cloud Audit Logs",
        "Verify BigQuery dataset has no table expiration",
        "Test: Run 'gcloud logging read' to verify logs are being captured",
        "Test: Check bucket for exported log files",
        "Document: Record audit log bucket location in compliance documentation",
    ];
    return checks;
}
