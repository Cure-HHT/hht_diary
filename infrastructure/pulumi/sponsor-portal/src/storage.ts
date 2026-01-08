/**
 * Cloud Storage Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00047: Backup and recovery
 *
 * Creates Cloud Storage buckets for:
 * - Database backup exports
 * - Audit log archives
 * - Evidence record attachments (if needed)
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName, resourceLabels } from "./config";

/**
 * Storage configuration options
 */
export interface StorageConfig {
    /** Days to retain backup files before deletion */
    backupRetentionDays: number;
    /** Enable versioning on backup bucket */
    enableVersioning: boolean;
}

/**
 * Default storage configuration
 */
export const defaultStorageConfig: StorageConfig = {
    backupRetentionDays: 365,
    enableVersioning: true,
};

/**
 * Result of storage creation
 */
export interface StorageResult {
    backupBucket: gcp.storage.Bucket;
}

/**
 * Create Cloud Storage buckets
 */
export function createStorageBuckets(
    config: StackConfig,
    storageConfig: StorageConfig = defaultStorageConfig,
    enabledApis?: gcp.projects.Service[]
): StorageResult {
    const labels = resourceLabels(config);

    // Backup bucket for database exports and audit archives
    const backupBucket = new gcp.storage.Bucket(
        resourceName(config, "backups"),
        {
            name: `${config.project}-backups`,
            project: config.project,
            location: config.region,
            uniformBucketLevelAccess: true,
            labels: labels,

            // Lifecycle rule to delete old backups
            lifecycleRules: [
                {
                    condition: {
                        age: storageConfig.backupRetentionDays,
                    },
                    action: {
                        type: "Delete",
                    },
                },
            ],

            // Enable versioning for recovery
            versioning: {
                enabled: storageConfig.enableVersioning,
            },

            // Soft delete for additional protection (30 days)
            softDeletePolicy: {
                retentionDurationSeconds: 30 * 24 * 60 * 60, // 30 days
            },
        },
        { dependsOn: enabledApis }
    );

    return {
        backupBucket,
    };
}
