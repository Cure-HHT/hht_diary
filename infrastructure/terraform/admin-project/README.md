# Admin Project Infrastructure

Terraform configuration for the `cure-hht-admin` GCP project, which hosts shared/org-wide resources used by all sponsor projects.

**Implements Requirements:**
- REQ-o00056: IaC for portal deployment
- REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)
- REQ-p00010: FDA 21 CFR Part 11 Compliance

## Overview

The `cure-hht-admin` project (project number: 149504828360) serves as the central admin project for:
- Terraform state storage (GCS bucket: `cure-hht-terraform-state`)
- Artifact Registry (GHCR pull-through cache)
- **Gmail Service Account** for org-wide email sending (OTP codes, activation emails)

## Resources Managed

### Gmail Service Account

A single service account (`org-gmail-sender`) that all sponsor projects use to send emails via Gmail API:
- Email OTP codes for 2FA
- Activation codes for new users
- System notifications

This approach is simpler than per-sponsor/environment service accounts:
- One domain-wide delegation setup
- WIF (Workload Identity Federation) - no keys to manage
- Centralized audit trail

## Prerequisites

1. **Google Workspace Admin** must complete one-time setup:
   - Sign BAA for HIPAA compliance (Account → Legal and compliance)
   - Create sender mailbox: `support@anspar.org`

2. **Terraform state bucket** must exist:
   ```bash
   gsutil ls gs://cure-hht-terraform-state/
   ```

## Usage

### Initialize

```bash
cd infrastructure/terraform/admin-project
terraform init
```

### Plan

```bash
# Ensure Doppler provides required env vars:
# - TF_VAR_ADMIN_PROJECT_NUMBER
# - TF_VAR_GCP_ORG_ID
doppler run -- terraform plan
```

### Apply

```bash
doppler run -- terraform apply
```

### After Apply

1. **Enable Domain-Wide Delegation** in Google Workspace Admin Console:
   - Go to: Security → API Controls → Domain-wide Delegation
   - Click "Add new"
   - Enter Client ID from terraform output: `gmail_client_id`
   - Add OAuth scope: `https://www.googleapis.com/auth/gmail.send`

2. **Add to Doppler** (all environments):
   ```bash
   doppler secrets set GMAIL_SERVICE_ACCOUNT_EMAIL="org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com"
   doppler secrets set EMAIL_SENDER="support@anspar.org"
   doppler secrets set EMAIL_ENABLED="true"
   ```

3. **Grant local developers permission to impersonate** (per developer):
   ```bash
   gcloud iam service-accounts add-iam-policy-binding \
     org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com \
     --member="user:DEVELOPER@anspar.org" \
     --role="roles/iam.serviceAccountTokenCreator" \
     --project=cure-hht-admin
   ```

4. **Add Sponsor Cloud Run Service Accounts** for impersonation:
   - After deploying each sponsor/environment with `sponsor-portal`, get the Cloud Run service account:
     ```bash
     cd ../sponsor-portal
     terraform output -raw portal_server_service_account_email
     ```
   - Add to `terraform.tfvars` in `sponsor_cloud_run_service_accounts` list
   - Re-run `terraform apply`

## Outputs

| Output | Description |
| ------ | ----------- |
| `gmail_service_account_email` | SA email for Doppler config |
| `gmail_client_id` | Client ID for domain-wide delegation |
| `gmail_setup_instructions` | Full setup guide |

## Files

```
admin-project/
├── README.md           # This file
├── main.tf             # Gmail SA and API enablement
├── variables.tf        # Input variables
├── outputs.tf          # Output values
├── providers.tf        # Provider configuration
├── versions.tf         # Version constraints + backend
└── terraform.tfvars    # Configuration values
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      cure-hht-admin                              │
│                    (Project: 149504828360)                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │             Gmail Service Account                         │   │
│  │             org-gmail-sender@cure-hht-admin.iam           │   │
│  │                                                           │   │
│  │  Domain-Wide Delegation → gmail.send → support@anspar    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                    serviceAccountTokenCreator                    │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  cure-hht-dev │      │ cure-hht-prod │      │ callisto-dev  │
│               │      │               │      │               │
│  Cloud Run SA │      │  Cloud Run SA │      │  Cloud Run SA │
│  can send     │      │  can send     │      │  can send     │
│  emails       │      │  emails       │      │  emails       │
└───────────────┘      └───────────────┘      └───────────────┘
```

## Security Notes

- **No service account keys** - uses WIF (Workload Identity Federation) for impersonation
- Only Cloud Run SAs and explicitly granted users can impersonate the Gmail SA
- All emails are logged in `email_audit_log` table for FDA compliance
- Domain-wide delegation is scoped to `gmail.send` only (not full Gmail access)
