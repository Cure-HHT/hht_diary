We are working on ticket CUR-648.  
We have a Pulumi infrastructure project that hasn't been used yet and, with new
resources who know Terraform well and not Pulumi, and since Pulumi looked more
complicated, we need to convert the pulumi project to terraform.  
Go into plan mode and create a plan to convert the project to terraform.  

Understand our multi-sponsor architecture:
spec/dev-architecture-multi-sponsor.md

Each sponsor gets 4 GCP project, one for each environment: dev, qa, uat and prod

Also understand all out requirements:
spec/dev-architecture-multi-sponsor.md
spec/dev-compliance-practices.md
spec/dev-configuration.md
spec/dev-core-practices.md
spec/dev-environment.md
spec/dev-evidence-records.md
spec/dev-portal.md
spec/dev-principles-quick-reference.md
spec/dev-requirements-management.md
spec/dev-security.md
spec/dev-security-RLS.md
spec/ops-artifact-management.md
spec/ops-cicd.md
spec/ops-data-custody-handoff.md
spec/ops-deployment.md
spec/ops-database-migration.md
spec/ops-database-setup.md
spec/dev-database.md
spec/dev-database-reference.md
spec/ops-deployment-automation.md
spec/ops-deployment-checklist.md
spec/ops-github-access-control.md
spec/ops-infrastructure-as-code.md
spec/ops-monitoring-observability.md
spec/ops-operations.md
spec/ops-portal.md
spec/ops-requirements-management.md
spec/ops-security.md
spec/ops-security-authentication.md
spec/ops-security-RLS.md
spec/ops-security-tamper-proofing.md
spec/ops-SLA.md
spec/ops-system.md
spec/prd-architecture-multi-sponsor.md
spec/prd-backup.md
spec/prd-clinical-trials.md
spec/prd-devops.md
spec/prd-diary-app.md
spec/prd-event-sourcing-system.md
spec/prd-evidence-records.md
spec/prd-portal.md
spec/prd-security.md
spec/prd-security-data-classification.md
spec/prd-security-RBAC.md
spec/prd-security-RLS.md
spec/prd-services.md
spec/prd-SLA.md
spec/prd-standards.md
spec/prd-system.md

Improve on the Pulumi setup where possible, especially because our requirements have been updated since it was created.

Errors in the Pulumi setup:
- There's only 1 GCP billing account: Cure-HHT 017213-A61D61-71522F
- The audit log storage bucket should only be locked in prod, not in dev, qa, or uat
- we prefer WIP over service accounts, when possible
- Use Artifact Registry for containers deployed to Cloud Run

We need: 
- A plan document for all the work and recommendations for overall form and usage
- terraform files
- README.md Documentation that describes all the IaC:
  - The deployment architecture
  - the terraform files and purpose
  - exaplins all variables and what information we need to collect
  - how to use the IaC system
  - how to use doppler when using the IaC
  - how to onboard a new sponsor
  - how to manage state across multiple sponsors and environments
  - do we have separate bootstrap and sponsor-portal project like Pulumi has?
  - how the yaml files can be used as templates for different sponsors (I guess this is just variables?)
- bash scripts that create a single project for a single sponsor (if this is possible in terraform) 
  - we want to create dev, perfect it  
- our secrets are stored in doppler which can be synced to GSM, integrate doppler for devops users
- do not store secrets in state management files
- use GCP best practices for networking, naming, and VPC usage 
- we don't want to use expensive cloud services.  All work must be auditable and secure so prefer free services that 
  are local or local to our cloud
- explain why not to use opentofu over open source terraform
- Update the docs that mention Pulumi to Terraform doc.

Write the plan document first then stop.  Let a human review the plan.
We may update the plan before we proceed with the rest.