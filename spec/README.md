# Hierarchical Documentation System

Files are organized by audience and topic using a hierarchical naming convention.
Files reference other files rather than containing redundant information.

**Status**: Reorganization complete (2025-10-23). All documentation now uses the hierarchical naming convention and resides in the spec/ directory.


# Hierarchical File Naming Convention

filename: {audience}-{topic}(-{subtopic}).{ext}

examples:
- prd-app.md
- prd-app-UX.md
- prd-clinical-trials.md
- prd-security.md
- prd-security-RBAC.md
- ops-security.md
- ops-security-RBAC.md
- dev-security.md
- dev-security-RBAC.md

# Audience

Typically the hierarchy from broad to specific is prd -> ops -> dev. 

prd: product requirement documents. High-level, C-suite, customer-facing, evaluation for suitability
ops: devops. Deployment, maintenance, daily operations and monitoring, incident reponse and reporting.
dev: software developers. Code writing practices, libraries used, toolchain.

Although dev and ops are in many ways parallel, ops requirements inform developer requirements, not vice-versa.

# Topics

app: the patient-facing application (the motivation for the project)
portal: a (non-patient) user-facing application for interacting with the system
clinical-trials: the operating paradigm for the system. Regulations and best-practice requirements.
sponsor: special requirements of the Sponsor.
security: ensuring only authorized access to protect the integrity of the data
RBAC: roll based access control. A system for authorizing specific activities.
RLS: row level security. A system for controlling access to data within the database.
database: where patient data is stored, as well as trial configuration and audit logs.


