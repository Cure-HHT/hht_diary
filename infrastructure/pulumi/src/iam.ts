/**
 * IAM Service Account Configuration
 *
 * Creates service accounts with least-privilege permissions for Cloud Run.
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName, resourceLabels } from "./config";

/**
 * Create service account for Cloud Run portal service
 */
export function createServiceAccount(config: StackConfig): gcp.serviceaccount.Account {
    const saName = resourceName(config, "portal-sa");

    const serviceAccount = new gcp.serviceaccount.Account(saName, {
        accountId: saName,
        displayName: `Portal Service Account (${config.sponsor} ${config.environment})`,
        description: "Service account for Cloud Run portal with least-privilege permissions",
        project: config.project,
    });

    // Grant Cloud SQL Client role (allows connecting to Cloud SQL)
    new gcp.projects.IAMMember(`${saName}-cloudsql-client`, {
        project: config.project,
        role: "roles/cloudsql.client",
        member: serviceAccount.email.apply(email => `serviceAccount:${email}`),
    });

    // Grant Artifact Registry Reader role (allows pulling images)
    new gcp.projects.IAMMember(`${saName}-artifact-reader`, {
        project: config.project,
        role: "roles/artifactregistry.reader",
        member: serviceAccount.email.apply(email => `serviceAccount:${email}`),
    });

    // Grant Logging Writer role (allows writing logs)
    new gcp.projects.IAMMember(`${saName}-logging-writer`, {
        project: config.project,
        role: "roles/logging.logWriter",
        member: serviceAccount.email.apply(email => `serviceAccount:${email}`),
    });

    // Grant Monitoring Metric Writer role (allows writing metrics)
    new gcp.projects.IAMMember(`${saName}-monitoring-writer`, {
        project: config.project,
        role: "roles/monitoring.metricWriter",
        member: serviceAccount.email.apply(email => `serviceAccount:${email}`),
    });

    return serviceAccount;
}
