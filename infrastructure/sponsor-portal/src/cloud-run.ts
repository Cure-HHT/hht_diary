/**
 * Cloud Run Service Configuration
 *
 * Deploys containerized Flutter web portal to Cloud Run with:
 * - Auto-scaling configuration
 * - Cloud SQL connection
 * - Environment variables
 * - Health checks
 * - Service account
 */

import * as gcp from "@pulumi/gcp";
import * as docker from "@pulumi/docker";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName } from "./config";

/**
 * Create Cloud Run service for portal
 */
export function createCloudRunService(
    config: StackConfig,
    image: docker.Image,
    serviceAccount: gcp.serviceaccount.Account,
    cloudSql: gcp.sql.DatabaseInstance
): gcp.cloudrun.Service {
    const serviceName = resourceName(config, "portal");

    const service = new gcp.cloudrun.Service(serviceName, {
        name: "portal",
        location: config.region,
        project: config.project,

        template: {
            metadata: {
                annotations: {
                    // Connect to Cloud SQL instance
                    "run.googleapis.com/cloudsql-instances": cloudSql.connectionName,
                    // Auto-scaling configuration
                    "autoscaling.knative.dev/minScale": config.minInstances.toString(),
                    "autoscaling.knative.dev/maxScale": config.maxInstances.toString(),
                    // VPC connector (if needed for private Cloud SQL)
                    // "run.googleapis.com/vpc-access-connector": vpcConnector.name,
                },
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
                        env: [
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
