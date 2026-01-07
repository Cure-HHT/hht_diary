/**
 * Audit Log Infrastructure for Bootstrap Projects
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Creates tamper-evident audit log storage with 25-year retention for
 * FDA 21 CFR Part 11 compliance in each sponsor project.
 *
 * Captures:
 * - Who performed actions (user identity/principal)
 * - What actions were performed (API calls)
 * - When actions occurred (timestamps)
 * - Source IP addresses
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { BootstrapConfig, Environment, ENVIRONMENTS } from "./config";
import { ProjectResult } from "./projects";

/**
 * Audit log configuration
 */
export interface AuditLogConfig {
    /** Retention period in years (default: 25 for FDA compliance) */
    retentionYears: number;
    /** Lock the retention policy (prevents shortening/removal) */
    lockRetentionPolicy: boolean;
    /** Include Data Access logs (verbose, higher cost) */
    includeDataAccessLogs: boolean;
}

/**
 * Default audit log configuration for FDA 21 CFR Part 11 compliance
 */
export const DEFAULT_AUDIT_CONFIG: AuditLogConfig = {
    retentionYears: 25,
    lockRetentionPolicy: true,
    includeDataAccessLogs: true,
};

/**
 * Result of audit log creation for a single project
 */
export interface ProjectAuditResult {
    environment: Environment;
    bucket: gcp.storage.Bucket;
    sink: gcp.logging.ProjectSink;
}

/**
 * Result of audit log creation for all projects
 */
export interface AuditLogResult {
    projectAudits: Map<Environment, ProjectAuditResult>;
}

/**
 * Create audit log infrastructure for a single project
 */
function createProjectAuditLogs(
    config: BootstrapConfig,
    project: ProjectResult,
    auditConfig: AuditLogConfig
): ProjectAuditResult {
    const env = project.environment;
    const retentionSeconds = auditConfig.retentionYears * 365 * 24 * 60 * 60;

    // Create audit log bucket with locked retention policy
    const bucketName = `${config.projectPrefix}-${config.sponsor}-${env}-audit-logs`;
    const bucket = new gcp.storage.Bucket(
        bucketName,
        {
            name: bucketName,
            project: project.projectId,
            location: config.defaultRegion,
            uniformBucketLevelAccess: true,
            labels: {
                ...config.labels,
                environment: env,
                purpose: "fda-audit-trail",
                retention_years: auditConfig.retentionYears.toString(),
            },

            // Retention policy - objects cannot be deleted until retention period expires
            retentionPolicy: {
                retentionPeriod: retentionSeconds,
                isLocked: auditConfig.lockRetentionPolicy,
            },

            // Enable versioning for additional protection
            versioning: {
                enabled: true,
            },

            // Soft delete provides additional recovery window
            softDeletePolicy: {
                retentionDurationSeconds: 30 * 24 * 60 * 60, // 30 days
            },

            // Lifecycle rules: Move to cheaper storage over time
            lifecycleRules: [
                {
                    condition: { age: 90 },
                    action: { type: "SetStorageClass", storageClass: "COLDLINE" },
                },
                {
                    condition: { age: 365 },
                    action: { type: "SetStorageClass", storageClass: "ARCHIVE" },
                },
            ],
        },
        { dependsOn: project.apis }
    );

    // Build log filter for Cloud Audit Logs
    const logFilterParts = [
        'logName:"cloudaudit.googleapis.com"',
        'protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"',
    ];

    if (!auditConfig.includeDataAccessLogs) {
        logFilterParts.push('logName!~"data_access"');
    }

    const logFilter = logFilterParts.join(" AND ");

    // Create log sink to export audit logs to Cloud Storage
    const sinkName = `${config.sponsor}-${env}-audit-log-sink`;
    const sink = new gcp.logging.ProjectSink(
        sinkName,
        {
            name: sinkName,
            project: project.projectId,
            destination: pulumi.interpolate`storage.googleapis.com/${bucket.name}`,
            filter: logFilter,
            uniqueWriterIdentity: true,
            description: `FDA 21 CFR Part 11 compliant audit log export (${auditConfig.retentionYears}-year retention)`,
        },
        { dependsOn: project.apis }
    );

    // Grant the log sink's service account permission to write to the bucket
    new gcp.storage.BucketIAMMember(
        `${sinkName}-writer`,
        {
            bucket: bucket.name,
            role: "roles/storage.objectCreator",
            member: sink.writerIdentity,
        }
    );

    return {
        environment: env,
        bucket,
        sink,
    };
}

/**
 * Create audit log infrastructure for all sponsor projects
 *
 * Sets up 25-year retention audit logs in each of the 4 environment projects
 * (dev, qa, uat, prod) for FDA 21 CFR Part 11 compliance.
 *
 * @param config Bootstrap configuration
 * @param projects Map of environment to project result
 * @param auditConfig Audit configuration (defaults to 25-year locked retention)
 */
export function createSponsorAuditLogs(
    config: BootstrapConfig,
    projects: Map<Environment, ProjectResult>,
    auditConfig: AuditLogConfig = DEFAULT_AUDIT_CONFIG
): AuditLogResult {
    const projectAudits = new Map<Environment, ProjectAuditResult>();

    for (const env of ENVIRONMENTS) {
        const project = projects.get(env);
        if (!project) {
            throw new Error(`Project not found for environment: ${env}`);
        }

        pulumi.log.info(`Creating audit log infrastructure for ${config.sponsor}-${env}`);
        const auditResult = createProjectAuditLogs(config, project, auditConfig);
        projectAudits.set(env, auditResult);
    }

    return { projectAudits };
}

/**
 * Get audit log outputs for export
 */
export function getAuditLogOutputs(
    config: BootstrapConfig,
    auditResult: AuditLogResult
): { [key: string]: pulumi.Output<string> | string | number } {
    const outputs: { [key: string]: pulumi.Output<string> | string | number } = {
        auditLogRetentionYears: DEFAULT_AUDIT_CONFIG.retentionYears,
        auditLogRetentionLocked: DEFAULT_AUDIT_CONFIG.lockRetentionPolicy.toString(),
    };

    for (const [env, audit] of auditResult.projectAudits) {
        outputs[`${env}AuditLogBucket`] = audit.bucket.name;
    }

    return outputs;
}
