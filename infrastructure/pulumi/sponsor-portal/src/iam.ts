/**
 * IAM Service Account Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *
 * Creates service accounts with least-privilege permissions for Cloud Run.
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName } from "./config";

/**
 * Required GCP APIs for the portal infrastructure
 */
const REQUIRED_APIS = [
    "sqladmin.googleapis.com",         // Cloud SQL
    "run.googleapis.com",              // Cloud Run
    "artifactregistry.googleapis.com", // Artifact Registry
    "compute.googleapis.com",          // VPC networking
    "vpcaccess.googleapis.com",        // VPC Access Connector
    "servicenetworking.googleapis.com",// Private service connection
    "cloudbuild.googleapis.com",       // Cloud Build
    "logging.googleapis.com",          // Cloud Logging
    "monitoring.googleapis.com",       // Cloud Monitoring
    "iam.googleapis.com",              // IAM
    "iamcredentials.googleapis.com",   // IAM Service Account Credentials
    "sts.googleapis.com",              // Security Token Service (for Workforce Identity)
];

/**
 * Enable required GCP APIs for the project
 *
 * @param config Stack configuration
 * @returns Array of enabled API services (for dependency tracking)
 */
export function enableRequiredApis(config: StackConfig): gcp.projects.Service[] {
    return REQUIRED_APIS.map(api => {
        const name = api.replace(".googleapis.com", "").replace(/\./g, "-");
        return new gcp.projects.Service(
            resourceName(config, `api-${name}`),
            {
                project: config.project,
                service: api,
                disableOnDestroy: false, // Keep APIs enabled even if stack is destroyed
            }
        );
    });
}

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
