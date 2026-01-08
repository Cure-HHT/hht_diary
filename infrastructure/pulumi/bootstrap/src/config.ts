/**
 * Bootstrap Configuration Management
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00008: Multi-sponsor deployment model
 */

import * as pulumi from "@pulumi/pulumi";

/**
 * Environment definitions for each sponsor
 */
export const ENVIRONMENTS = ["dev", "qa", "uat", "prod"] as const;
export type Environment = typeof ENVIRONMENTS[number];

/**
 * Bootstrap stack configuration
 */
export interface BootstrapConfig {
    // Sponsor identification
    sponsor: string;

    // GCP Organization
    orgId: string;

    // Billing
    billingAccountId: string;

    // Project naming
    projectPrefix: string;

    // Region for resources
    defaultRegion: string;

    // Optional: Folder to place projects in
    folderId?: string;

    // Labels to apply to all projects
    labels: { [key: string]: string };
}

/**
 * Load bootstrap configuration from Pulumi config
 */
export function getBootstrapConfig(): BootstrapConfig {
    const config = new pulumi.Config();
    const gcpConfig = new pulumi.Config("gcp");

    const sponsor = config.require("sponsor");

    return {
        sponsor,
        orgId: gcpConfig.require("orgId"),
        billingAccountId: config.require("billingAccountId"),
        projectPrefix: config.get("projectPrefix") || "cure-hht",
        defaultRegion: config.get("defaultRegion") || "us-central1",
        folderId: config.get("folderId"),
        labels: {
            sponsor: sponsor,
            managed_by: "pulumi",
            bootstrap: "true",
            compliance: "fda-21-cfr-part-11",
        },
    };
}

/**
 * Generate project ID for a sponsor environment
 * Format: {prefix}-{sponsor}-{env}
 * Example: cure-hht-orion-prod
 */
export function getProjectId(config: BootstrapConfig, env: Environment): string {
    return `${config.projectPrefix}-${config.sponsor}-${env}`;
}

/**
 * Generate display name for a project
 */
export function getProjectDisplayName(config: BootstrapConfig, env: Environment): string {
    const envNames: Record<Environment, string> = {
        dev: "Development",
        qa: "QA",
        uat: "UAT",
        prod: "Production",
    };
    return `${config.sponsor.charAt(0).toUpperCase() + config.sponsor.slice(1)} ${envNames[env]}`;
}
