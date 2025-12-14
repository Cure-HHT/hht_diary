/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Clinical Trial Portal - Pulumi Infrastructure
 *
 * This is the main entry point for the Pulumi program that deploys
 * the portal infrastructure to Google Cloud Platform.
 *
 * Architecture:
 * - VPC: Private network for secure Cloud SQL connectivity
 * - Cloud Run: Containerized Flutter web app (nginx + static files)
 * - Artifact Registry: Docker image storage
 * - Cloud SQL: PostgreSQL database with RLS (private IP via VPC)
 * - Cloud Storage: Backup buckets for database exports
 * - Audit Logs: 25-year retention for FDA 21 CFR Part 11 compliance
 * - Workforce Identity Federation: Sponsor SSO integration (SAML/OIDC)
 * - Custom Domain: SSL-enabled custom domain mapping
 * - Monitoring: Uptime checks, error alerts, and Cloud SQL alerts
 * - IAM: Least-privilege service accounts
 */

import * as pulumi from "@pulumi/pulumi";
import { getStackConfig } from "./src/config";
import { createServiceAccount, enableRequiredApis } from "./src/iam";
import { createArtifactRegistry } from "./src/docker-image";
import { createVpcNetwork } from "./src/vpc";
import { createStorageBuckets } from "./src/storage";
import { createCloudSqlInstance } from "./src/cloud-sql";
import { buildAndPushDockerImage } from "./src/docker-image";
import { createCloudRunService } from "./src/cloud-run";
import { createDomainMapping } from "./src/domain-mapping";
import { createMonitoring } from "./src/monitoring";
import {
    createWorkforceIdentityFederation,
    grantWorkforcePoolAccess,
    WorkforceIdentityConfig,
} from "./src/workforce-identity";
import { createAuditLogInfrastructure } from "./src/audit-logs";

/**
 * Main Pulumi program
 */
async function main() {
    // Load stack configuration
    const config = getStackConfig();

    pulumi.log.info(`Deploying portal for sponsor: ${config.sponsor}, env: ${config.environment}`);

    // Step 1: Enable Required APIs (must be first)
    const enabledApis = enableRequiredApis(config);

    // Step 2: Create IAM Service Account
    const serviceAccount = createServiceAccount(config);

    // Step 3: Create VPC Network and VPC Access Connector
    const vpc = createVpcNetwork(config, undefined, enabledApis);

    // Step 4: Create Storage Buckets (backups)
    const storage = createStorageBuckets(config, undefined, enabledApis);

    // Step 5: Create Artifact Registry Repository
    const artifactRegistry = createArtifactRegistry(config);

    // Step 6: Create Cloud SQL Instance (with VPC private IP)
    const cloudSql = createCloudSqlInstance(config, vpc);

    // Step 7: Build and Push Docker Image
    const dockerImage = await buildAndPushDockerImage(config, artifactRegistry);

    // Step 8: Deploy Cloud Run Service (with VPC connector for private Cloud SQL)
    const cloudRunService = createCloudRunService(
        config,
        dockerImage,
        serviceAccount,
        cloudSql,
        vpc
    );

    // Step 9: Create Custom Domain Mapping
    const domainMapping = createDomainMapping(config, cloudRunService);

    // Step 10: Create Monitoring and Alerts (including Cloud SQL alerts)
    const monitoring = createMonitoring(config, cloudRunService, cloudSql);

    // Step 11: Create Audit Log Infrastructure (FDA 21 CFR Part 11 - 25 year retention)
    const auditLogs = createAuditLogInfrastructure(config, undefined, enabledApis);

    // Step 12: Configure Workforce Identity Federation (if enabled)
    // This allows sponsor users to authenticate via their corporate IdP (SAML/OIDC)
    let workforceIdentity = undefined;
    if (config.workforceIdentity.enabled) {
        const identityConfig: WorkforceIdentityConfig = {
            enabled: true,
            providerType: config.workforceIdentity.providerType || "oidc",
            oidc: config.workforceIdentity.providerType === "oidc" ? {
                issuerUri: config.workforceIdentity.issuerUri!,
                clientId: config.workforceIdentity.clientId!,
                clientSecret: config.workforceIdentity.clientSecret,
                webSsoResponseType: "CODE",
            } : undefined,
            attributeMapping: {
                "google.subject": "assertion.sub",
                "google.groups": "assertion.groups",
                "attribute.email": "assertion.email",
                "attribute.name": "assertion.name",
            },
        };

        workforceIdentity = createWorkforceIdentityFederation(config, identityConfig);

        // Grant authenticated sponsor users access to invoke Cloud Run
        if (workforceIdentity) {
            grantWorkforcePoolAccess(
                config,
                workforceIdentity,
                "roles/run.invoker",
                "cloudrun-invoker"
            );
        }
    }

    // Export stack outputs
    return {
        // Cloud Run outputs
        portalUrl: cloudRunService.statuses[0].url,
        serviceName: cloudRunService.name,

        // Domain outputs
        customDomainUrl: pulumi.interpolate`https://${config.domainName}`,
        dnsRecordRequired: pulumi.interpolate`CNAME ${config.domainName} -> ghs.googlehosted.com`,
        domainStatus: domainMapping.statuses.apply(s => s?.[0]?.resourceRecords),

        // VPC outputs
        vpcNetworkName: vpc.network.name,
        vpcConnectorName: vpc.vpcConnector.name,

        // Database outputs
        dbConnectionName: cloudSql.connectionName,
        dbInstanceName: cloudSql.name,
        dbPrivateIpAddress: cloudSql.privateIpAddress,

        // Storage outputs
        backupBucketName: storage.backupBucket.name,

        // Image outputs
        imageTag: dockerImage.imageName,

        // Monitoring outputs
        uptimeCheckId: monitoring.uptimeCheck.uptimeCheckId,

        // Audit Log outputs (FDA 21 CFR Part 11 compliance)
        auditLogBucket: auditLogs.auditLogBucket.name,
        auditLogBucketUrl: pulumi.interpolate`gs://${auditLogs.auditLogBucket.name}`,
        auditLogRetentionYears: 25,
        auditLogDataset: auditLogs.auditLogDataset?.datasetId,

        // General outputs
        sponsor: config.sponsor,
        environment: config.environment,
        region: config.region,

        // Workforce Identity Federation outputs (if enabled)
        workforceIdentityEnabled: config.workforceIdentity.enabled,
        workforcePoolId: workforceIdentity?.pool.workforcePoolId,
        workforceProviderId: workforceIdentity?.provider.id,
    };
}

// Execute main program
export = main();
