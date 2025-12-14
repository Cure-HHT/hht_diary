/**
 * Monitoring and Alerting Configuration
 *
 * Creates:
 * - Uptime checks for portal availability
 * - Alert policies for error rates and downtime
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName } from "./config";

export interface MonitoringResources {
    uptimeCheck: gcp.monitoring.UptimeCheckConfig;
    errorRateAlert: gcp.monitoring.AlertPolicy;
}

/**
 * Create monitoring and alerting resources
 */
export function createMonitoring(
    config: StackConfig,
    service: gcp.cloudrun.Service
): MonitoringResources {
    const uptimeCheckName = resourceName(config, "uptime-check");
    const alertPolicyName = resourceName(config, "error-alert");

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

    return {
        uptimeCheck,
        errorRateAlert,
    };
}
