/**
 * Organization and Project IAM Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00014: Role-based access control
 *
 * Sets up IAM for:
 * - CI/CD service account (for automated deployments)
 * - DevOps team access
 * - Environment-specific permissions (prod more restricted)
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { BootstrapConfig, Environment, getProjectId } from "./config";
import { ProjectResult } from "./projects";

/**
 * IAM roles for Anspar admin group per environment
 * - dev/qa: Full owner access for development and testing
 * - uat/prod: Viewer only; use break-glass for elevated access
 */
const ANSPAR_ADMIN_ROLES: Record<Environment, string[]> = {
    dev: ["roles/owner"],
    qa: ["roles/owner"],
    uat: ["roles/viewer"],
    prod: ["roles/viewer"],
};

/**
 * IAM roles for CI/CD service account per environment
 */
const CICD_ROLES: Record<Environment, string[]> = {
    dev: [
        "roles/run.admin",
        "roles/artifactregistry.admin",
        "roles/cloudsql.admin",
        "roles/iam.serviceAccountUser",
        "roles/storage.admin",
        "roles/secretmanager.admin",
        "roles/monitoring.admin",
    ],
    qa: [
        "roles/run.admin",
        "roles/artifactregistry.admin",
        "roles/cloudsql.admin",
        "roles/iam.serviceAccountUser",
        "roles/storage.admin",
        "roles/secretmanager.admin",
        "roles/monitoring.admin",
    ],
    uat: [
        "roles/run.admin",
        "roles/artifactregistry.admin",
        "roles/cloudsql.admin",
        "roles/iam.serviceAccountUser",
        "roles/storage.admin",
        "roles/secretmanager.admin",
        "roles/monitoring.admin",
    ],
    prod: [
        // Production has same roles but could be more restricted
        // Deployments require approval via CI/CD pipeline
        "roles/run.admin",
        "roles/artifactregistry.admin",
        "roles/cloudsql.admin",
        "roles/iam.serviceAccountUser",
        "roles/storage.admin",
        "roles/secretmanager.admin",
        "roles/monitoring.admin",
    ],
};

/**
 * Result of IAM setup
 */
export interface IamResult {
    cicdServiceAccount: gcp.serviceaccount.Account;
    cicdServiceAccountKey?: gcp.serviceaccount.Key;
    iamBindings: gcp.projects.IAMMember[];
    ansparAdminGroup?: string;
    ansparBindings: gcp.projects.IAMMember[];
}

/**
 * Create CI/CD service account for a sponsor
 * This account is used by GitHub Actions to deploy infrastructure
 */
export function createCicdServiceAccount(
    config: BootstrapConfig,
    devProject: ProjectResult
): gcp.serviceaccount.Account {
    const saName = `${config.sponsor}-cicd`;

    // Create service account in the dev project (shared across environments)
    const serviceAccount = new gcp.serviceaccount.Account(saName, {
        accountId: saName,
        displayName: `${config.sponsor} CI/CD Service Account`,
        description: "Service account for automated deployments via GitHub Actions",
        project: devProject.project.projectId,
    }, { dependsOn: devProject.apis });

    return serviceAccount;
}

/**
 * Grant Anspar admin group access to a project
 * - dev/qa: roles/owner (full access)
 * - uat/prod: roles/viewer (read-only, use break-glass for more)
 */
export function grantAnsparAdminAccess(
    config: BootstrapConfig,
    env: Environment,
    projectResult: ProjectResult,
    ansparAdminGroup: string
): gcp.projects.IAMMember[] {
    const projectId = getProjectId(config, env);
    const roles = ANSPAR_ADMIN_ROLES[env];
    const bindings: gcp.projects.IAMMember[] = [];

    for (const role of roles) {
        const roleName = role.split("/")[1];
        const binding = new gcp.projects.IAMMember(
            `${projectId}-anspar-${roleName}`,
            {
                project: projectResult.project.projectId,
                role: role,
                member: `group:${ansparAdminGroup}`,
            },
            { dependsOn: projectResult.apis }
        );
        bindings.push(binding);
    }

    return bindings;
}

/**
 * Grant CI/CD service account access to a project
 */
export function grantCicdAccess(
    config: BootstrapConfig,
    env: Environment,
    projectResult: ProjectResult,
    cicdServiceAccount: gcp.serviceaccount.Account
): gcp.projects.IAMMember[] {
    const projectId = getProjectId(config, env);
    const roles = CICD_ROLES[env];
    const bindings: gcp.projects.IAMMember[] = [];

    for (const role of roles) {
        const roleName = role.split("/")[1];
        const binding = new gcp.projects.IAMMember(
            `${projectId}-cicd-${roleName}`,
            {
                project: projectResult.project.projectId,
                role: role,
                member: pulumi.interpolate`serviceAccount:${cicdServiceAccount.email}`,
            },
            { dependsOn: projectResult.apis }
        );
        bindings.push(binding);
    }

    return bindings;
}

/**
 * Set up Workload Identity Federation for GitHub Actions
 * This allows GitHub Actions to authenticate without storing service account keys
 */
export function setupWorkloadIdentityForGitHub(
    config: BootstrapConfig,
    devProject: ProjectResult,
    cicdServiceAccount: gcp.serviceaccount.Account,
    githubOrg: string,
    githubRepo: string
): {
    pool: gcp.iam.WorkloadIdentityPool;
    provider: gcp.iam.WorkloadIdentityPoolProvider;
} {
    const poolName = `${config.sponsor}-github-pool`;
    const providerName = `${config.sponsor}-github-provider`;

    // Create Workload Identity Pool
    const pool = new gcp.iam.WorkloadIdentityPool(poolName, {
        workloadIdentityPoolId: poolName,
        project: devProject.project.projectId,
        displayName: `${config.sponsor} GitHub Actions`,
        description: "Workload Identity Pool for GitHub Actions CI/CD",
        disabled: false,
    }, { dependsOn: devProject.apis });

    // Create Workload Identity Provider for GitHub
    const provider = new gcp.iam.WorkloadIdentityPoolProvider(providerName, {
        workloadIdentityPoolId: pool.workloadIdentityPoolId,
        workloadIdentityPoolProviderId: providerName,
        project: devProject.project.projectId,
        displayName: "GitHub Actions",
        description: "GitHub Actions OIDC provider",
        attributeMapping: {
            "google.subject": "assertion.sub",
            "attribute.actor": "assertion.actor",
            "attribute.repository": "assertion.repository",
            "attribute.repository_owner": "assertion.repository_owner",
        },
        attributeCondition: `assertion.repository_owner == "${githubOrg}"`,
        oidc: {
            issuerUri: "https://token.actions.githubusercontent.com",
        },
    }, { parent: pool });

    // Allow the GitHub repo to impersonate the service account
    new gcp.serviceaccount.IAMMember(`${config.sponsor}-github-impersonate`, {
        serviceAccountId: cicdServiceAccount.name,
        role: "roles/iam.workloadIdentityUser",
        member: pulumi.interpolate`principalSet://iam.googleapis.com/${pool.name}/attribute.repository/${githubOrg}/${githubRepo}`,
    });

    return { pool, provider };
}

/**
 * Set up IAM for all sponsor projects
 */
export function setupSponsorIam(
    config: BootstrapConfig,
    projects: Map<Environment, ProjectResult>,
    githubOrg?: string,
    githubRepo?: string,
    ansparAdminGroup?: string
): IamResult {
    const devProject = projects.get("dev")!;

    // Create CI/CD service account
    const cicdServiceAccount = createCicdServiceAccount(config, devProject);

    // Grant CI/CD access to all projects
    const allBindings: gcp.projects.IAMMember[] = [];
    for (const [env, projectResult] of projects) {
        const bindings = grantCicdAccess(config, env, projectResult, cicdServiceAccount);
        allBindings.push(...bindings);
    }

    // Grant Anspar admin access to all projects (if configured)
    const ansparBindings: gcp.projects.IAMMember[] = [];
    if (ansparAdminGroup) {
        pulumi.log.info(`Granting Anspar admin access to: ${ansparAdminGroup}`);
        for (const [env, projectResult] of projects) {
            const bindings = grantAnsparAdminAccess(config, env, projectResult, ansparAdminGroup);
            ansparBindings.push(...bindings);
            const role = ANSPAR_ADMIN_ROLES[env][0];
            pulumi.log.info(`  ${env}: ${role}`);
        }
    }

    // Optionally set up Workload Identity for GitHub Actions
    if (githubOrg && githubRepo) {
        setupWorkloadIdentityForGitHub(
            config,
            devProject,
            cicdServiceAccount,
            githubOrg,
            githubRepo
        );
    }

    return {
        cicdServiceAccount,
        iamBindings: allBindings,
        ansparAdminGroup,
        ansparBindings,
    };
}
