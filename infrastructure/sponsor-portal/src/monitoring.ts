/**
 * Monitoring and Alerting Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Creates:
 * - Uptime checks for portal availability
 * - Alert policies for error rates and downtime
 * - Cloud SQL CPU and storage alerts
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName } from "./config";

export interface MonitoringResources {
    uptimeCheck: gcp.monitoring.UptimeCheckConfig;
    errorRateAlert: gcp.monitoring.AlertPolicy;
    dbCpuAlert?: gcp.monitoring.AlertPolicy;
    dbStorageAlert?: gcp.monitoring.AlertPolicy;
}

/**
 * Monitoring configuration options
 */
export interface MonitoringConfig {
    /** Enable Cloud SQL alerts (default: true) */
    enableDbAlerts?: boolean;
    /** CPU utilization threshold percentage (default: 80) */
    dbCpuThreshold?: number;
    /** Storage utilization threshold percentage (default: 80) */
    dbStorageThreshold?: number;
}

/**
 * Create monitoring and alerting resources
 */
export function createMonitoring(
    config: StackConfig,
    service: gcp.cloudrun.Service,
    dbInstance?: gcp.sql.DatabaseInstance,
    monitoringConfig?: MonitoringConfig
): MonitoringResources {
    const uptimeCheckName = resourceName(config, "uptime-check");
    const alertPolicyName = resourceName(config, "error-alert");
    const enableDbAlerts = monitoringConfig?.enableDbAlerts ?? true;
    const dbCpuThreshold = monitoringConfig?.dbCpuThreshold ?? 80;
    const dbStorageThreshold = monitoringConfig?.dbStorageThreshold ?? 80;

    // Create uptime check
    const uptimeCheck = new gcp.monitoring.UptimeCheckConfig(uptimeCheckName, {
        displayName: `Portal Uptime Check (${config.sponsor} ${config.environment})`,
        timeout: "10s",
        period: "60s", // Check every 60 seconds
        project: config.project,

        httpCheck: {
            path: "/health",
            port: 443,
            useSsl: true,
            validateSsl: true,
        },

        monitoredResource: {
            type: "uptime_url",
            labels: {
                project_id: config.project,
                host: config.domainName,
            },
        },

        contentMatchers: [
            {
                content: "OK",
                matcher: "CONTAINS_STRING",
            },
        ],
    });

    // Create alert policy for high error rate
    const errorRateAlert = new gcp.monitoring.AlertPolicy(alertPolicyName, {
        displayName: `Portal Error Rate Alert (${config.sponsor} ${config.environment})`,
        project: config.project,
        combiner: "OR",

        conditions: [
            {
                displayName: "Cloud Run Error Rate > 5%",
                conditionThreshold: {
                    filter: pulumi.interpolate`
                        resource.type="cloud_run_revision" AND
                        resource.labels.service_name="${service.name}" AND
                        metric.type="run.googleapis.com/request_count" AND
                        metric.labels.response_code_class="5xx"
                    `,
                    duration: "60s",
                    comparison: "COMPARISON_GT",
                    thresholdValue: 0.05, // 5% error rate
                    aggregations: [
                        {
                            alignmentPeriod: "60s",
                            perSeriesAligner: "ALIGN_RATE",
                        },
                    ],
                },
            },
        ],

        alertStrategy: {
            autoClose: "1800s", // Auto-close after 30 minutes
        },

        documentation: {
            content: pulumi.interpolate`
                Portal error rate exceeded 5% for ${config.sponsor} ${config.environment}.

                ## Troubleshooting Steps:
                1. Check Cloud Run logs: https://console.cloud.google.com/run/detail/${config.region}/portal/logs?project=${config.project}
                2. Verify Cloud SQL connectivity
                3. Check recent deployments for issues
                4. Consider rolling back to previous revision

                ## Escalation:
                - If error persists > 30 minutes, escalate to on-call engineer
                - Update status page if customer-facing

                Portal URL: https://${config.domainName}
            `,
            mimeType: "text/markdown",
        },
    });

    // Cloud SQL monitoring alerts
    let dbCpuAlert: gcp.monitoring.AlertPolicy | undefined;
    let dbStorageAlert: gcp.monitoring.AlertPolicy | undefined;

    if (dbInstance && enableDbAlerts) {
        // Cloud SQL High CPU Alert
        dbCpuAlert = new gcp.monitoring.AlertPolicy(
            resourceName(config, "db-cpu-alert"),
            {
                displayName: `Cloud SQL High CPU (${config.sponsor} ${config.environment})`,
                project: config.project,
                combiner: "OR",

                conditions: [
                    {
                        displayName: `CPU utilization > ${dbCpuThreshold}%`,
                        conditionThreshold: {
                            filter: pulumi.interpolate`
                                resource.type="cloudsql_database" AND
                                resource.labels.database_id="${config.project}:${dbInstance.name}" AND
                                metric.type="cloudsql.googleapis.com/database/cpu/utilization"
                            `,
                            duration: "300s", // 5 minutes
                            comparison: "COMPARISON_GT",
                            thresholdValue: dbCpuThreshold / 100, // Convert percentage to decimal
                            aggregations: [
                                {
                                    alignmentPeriod: "60s",
                                    perSeriesAligner: "ALIGN_MEAN",
                                },
                            ],
                        },
                    },
                ],

                alertStrategy: {
                    autoClose: "3600s", // Auto-close after 1 hour
                },

                documentation: {
                    content: pulumi.interpolate`
                        Cloud SQL CPU utilization exceeded ${dbCpuThreshold}% for ${config.sponsor} ${config.environment}.

                        ## Troubleshooting Steps:
                        1. Check active queries: Cloud Console → SQL → Instance → Query Insights
                        2. Look for long-running queries or locks
                        3. Consider scaling up the database tier
                        4. Review connection pool settings

                        ## Instance Details:
                        - Instance: ${dbInstance.name}
                        - Project: ${config.project}
                        - Console: https://console.cloud.google.com/sql/instances/${dbInstance.name}/overview?project=${config.project}
                    `,
                    mimeType: "text/markdown",
                },
            }
        );

        // Cloud SQL High Storage Alert
        dbStorageAlert = new gcp.monitoring.AlertPolicy(
            resourceName(config, "db-storage-alert"),
            {
                displayName: `Cloud SQL High Storage (${config.sponsor} ${config.environment})`,
                project: config.project,
                combiner: "OR",

                conditions: [
                    {
                        displayName: `Disk utilization > ${dbStorageThreshold}%`,
                        conditionThreshold: {
                            filter: pulumi.interpolate`
                                resource.type="cloudsql_database" AND
                                resource.labels.database_id="${config.project}:${dbInstance.name}" AND
                                metric.type="cloudsql.googleapis.com/database/disk/utilization"
                            `,
                            duration: "300s", // 5 minutes
                            comparison: "COMPARISON_GT",
                            thresholdValue: dbStorageThreshold / 100, // Convert percentage to decimal
                            aggregations: [
                                {
                                    alignmentPeriod: "60s",
                                    perSeriesAligner: "ALIGN_MEAN",
                                },
                            ],
                        },
                    },
                ],

                alertStrategy: {
                    autoClose: "3600s", // Auto-close after 1 hour
                },

                documentation: {
                    content: pulumi.interpolate`
                        Cloud SQL disk utilization exceeded ${dbStorageThreshold}% for ${config.sponsor} ${config.environment}.

                        ## Immediate Actions:
                        1. Check if autoresize is enabled (should be)
                        2. Review disk size limits
                        3. Consider archiving old data
                        4. Check for bloated tables/indexes (VACUUM FULL)

                        ## Instance Details:
                        - Instance: ${dbInstance.name}
                        - Project: ${config.project}
                        - Console: https://console.cloud.google.com/sql/instances/${dbInstance.name}/overview?project=${config.project}

                        ## Note:
                        If autoresize is enabled, disk will automatically expand.
                        Monitor costs and set appropriate disk size limits.
                    `,
                    mimeType: "text/markdown",
                },
            }
        );
    }

    return {
        uptimeCheck,
        errorRateAlert,
        dbCpuAlert,
        dbStorageAlert,
    };
}
