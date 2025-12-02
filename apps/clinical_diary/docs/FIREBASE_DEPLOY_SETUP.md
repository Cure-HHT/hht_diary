# Firebase Deployment Setup

<!-- IMPLEMENTS REQUIREMENTS:
     REQ-d00006: Mobile App Build and Release Process -->

This document describes how to set up Firebase Hosting deployment for the Clinical Diary app.

## Overview

The Clinical Diary web app is deployed to Firebase Hosting via GitHub Actions. Authentication uses **Workload Identity Federation** - the most secure method that requires no stored secrets.

## Prerequisites

- Google Cloud CLI (`gcloud`) installed and authenticated
- Access to the `hht-diary-mvp` Google Cloud project with appropriate permissions
- Admin access to the GitHub repository

## Setup Instructions (Workload Identity Federation)

### 1. Create Service Account

```bash
# Create the service account (if not already created)
gcloud iam service-accounts create firebase-deploy \
  --project=hht-diary-mvp \
  --display-name="Firebase Deploy (GitHub Actions)"

# Grant Firebase Hosting Admin role
gcloud projects add-iam-policy-binding hht-diary-mvp \
  --member="serviceAccount:firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com" \
  --role="roles/firebasehosting.admin"
```

### 2. Create Workload Identity Pool

```bash
# Create the workload identity pool
gcloud iam workload-identity-pools create "github-actions" \
  --project="hht-diary-mvp" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### 3. Create Workload Identity Provider

```bash
# Create the OIDC provider for GitHub
gcloud iam workload-identity-pools providers create-oidc "github" \
  --project="hht-diary-mvp" \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'Cure-HHT'" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### 4. Allow Service Account Impersonation

```bash
# Get the project number (needed for the principal)
PROJECT_NUMBER=$(gcloud projects describe hht-diary-mvp --format="value(projectNumber)")

# Allow the GitHub Actions workflow to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  "firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com" \
  --project="hht-diary-mvp" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions/attribute.repository/Cure-HHT/hht_diary"
```

### 5. Get the Workload Identity Provider Resource Name

```bash
# Get the full provider resource name (needed for workflow)
gcloud iam workload-identity-pools providers describe "github" \
  --project="hht-diary-mvp" \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --format="value(name)"
```

This outputs something like:

```text
projects/681337116402/locations/global/workloadIdentityPools/github-actions/providers/github
```

### 6. Add GitHub Secrets

Go to GitHub repository: **Settings > Secrets and variables > Actions**

Add two secrets:

- **WIF_PROVIDER**: The provider resource name from step 5
- **WIF_SERVICE_ACCOUNT**: `firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com`

## How It Works

The CI workflow uses Workload Identity Federation for keyless authentication:

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

- name: Deploy to Firebase Hosting
  run: firebase deploy --only hosting
```

No secrets are stored - GitHub Actions presents an OIDC token that Google Cloud validates directly.

## Deployment Triggers

- **Automatic**: Push to `main` branch (after tests pass)
- **Manual**: Can be triggered via GitHub Actions workflow_dispatch

## Version Bumping

Version is automatically bumped via the pre-push git hook when changes are made to `apps/clinical_diary/`. The hook:

1. Runs `dart pub bump patch` to increment the patch version
2. Stages the updated `pubspec.yaml`
3. Amends the commit to include the version bump

The deployed `version.json` reflects the version from `pubspec.yaml`.

## Troubleshooting

### Permission Denied

If deployment fails with permission errors, verify the service account has the correct role:

```bash
gcloud projects get-iam-policy hht-diary-mvp \
  --flatten="bindings[].members" \
  --filter="bindings.members:firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com"
```

### Workload Identity Issues

If authentication fails, verify the WIF setup:

```bash
# Check the pool exists
gcloud iam workload-identity-pools describe "github-actions" \
  --project="hht-diary-mvp" \
  --location="global"

# Check the provider exists
gcloud iam workload-identity-pools providers describe "github" \
  --project="hht-diary-mvp" \
  --location="global" \
  --workload-identity-pool="github-actions"

# Check service account IAM bindings
gcloud iam service-accounts get-iam-policy \
  firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com
```

### Repository Mismatch

The attribute condition restricts access to the `Cure-HHT` organization. If the repo is forked or moved, update the provider's attribute condition.

## Related Documentation

- [Firebase Functions Setup](./FIREBASE_FUNCTIONS_SETUP.md)
- [Google Cloud Auth Action](https://github.com/google-github-actions/auth)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
