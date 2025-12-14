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
 * - Cloud Run: Containerized Flutter web app (nginx + static files)
 * - Artifact Registry: Docker image storage
 * - Cloud SQL: PostgreSQL database with RLS
 * - Identity Platform: Firebase authentication
 * - Custom Domain: SSL-enabled custom domain mapping
 * - Monitoring: Uptime checks and error alerts
 * - IAM: Least-privilege service accounts
 */

import * as pulumi from "@pulumi/pulumi";
import { getStackConfig } from "./src/config";
import { createServiceAccount } from "./src/iam";
import { createArtifactRegistry } from "./src/docker-image";
import { createCloudSqlInstance } from "./src/cloud-sql";
import { buildAndPushDockerImage } from "./src/docker-image";
import { createCloudRunService } from "./src/cloud-run";
import { createDomainMapping } from "./src/domain-mapping";
import { createMonitoring } from "./src/monitoring";

/**
 * Main Pulumi program
 */
async function main() {
    // Load stack configuration
    const config = getStackConfig();

    pulumi.log.info(`Deploying portal for sponsor: ${config.sponsor}, env: ${config.environment}`);

    // Step 1: Create IAM Service Account
    const serviceAccount = createServiceAccount(config);

    // Step 2: Create Artifact Registry Repository
    const artifactRegistry = createArtifactRegistry(config);

    // Step 3: Create Cloud SQL Instance
    const cloudSql = createCloudSqlInstance(config, serviceAccount);

    // Step 4: Build and Push Docker Image
    const dockerImage = await buildAndPushDockerImage(config, artifactRegistry);

    // Step 5: Deploy Cloud Run Service
    const cloudRunService = createCloudRunService(
        config,
        dockerImage,
        serviceAccount,
        cloudSql
    );

    // Step 6: Create Custom Domain Mapping
    const domainMapping = createDomainMapping(config, cloudRunService);

    // Step 7: Create Monitoring and Alerts
    const monitoring = createMonitoring(config, cloudRunService);

    // Export stack outputs
    return {
        // Cloud Run outputs
        portalUrl: cloudRunService.statuses[0].url,
        serviceName: cloudRunService.name,

        // Domain outputs
        customDomainUrl: pulumi.interpolate`https://${config.domainName}`,
        dnsRecordRequired: pulumi.interpolate`CNAME ${config.domainName} -> ghs.googlehosted.com`,
        domainStatus: domainMapping.status.certificateMode,

        // Database outputs
        dbConnectionName: cloudSql.connectionName,
        dbInstanceName: cloudSql.name,

        // Image outputs
        imageTag: dockerImage.imageName,

        // Monitoring outputs
        uptimeCheckId: monitoring.uptimeCheck.uptimeCheckId,

        // General outputs
        sponsor: config.sponsor,
        environment: config.environment,
        region: config.region,
    };
}

// Execute main program
export = main();
