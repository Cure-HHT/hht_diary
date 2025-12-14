/**
 * Stack Configuration Management
 *
 * This module handles loading and validating Pulumi stack configuration.
 */

import * as pulumi from "@pulumi/pulumi";

export interface StackConfig {
    // GCP Configuration
    project: string;
    region: string;
    gcpOrgId: string;  // Required for Workforce Identity Federation

    // Sponsor Configuration
    sponsor: string;
    environment: "dev" | "qa" | "uat" | "production";

    // Domain Configuration
    domainName: string;

    // Database Configuration (Output<string> because it's a secret)
    dbPassword: pulumi.Output<string>;

    // Build Configuration
    sponsorRepoPath: string;

    // Cloud Run Configuration
    minInstances: number;
    maxInstances: number;
    containerMemory: string;
    containerCpu: number;

    // Workforce Identity Federation Configuration
    workforceIdentity: {
        enabled: boolean;
        providerType?: "oidc" | "saml";
        issuerUri?: string;
        clientId?: string;
        clientSecret?: pulumi.Output<string>;
    };
}

/**
 * Load and validate stack configuration
 */
export function getStackConfig(): StackConfig {
    const config = new pulumi.Config();
    const gcpConfig = new pulumi.Config("gcp");

    // Load required configuration
    const stackConfig: StackConfig = {
        // GCP
        project: gcpConfig.require("project"),
        region: gcpConfig.get("region") || "us-central1",
        gcpOrgId: gcpConfig.require("orgId"),

        // Sponsor
        sponsor: config.require("sponsor"),
        environment: config.require("environment") as any,

        // Domain
        domainName: config.require("domainName"),

        // Database
        dbPassword: config.requireSecret("dbPassword"),

        // Build
        sponsorRepoPath: config.get("sponsorRepoPath") || "../clinical-diary-sponsor",

        // Cloud Run
        minInstances: config.getNumber("minInstances") || 1,
        maxInstances: config.getNumber("maxInstances") || 10,
        containerMemory: config.get("containerMemory") || "512Mi",
        containerCpu: config.getNumber("containerCpu") || 1,

        // Workforce Identity Federation
        workforceIdentity: {
            enabled: config.getBoolean("workforceIdentityEnabled") || false,
            providerType: config.get("workforceIdentityProviderType") as "oidc" | "saml" | undefined,
            issuerUri: config.get("workforceIdentityIssuerUri"),
            clientId: config.get("workforceIdentityClientId"),
            clientSecret: config.getSecret("workforceIdentityClientSecret"),
        },
    };

    // Validate environment
    const validEnvs = ["dev", "qa", "uat", "production"];
    if (!validEnvs.includes(stackConfig.environment)) {
        throw new Error(
            `Invalid environment: ${stackConfig.environment}. Must be one of: ${validEnvs.join(", ")}`
        );
    }

    return stackConfig;
}

/**
 * Generate resource name with consistent naming convention
 */
export function resourceName(config: StackConfig, baseName: string): string {
    return `${config.sponsor}-${config.environment}-${baseName}`;
}

/**
 * Generate resource labels for all resources
 */
export function resourceLabels(config: StackConfig): { [key: string]: string } {
    return {
        sponsor: config.sponsor,
        environment: config.environment,
        managed_by: "pulumi",
        compliance: "fda-21-cfr-part-11",
    };
}
