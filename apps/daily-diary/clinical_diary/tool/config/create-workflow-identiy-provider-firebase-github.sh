#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00043: Automated Deployment Pipeline
#
# Create Firebase Service Account with Workload Identity Federation for GitHub Actions
# This avoids service account keys (which may be blocked by org policy)
#
# Usage: ./firebase-service-account.sh [PROJECT_ID] [GITHUB_ORG/REPO]
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Owner/Admin access to the GCP project

set -euo pipefail

PROJECT_ID="${1:-hht-diary-dev}"
GITHUB_REPO="${2:-Cure-HHT/hht_diary}"
SA_NAME="github-actions-firebase"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-provider"
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

echo "Setting up Workload Identity Federation for GitHub Actions"
echo "Project: ${PROJECT_ID}"
echo "GitHub Repo: ${GITHUB_REPO}"
echo ""

# Enable required APIs
echo "1. Enabling required APIs..."
gcloud services enable iamcredentials.googleapis.com --project=${PROJECT_ID}
gcloud services enable sts.googleapis.com --project=${PROJECT_ID}

# Create the service account (if not exists)
echo "2. Creating service account..."
gcloud iam service-accounts create ${SA_NAME} \
  --project=${PROJECT_ID} \
  --display-name="GitHub Actions Firebase Deploy" \
  2>/dev/null || echo "   Service account already exists, continuing..."

# Grant Firebase Hosting Admin role
echo "3. Granting Firebase Hosting Admin role..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/firebasehosting.admin" \
  --quiet

# Grant Cloud Run Viewer (needed for hosting deploys)
echo "4. Granting Cloud Run Viewer role..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.viewer" \
  --quiet

# Create Workload Identity Pool
echo "5. Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create ${POOL_NAME} \
  --project=${PROJECT_ID} \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  2>/dev/null || echo "   Pool already exists, continuing..."

# Create Workload Identity Provider
echo "6. Creating Workload Identity Provider..."
gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_NAME} \
  --project=${PROJECT_ID} \
  --location="global" \
  --workload-identity-pool=${POOL_NAME} \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '$(echo ${GITHUB_REPO} | cut -d'/' -f1)'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  2>/dev/null || echo "   Provider already exists, continuing..."

# Allow GitHub Actions to impersonate the service account
echo "7. Granting GitHub Actions permission to impersonate service account..."
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO}"

# Get the Workload Identity Provider resource name
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"

echo ""
echo "============================================"
echo "Workload Identity Federation configured!"
echo "============================================"
echo ""
echo "Add these secrets to GitHub (or Doppler):"
echo ""
echo "  WIF_PROVIDER=${WIF_PROVIDER}"
echo "  WIF_SERVICE_ACCOUNT=${SA_EMAIL}"
echo ""
echo "Update your GitHub Actions workflow to use:"
echo ""
cat << 'EOF'
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: # Not needed with WIF
          projectId: hht-diary-dev
          channelId: live
          entryPoint: apps/daily-diary/clinical_diary
EOF
