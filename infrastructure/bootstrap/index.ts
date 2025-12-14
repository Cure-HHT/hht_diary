/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00008: Multi-sponsor deployment model
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Bootstrap Infrastructure - Sponsor Onboarding
 *
 * This Pulumi program creates the foundational GCP infrastructure
 * for a new sponsor, including:
 *
 * - 4 GCP projects (dev, qa, uat, prod)
 * - Required API enablement
 * - Billing budgets and alerts
 * - CI/CD service account with appropriate IAM roles
 * - Workload Identity Federation for GitHub Actions (optional)
 * - Audit log infrastructure (25-year retention for FDA 21 CFR Part 11)
 *
 * Usage:
 *   cd infrastructure/bootstrap
 *   pulumi stack init <sponsor-name>
 *   pulumi config set sponsor <sponsor-name>
 *   pulumi config set gcp:orgId <org-id>
 *   pulumi config set billingAccountId <billing-account-id>
 *   pulumi up
 */

import * as pulumi from "@pulumi/pulumi";
import { getBootstrapConfig, ENVIRONMENTS } from "./src/config";
import { createSponsorProjects, getProjectOutputs } from "./src/projects";
import { createSponsorBillingBudgets } from "./src/billing";
import { setupSponsorIam } from "./src/org-iam";
import { createSponsorAuditLogs, getAuditLogOutputs } from "./src/audit-logs";

/**
 * Main bootstrap program
 */
function main() {
    // Load configuration
    const config = getBootstrapConfig();

    pulumi.log.info(`Bootstrapping infrastructure for sponsor: ${config.sponsor}`);
    pulumi.log.info(`Organization ID: ${config.orgId}`);
    pulumi.log.info(`Billing Account: ${config.billingAccountId}`);

    // Step 1: Create 4 GCP projects (dev, qa, uat, prod)
    pulumi.log.info("Creating sponsor projects...");
    const projects = createSponsorProjects(config);

    // Step 2: Create billing budgets for each project
    pulumi.log.info("Setting up billing budgets...");
    const budgets = createSponsorBillingBudgets(config, projects);

    // Step 3: Set up IAM (CI/CD service account, roles, Anspar admin access)
    pulumi.log.info("Configuring IAM...");
    const pulumiConfig = new pulumi.Config();
    const githubOrg = pulumiConfig.get("githubOrg");
    const githubRepo = pulumiConfig.get("githubRepo");
    const ansparAdminGroup = pulumiConfig.get("ansparAdminGroup");

    const iam = setupSponsorIam(config, projects, githubOrg, githubRepo, ansparAdminGroup);

    // Step 4: Create audit log infrastructure (FDA 21 CFR Part 11 - 25 year retention)
    pulumi.log.info("Setting up audit log infrastructure (25-year retention)...");
    const auditLogs = createSponsorAuditLogs(config, projects);
    const auditOutputs = getAuditLogOutputs(config, auditLogs);

    // Export outputs
    const projectOutputs = getProjectOutputs(projects);

    return {
        // Sponsor info
        sponsor: config.sponsor,
        projectPrefix: config.projectPrefix,

        // Project IDs (for use in infrastructure/sponsor-portal stacks)
        ...projectOutputs,

        // CI/CD service account
        cicdServiceAccountEmail: iam.cicdServiceAccount.email,
        cicdServiceAccountId: iam.cicdServiceAccount.uniqueId,

        // Anspar admin access
        ansparAdminGroup: iam.ansparAdminGroup ?? "not configured",
        ansparDevQaAccess: iam.ansparAdminGroup ? "roles/owner" : "none",
        ansparUatProdAccess: iam.ansparAdminGroup ? "roles/viewer" : "none",

        // Audit log infrastructure (FDA 21 CFR Part 11 compliance)
        ...auditOutputs,

        // Instructions for next steps
        nextSteps: pulumi.interpolate`
Sponsor ${config.sponsor} bootstrap complete!

Next steps:
1. Update DNS records if needed
2. Configure Pulumi stacks for each environment:

   cd ../sponsor-portal

   # Development
   pulumi stack init ${config.sponsor}-dev
   pulumi config set gcp:project ${projectOutputs.devProjectId}
   pulumi config set gcp:region ${config.defaultRegion}
   pulumi config set gcp:orgId ${config.orgId}
   pulumi config set sponsor ${config.sponsor}
   pulumi config set environment dev
   pulumi config set domainName portal-${config.sponsor}-dev.cure-hht.org
   pulumi config set --secret dbPassword <password>

   # Repeat for qa, uat, prod...

3. Set up GitHub Actions secrets:
   - GCP_WORKLOAD_IDENTITY_PROVIDER
   - GCP_SERVICE_ACCOUNT

4. Deploy infrastructure:
   pulumi up
`,
    };
}

// Execute
export = main();
