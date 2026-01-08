/**
 * Cloud Run Service Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00005: Data security and isolation
 *
 * Deploys containerized Flutter web portal to Cloud Run with:
 * - Auto-scaling configuration
 * - VPC connector for private Cloud SQL connectivity
 * - Environment variables
 * - Health checks
 * - Service account
 */

import * as gcp from "@pulumi/gcp";
import * as docker from "@pulumi/docker";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName } from "./config";
import { VpcResult } from "./vpc";

/**
 * Create Cloud Run service for portal
 *
 * @param config Stack configuration
 * @param image Docker image to deploy
 * @param serviceAccount Service account for the Cloud Run service
 * @param cloudSql Cloud SQL instance for database connection
 * @param vpc VPC result for private connectivity (optional, but recommended)
 */
export function createCloudRunService(
    config: StackConfig,
    image: docker.Image,
    serviceAccount: gcp.serviceaccount.Account,
    cloudSql: gcp.sql.DatabaseInstance,
    vpc?: VpcResult
): gcp.cloudrun.Service {
    const serviceName = resourceName(config, "portal");

    // Build annotations based on VPC configuration
    const annotations: { [key: string]: pulumi.Input<string> } = {
        // Connect to Cloud SQL instance
        "run.googleapis.com/cloudsql-instances": cloudSql.connectionName,
        // Auto-scaling configuration
        "autoscaling.knative.dev/minScale": config.minInstances.toString(),
        "autoscaling.knative.dev/maxScale": config.maxInstances.toString(),
    };

    // Add VPC connector if available (for private Cloud SQL connectivity)
    if (vpc) {
        annotations["run.googleapis.com/vpc-access-connector"] = vpc.vpcConnector.name;
        annotations["run.googleapis.com/vpc-access-egress"] = "private-ranges-only";
    }

    const service = new gcp.cloudrun.Service(serviceName, {
        name: "portal",
        location: config.region,
        project: config.project,

        template: {
            metadata: {
                annotations: annotations,
            },
            spec: {
                serviceAccountName: serviceAccount.email,
                containers: [
                    {
                        image: image.imageName,
                        ports: [
                            {
                                containerPort: 8080,
                                name: "http1",
                            },
                        ],
                        resources: {
                            limits: {
                                cpu: config.containerCpu.toString(),
                                memory: config.containerMemory,
                            },
                        },
                        envs: [
                            {
                                name: "ENVIRONMENT",
                                value: config.environment,
                            },
                            {
                                name: "SPONSOR_ID",
                                value: config.sponsor,
                            },
                            {
                                name: "GCP_PROJECT_ID",
                                value: config.project,
                            },
                            {
                                name: "DB_HOST",
                                value: "/cloudsql/" + cloudSql.connectionName.apply(name => name),
                            },
                            {
                                name: "DB_NAME",
                                value: "clinical_diary",
                            },
                            {
                                name: "DB_USER",
                                value: "app_user",
                            },
                            {
                                name: "DB_PASSWORD",
                                value: config.dbPassword,
                            },
                        ],
                        // Liveness probe
                        livenessProbe: {
                            httpGet: {
                                path: "/health",
                                port: 8080,
                            },
                            initialDelaySeconds: 10,
                            periodSeconds: 10,
                            timeoutSeconds: 3,
                            failureThreshold: 3,
                        },
                    },
                ],
            },
        },

        traffics: [
            {
                percent: 100,
                latestRevision: true,
            },
        ],
    });

    // Allow unauthenticated access (portal handles auth via Identity Platform)
    new gcp.cloudrun.IamMember(`${serviceName}-public-access`, {
        service: service.name,
        location: config.region,
        role: "roles/run.invoker",
        member: "allUsers",
        project: config.project,
    });

    return service;
}
