/**
 * Stack Configuration Management
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00005: Data security and isolation (GDPR compliance)
 *
 * This module handles loading and validating Pulumi stack configuration.
 */

import * as pulumi from "@pulumi/pulumi";

/**
 * GCP regions compliant with GDPR (EU/EEA data residency)
 * https://cloud.google.com/about/locations#europe
 */
export const GDPR_COMPLIANT_REGIONS = [
    // EU Member States
    "europe-west1",      // Belgium
    "europe-west3",      // Frankfurt, Germany
    "europe-west4",      // Netherlands
    "europe-west6",      // Zurich, Switzerland (GDPR adequate)
    "europe-west8",      // Milan, Italy
    "europe-west9",      // Paris, France
    "europe-west10",     // Berlin, Germany
    "europe-west12",     // Turin, Italy
    "europe-north1",     // Finland
    "europe-central2",   // Warsaw, Poland
    "europe-southwest1", // Madrid, Spain
] as const;

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

    // Validate GDPR compliance for region
    validateGdprRegion(stackConfig.region, config.getBoolean("allowNonGdprRegion") ?? false);

    return stackConfig;
}

/**
 * Validate that the region is GDPR-compliant
 *
 * @param region GCP region
 * @param allowNonGdprRegion If true, only warns instead of throwing
 * @throws Error if region is not GDPR-compliant and allowNonGdprRegion is false
 */
export function validateGdprRegion(region: string, allowNonGdprRegion: boolean = false): void {
    const isGdprCompliant = (GDPR_COMPLIANT_REGIONS as readonly string[]).includes(region);

    if (!isGdprCompliant) {
        const message = `
WARNING: Region '${region}' is NOT GDPR-compliant for EU data residency.

For GDPR compliance, use one of these EU regions:
  ${GDPR_COMPLIANT_REGIONS.join(", ")}

Recommended for most EU deployments:
  - europe-west1 (Belgium) - Mature, well-connected
  - europe-west3 (Frankfurt) - Central EU location
  - europe-west4 (Netherlands) - Good connectivity

To proceed with a non-GDPR region (NOT recommended for EU user data):
  pulumi config set allowNonGdprRegion true
`;

        if (allowNonGdprRegion) {
            pulumi.log.warn(message);
        } else {
            throw new Error(message);
        }
    }
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
