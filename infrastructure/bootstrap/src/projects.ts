/**
 * GCP Project Creation
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00008: Multi-sponsor deployment model
 *
 * Creates 4 GCP projects per sponsor (dev, qa, uat, prod)
 * with consistent naming, labels, and API enablement.
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import {
    BootstrapConfig,
    Environment,
    ENVIRONMENTS,
    getProjectId,
    getProjectDisplayName,
} from "./config";

/**
 * APIs to enable on each project
 * These are required for the portal infrastructure
 */
const REQUIRED_APIS = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudidentity.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudbuild.googleapis.com",
    "containerregistry.googleapis.com",
];

/**
 * Result of project creation
 */
export interface ProjectResult {
    project: gcp.organizations.Project;
    projectId: pulumi.Output<string>;
    environment: Environment;
    apis: gcp.projects.Service[];
}

/**
 * Create a single GCP project for a sponsor environment
 */
function createProject(
    config: BootstrapConfig,
    env: Environment
): ProjectResult {
    const projectId = getProjectId(config, env);
    const displayName = getProjectDisplayName(config, env);

    // Create the project
    const project = new gcp.organizations.Project(projectId, {
        projectId: projectId,
        name: displayName,
        orgId: config.orgId,
        billingAccount: config.billingAccountId,
        folderId: config.folderId,
        labels: {
            ...config.labels,
            environment: env,
        },
        autoCreateNetwork: false, // We'll create VPC explicitly if needed
    });

    // Enable required APIs
    const apis: gcp.projects.Service[] = [];
    for (const api of REQUIRED_APIS) {
        const apiResource = new gcp.projects.Service(
            `${projectId}-${api.split(".")[0]}`,
            {
                project: project.projectId,
                service: api,
                disableOnDestroy: false, // Don't disable API on stack destroy
                disableDependentServices: false,
            },
            { dependsOn: [project] }
        );
        apis.push(apiResource);
    }

    return {
        project,
        projectId: project.projectId,
        environment: env,
        apis,
    };
}

/**
 * Create all 4 projects for a sponsor (dev, qa, uat, prod)
 */
export function createSponsorProjects(
    config: BootstrapConfig
): Map<Environment, ProjectResult> {
    const projects = new Map<Environment, ProjectResult>();

    for (const env of ENVIRONMENTS) {
        pulumi.log.info(`Creating project for ${config.sponsor}-${env}`);
        const result = createProject(config, env);
        projects.set(env, result);
    }

    return projects;
}

/**
 * Get project outputs for export
 */
export function getProjectOutputs(
    projects: Map<Environment, ProjectResult>
): { [key: string]: pulumi.Output<string> } {
    const outputs: { [key: string]: pulumi.Output<string> } = {};

    for (const [env, result] of projects) {
        outputs[`${env}ProjectId`] = result.projectId;
        outputs[`${env}ProjectNumber`] = result.project.number;
    }

    return outputs;
}
