#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Setup script for Firebase Cloud Functions permissions
# This script configures a Firebase/GCP project to allow public access to Cloud Functions
# and grants necessary Firestore permissions.
#
# Usage: ./setup-firebase-permissions.sh <project-id> [region]
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - User must have Owner or appropriate admin roles on the project
#   - If in an organization, user should have Org Policy Admin role

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REGION="${2:-europe-west1}"
FUNCTIONS="enroll health sync getRecords"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Project ID required${NC}"
    echo "Usage: $0 <project-id> [region]"
    echo "Example: $0 hht-diary-mvp europe-west1"
    exit 1
fi

PROJECT_ID="$1"

echo "=============================================="
echo "Firebase Cloud Functions Permission Setup"
echo "=============================================="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Functions: $FUNCTIONS"
echo ""

# Verify gcloud is authenticated
echo -e "${YELLOW}Checking gcloud authentication...${NC}"
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$ACCOUNT" ]; then
    echo -e "${RED}Error: Not authenticated with gcloud${NC}"
    echo "Run: gcloud auth login"
    exit 1
fi
echo -e "${GREEN}Authenticated as: $ACCOUNT${NC}"

# Set the project
echo -e "\n${YELLOW}Setting project to $PROJECT_ID...${NC}"
gcloud config set project "$PROJECT_ID" 2>/dev/null
echo -e "${GREEN}Project set${NC}"

# Get project number
echo -e "\n${YELLOW}Getting project number...${NC}"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)' 2>/dev/null)
if [ -z "$PROJECT_NUMBER" ]; then
    echo -e "${RED}Error: Could not get project number. Check project ID and permissions.${NC}"
    exit 1
fi
echo -e "${GREEN}Project number: $PROJECT_NUMBER${NC}"

# Enable required APIs
echo -e "\n${YELLOW}Enabling required APIs...${NC}"
APIS="cloudfunctions.googleapis.com firestore.googleapis.com orgpolicy.googleapis.com"
for api in $APIS; do
    echo "  Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null || true
done
echo -e "${GREEN}APIs enabled${NC}"

# Check if project is in an organization
echo -e "\n${YELLOW}Checking organization membership...${NC}"
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format='value(id)' 2>/dev/null | tail -1)
if [ -n "$ORG_ID" ] && [ "$ORG_ID" != "$PROJECT_ID" ]; then
    echo "Project is in organization: $ORG_ID"

    # Check if org policy is blocking allUsers
    echo -e "\n${YELLOW}Checking organization policy...${NC}"
    ORG_POLICY=$(gcloud org-policies describe iam.allowedPolicyMemberDomains --organization="$ORG_ID" 2>/dev/null || echo "")

    if echo "$ORG_POLICY" | grep -q "allowedValues"; then
        echo -e "${YELLOW}Organization has domain restrictions. Creating project-level override...${NC}"

        # Create policy override file
        cat > /tmp/policy-override.yaml << EOF
name: projects/$PROJECT_ID/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
  - allowAll: true
EOF

        # Apply the override
        if gcloud org-policies set-policy /tmp/policy-override.yaml --project="$PROJECT_ID" 2>/dev/null; then
            echo -e "${GREEN}Organization policy override created${NC}"
            echo "Waiting 15 seconds for policy to propagate..."
            sleep 15
        else
            echo -e "${RED}Warning: Could not set org policy override.${NC}"
            echo "You may need Org Policy Admin role or contact your organization admin."
            echo "Continuing anyway - IAM bindings may fail..."
        fi

        rm -f /tmp/policy-override.yaml
    else
        echo -e "${GREEN}No domain restrictions found${NC}"
    fi
else
    echo "Project is not in an organization"
fi

# Grant Firestore access to compute service account
echo -e "\n${YELLOW}Granting Firestore access to Cloud Functions service account...${NC}"
SA_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "  Granting roles/datastore.owner to $SA_EMAIL..."
if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/datastore.owner" \
    --condition=None \
    --quiet 2>/dev/null; then
    echo -e "${GREEN}Firestore access granted${NC}"
else
    echo -e "${RED}Warning: Could not grant Firestore access${NC}"
fi

# Check if functions exist
echo -e "\n${YELLOW}Checking if Cloud Functions are deployed...${NC}"
DEPLOYED_FUNCTIONS=$(gcloud functions list --region="$REGION" --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")

if [ -z "$DEPLOYED_FUNCTIONS" ]; then
    echo -e "${YELLOW}No functions found in region $REGION${NC}"
    echo "Deploy functions first with: firebase deploy --only functions"
    echo ""
    echo "After deploying, run this script again to set IAM permissions."
    exit 0
fi

echo "Found deployed functions:"
echo "$DEPLOYED_FUNCTIONS" | while read fn; do echo "  - $fn"; done

# Grant public access to each function
echo -e "\n${YELLOW}Granting public access to Cloud Functions...${NC}"
for fn in $FUNCTIONS; do
    if echo "$DEPLOYED_FUNCTIONS" | grep -q "$fn"; then
        echo "  Setting allUsers invoker on $fn..."
        if gcloud functions add-iam-policy-binding "$fn" \
            --region="$REGION" \
            --member="allUsers" \
            --role="roles/cloudfunctions.invoker" \
            --project="$PROJECT_ID" \
            --quiet 2>/dev/null; then
            echo -e "    ${GREEN}Done${NC}"
        else
            echo -e "    ${RED}Failed - may need org policy override${NC}"
        fi
    else
        echo -e "  ${YELLOW}Skipping $fn (not deployed)${NC}"
    fi
done

# Test the health endpoint
echo -e "\n${YELLOW}Testing health endpoint...${NC}"
HEALTH_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/health"
echo "  URL: $HEALTH_URL"

sleep 5  # Wait for IAM propagation

RESPONSE=$(curl -s "$HEALTH_URL" 2>/dev/null || echo "")
if echo "$RESPONSE" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}Health check passed!${NC}"
    echo "  Response: $RESPONSE"
else
    echo -e "${YELLOW}Health check returned unexpected response:${NC}"
    echo "  $RESPONSE"
    echo ""
    echo "This may be due to IAM propagation delay. Wait a minute and test manually:"
    echo "  curl $HEALTH_URL"
fi

# Summary
echo ""
echo "=============================================="
echo "Setup Complete"
echo "=============================================="
echo ""
echo "Function URLs:"
for fn in $FUNCTIONS; do
    echo "  $fn: https://${REGION}-${PROJECT_ID}.cloudfunctions.net/$fn"
done
echo ""
echo "Hosting URLs (if Firebase Hosting is configured):"
echo "  https://${PROJECT_ID}.web.app/api/health"
echo "  https://${PROJECT_ID}.web.app/api/enroll"
echo "  https://${PROJECT_ID}.web.app/api/sync"
echo "  https://${PROJECT_ID}.web.app/api/getRecords"
echo ""
echo "Next steps:"
echo "  1. Update cors.ts with your hosting domain"
echo "  2. Update firebase.json hosting rewrites if needed"
echo "  3. Deploy: firebase deploy"
echo "  4. Test: curl -X POST https://${PROJECT_ID}.web.app/api/enroll -H 'Content-Type: application/json' -d '{\"code\":\"CUREHHT1\"}'"
