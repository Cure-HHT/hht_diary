#!/usr/bin/env bash
# ============================================================================
# Test Gmail API Domain-Wide Delegation
# ============================================================================
#
# This script verifies that the Gmail service account has domain-wide
# delegation configured correctly in Google Workspace Admin Console.
#
# PREREQUISITES:
#   1. gcloud CLI installed and authenticated
#   2. User running this script has serviceAccountTokenCreator role on the Gmail SA
#   3. Domain-wide delegation configured in Google Workspace Admin Console
#
# USAGE:
#   ./test-gmail-delegation.sh [recipient-email]
#
# If no recipient is specified, sends to mike.bushe@anspar.org
# ============================================================================
set -e
# Configuration
GMAIL_SA="org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com"
GMAIL_SA_CLIENT_ID="102258146806186049472"
SENDER_EMAIL="support@anspar.org"
RECIPIENT_EMAIL="${1:-mike.bushe@anspar.org}"
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo ""
echo "============================================================"
echo "  Gmail API Domain-Wide Delegation Test"
echo "============================================================"
echo ""
echo "Service Account: $GMAIL_SA"
echo "Client ID:       $GMAIL_SA_CLIENT_ID"
echo "Sender Email:    $SENDER_EMAIL"
echo "Recipient:       $RECIPIENT_EMAIL"
echo ""
# Step 1: Check gcloud auth
echo -n "1. Checking gcloud authentication... "
if ! gcloud auth application-default print-access-token &>/dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "   Run: gcloud auth application-default login"
    exit 1
fi
echo -e "${GREEN}OK${NC}"
# Step 2: Check WIF impersonation permission and get token with domain-wide delegation
echo -n "2. Testing WIF impersonation permission... "
ADC_TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null)
# For domain-wide delegation, we must use signJwt with a 'sub' claim
# The generateAccessToken API does NOT support user impersonation
NOW=$(date +%s)
EXP=$((NOW + 3600))
# Create JWT claims with 'sub' for domain-wide delegation
JWT_CLAIMS=$(printf '{"iss":"%s","sub":"%s","scope":"https://www.googleapis.com/auth/gmail.send","aud":"https://oauth2.googleapis.com/token","iat":%d,"exp":%d}' \
  "$GMAIL_SA" "$SENDER_EMAIL" "$NOW" "$EXP")
JWT_CLAIMS_ESCAPED=$(echo "$JWT_CLAIMS" | sed 's/"/\\"/g')
# Sign the JWT using the service account
SIGN_RESPONSE=$(curl -s -X POST \
  "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${GMAIL_SA}:signJwt" \
  -H "Authorization: Bearer $ADC_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"payload\": \"$JWT_CLAIMS_ESCAPED\"}")
if echo "$SIGN_RESPONSE" | grep -q "error"; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "   You don't have permission to sign JWTs for the Gmail SA."
    echo "   An admin needs to run:"
    echo ""
    echo "   gcloud iam service-accounts add-iam-policy-binding \\"
    echo "     $GMAIL_SA \\"
    echo "     --member=\"user:YOUR_EMAIL@anspar.org\" \\"
    echo "     --role=\"roles/iam.serviceAccountTokenCreator\" \\"
    echo "     --project=cure-hht-admin"
    echo ""
    echo "   Error: $SIGN_RESPONSE"
    exit 1
fi
SIGNED_JWT=$(echo "$SIGN_RESPONSE" | grep -o '"signedJwt": *"[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}OK${NC}"
# Step 2b: Exchange JWT for access token (this validates domain-wide delegation)
echo -n "2b. Exchanging JWT for access token... "
TOKEN_RESPONSE=$(curl -s -X POST \
  "https://oauth2.googleapis.com/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${SIGNED_JWT}")
if echo "$TOKEN_RESPONSE" | grep -q "error"; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "   JWT exchange failed. This usually means domain-wide delegation"
    echo "   is not configured correctly in Google Workspace Admin Console."
    echo ""
    echo "   Error: $TOKEN_RESPONSE"
    exit 1
fi
GMAIL_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token": *"[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}OK${NC}"
# Step 3: Test Gmail API send (this tests domain-wide delegation)
echo -n "3. Testing Gmail API send (domain-wide delegation)... "
# Create test email
EMAIL_RAW="From: Clinical Trial Portal <${SENDER_EMAIL}>
To: ${RECIPIENT_EMAIL}
Subject: Gmail API Test - $(date '+%Y-%m-%d %H:%M:%S')
Content-Type: text/plain; charset=utf-8
This is a test email to verify Gmail API domain-wide delegation.
If you received this email, the configuration is CORRECT!
Configuration details:
- Service Account: ${GMAIL_SA}
- Client ID: ${GMAIL_SA_CLIENT_ID}
- Sender: ${SENDER_EMAIL}
- Scope: https://www.googleapis.com/auth/gmail.send
---
Sent via Gmail API with Workload Identity Federation"
# Base64url encode
EMAIL_B64=$(echo -n "$EMAIL_RAW" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n')
# Send via Gmail API
SEND_RESPONSE=$(curl -s -X POST \
  "https://gmail.googleapis.com/gmail/v1/users/${SENDER_EMAIL}/messages/send" \
  -H "Authorization: Bearer $GMAIL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"raw\": \"$EMAIL_B64\"}")
if echo "$SEND_RESPONSE" | grep -q '"id"'; then
    MESSAGE_ID=$(echo "$SEND_RESPONSE" | grep -o '"id": *"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}OK${NC}"
    echo ""
    echo "============================================================"
    echo -e "  ${GREEN}SUCCESS!${NC} Domain-wide delegation is configured correctly."
    echo "============================================================"
    echo ""
    echo "  Message ID: $MESSAGE_ID"
    echo "  Check inbox: $RECIPIENT_EMAIL"
    echo ""
    exit 0
fi
# Check for specific errors
if echo "$SEND_RESPONSE" | grep -q "failedPrecondition\|Precondition check failed"; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "============================================================"
    echo -e "  ${RED}DOMAIN-WIDE DELEGATION NOT CONFIGURED${NC}"
    echo "============================================================"
    echo ""
    echo "  A Google Workspace Admin must configure domain-wide delegation:"
    echo ""
    echo "  1. Go to: https://admin.google.com"
    echo "  2. Navigate to: Security → Access and data control → API Controls"
    echo "  3. Click: Domain-wide Delegation → Add new"
    echo "  4. Enter:"
    echo "     - Client ID: ${GMAIL_SA_CLIENT_ID}"
    echo "     - OAuth Scopes: https://www.googleapis.com/auth/gmail.send"
    echo "  5. Click: Authorize"
    echo ""
    echo "  After configuring, wait 2-5 minutes and run this script again."
    echo ""
    exit 1
fi
if echo "$SEND_RESPONSE" | grep -q "insufficientPermissions\|PERMISSION_DENIED"; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "  Permission denied. The scope may not be authorized."
    echo "  Ensure 'https://www.googleapis.com/auth/gmail.send' is in the delegation."
    echo ""
    echo "  Response: $SEND_RESPONSE"
    exit 1
fi
# Unknown error
echo -e "${RED}FAILED${NC}"
echo ""
echo "  Unexpected error:"
echo "  $SEND_RESPONSE"
exit 1