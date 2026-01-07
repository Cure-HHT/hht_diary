We are working on ticket CUR-648.  
We have a Pulumi infrastructure project that hasn't been used yet and, with new
resources who know Terraform well and not Pulumi, and since Pulumi looked more
complicated, we need to convert the pulumi project to terraform.  
Go into plan mode and create a plan to convert the project to terraform.  

Understand our multi-sponsor architecture:
spec/dev-architecture-multi-sponsor.md

Each sponsor gets 4 GCP project, one for each environment: dev, qa, uat and prod

Errors in the Pulumi setup:
- There's only 1 GCP billing account: Cure-HHT 017213-A61D61-71522F
- The audit log storage bucket should only be locked in prod, not in dev, qa, or uat

We need: 
- A plan document for all the work and recommendations for overall form and usage
- terraform files
- README.md Documentation that describes all the IaC:
  - The deployment architecture
  - the terraform files and purpose
  - how to use the IaC system
  - how to manage state across multiple sponsors and environments
- bash scripts that create a single project for a single sponsor (if this is possible in terraform) 
  - we want to create dev, perfect it  
- use GCP best practices for networking, naming, and VPC usage 

Write the plan document first then stop.  Let a human review the plan.
We may update the plan before we proceed with the rest.