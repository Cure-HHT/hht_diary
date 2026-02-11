#!/bin/bash
# infrastructure/docker/email-job/send-email.sh
#
# Cloud Run Job: Send a test email via Gmail API using WIF + domain-wide delegation.
# Replicates the auth flow from portal_functions EmailService (signJwt approach).
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00049: Ancillary Platform Services (email notification with audit trail)
#   REQ-o00041: Infrastructure as Code for Cloud Resources (Cloud Run job definition)
#   REQ-o00048: Audit Log Monitoring (email delivery logging for FDA compliance)
#
# Required env vars:
#   EMAIL_SVC_ACCT  - Gmail SA with domain-wide delegation
#   EMAIL_SENDER                 - Workspace email to send from (e.g., support@anspar.org)
#
# Optional env vars:
#   RECIPIENT_EMAIL  - Override recipient (default: devops Slack channel)
#   SUBJECT          - Override subject line
#   GCP_PROEJCT_ID   - Used in default subject for context (optional, auto-detected by metadata server on Cloud Run)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

: "${EMAIL_SVC_ACCT:?EMAIL_SVC_ACCT is required}"
: "${EMAIL_SENDER:?EMAIL_SENDER is required}"

RECIPIENT_EMAIL="${RECIPIENT_EMAIL:-devops-aaaasoq26bszfuqn5ckvcay3wm@anspar.slack.com}"
SUBJECT="${SUBJECT:-[Cloud Run] Test email from ${GCP_PROJECT_ID}}"
BODY="Test email sent from Cloud Run email-job at $(date -u '+%Y-%m-%dT%H:%M:%SZ').\n\nSender SA: ${EMAIL_SVC_ACCT}\nFrom: ${EMAIL_SENDER}\nTo: ${RECIPIENT_EMAIL}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log() {
    local level="$1"; shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [$level] $*" >&2
}
log_info()  { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }

# ---------------------------------------------------------------------------
# Step 1: Get ADC access token (from metadata server on Cloud Run, or gcloud locally)
# ---------------------------------------------------------------------------

get_adc_token() {
    log_info "Obtaining ADC access token..."

    local token
    # Try metadata server first (Cloud Run / GCE)
    if token=$(curl -sf -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
        2>/dev/null | jq -r '.access_token'); then
        if [[ -n "$token" && "$token" != "null" ]]; then
            log_info "Got token from metadata server"
            echo "$token"
            return
        fi
    fi

    # Fall back to gcloud (local development)
    if token=$(gcloud auth print-access-token 2>/dev/null); then
        log_info "Got token from gcloud CLI"
        echo "$token"
        return
    fi

    log_error "Could not obtain ADC token from metadata server or gcloud"
    exit 1
}

# ---------------------------------------------------------------------------
# Step 2: Sign JWT with domain-wide delegation (sub claim)
# ---------------------------------------------------------------------------

sign_jwt() {
    local adc_token="$1"

    local now exp jwt_claims
    now=$(date +%s)
    exp=$((now + 3600))

    jwt_claims=$(jq -n \
        --arg iss "$EMAIL_SVC_ACCT" \
        --arg sub "$EMAIL_SENDER" \
        --arg aud "https://oauth2.googleapis.com/token" \
        --argjson iat "$now" \
        --argjson exp "$exp" \
        '{
            iss: $iss,
            sub: $sub,
            scope: "https://www.googleapis.com/auth/gmail.send",
            aud: $aud,
            iat: $iat,
            exp: $exp
        }')

    log_info "Signing JWT for ${EMAIL_SVC_ACCT} (sub: ${EMAIL_SENDER})..."

    local response signed_jwt
    response=$(curl -s -X POST \
        "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${EMAIL_SVC_ACCT}:signJwt" \
        -H "Authorization: Bearer ${adc_token}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg payload "$jwt_claims" '{payload: $payload}')")

    signed_jwt=$(echo "$response" | jq -r '.signedJwt')

    if [[ -z "$signed_jwt" || "$signed_jwt" == "null" ]]; then
        log_error "signJwt failed: ${response}"
        exit 2
    fi

    log_info "JWT signed successfully"
    echo "$signed_jwt"
}

# ---------------------------------------------------------------------------
# Step 3: Exchange signed JWT for Gmail-scoped access token
# ---------------------------------------------------------------------------

exchange_jwt_for_token() {
    local signed_jwt="$1"

    log_info "Exchanging signed JWT for Gmail access token..."

    local response access_token
    response=$(curl -s -X POST \
        "https://oauth2.googleapis.com/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signed_jwt}")

    access_token=$(echo "$response" | jq -r '.access_token')

    if [[ -z "$access_token" || "$access_token" == "null" ]]; then
        log_error "Token exchange failed (check domain-wide delegation): ${response}"
        exit 3
    fi

    log_info "Got Gmail access token"
    echo "$access_token"
}

# ---------------------------------------------------------------------------
# Step 4: Send email via Gmail API
# ---------------------------------------------------------------------------

send_email() {
    local gmail_token="$1"

    # Build MIME message
    local mime_message
    mime_message=$(printf "From: %s\r\nTo: %s\r\nSubject: %s\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n%b" \
        "$EMAIL_SENDER" "$RECIPIENT_EMAIL" "$SUBJECT" "$BODY")

    # Base64url encode (Gmail API requirement)
    local raw
    raw=$(echo -n "$mime_message" | base64 | tr '+/' '-_' | tr -d '=\n')

    log_info "Sending email to ${RECIPIENT_EMAIL}..."

    local response message_id
    response=$(curl -s -X POST \
        "https://gmail.googleapis.com/gmail/v1/users/${EMAIL_SENDER}/messages/send" \
        -H "Authorization: Bearer ${gmail_token}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg raw "$raw" '{raw: $raw}')")

    message_id=$(echo "$response" | jq -r '.id')

    if [[ -z "$message_id" || "$message_id" == "null" ]]; then
        log_error "Gmail API send failed: ${response}"
        exit 4
    fi

    log_info "Email sent successfully (messageId: ${message_id})"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log_info "=========================================="
    log_info "Cloud Run Email Job - Starting"
    log_info "SA:   ${EMAIL_SVC_ACCT}"
    log_info "From: ${EMAIL_SENDER}"
    log_info "To:   ${RECIPIENT_EMAIL}"
    log_info "=========================================="

    local adc_token signed_jwt gmail_token
    adc_token=$(get_adc_token)
    signed_jwt=$(sign_jwt "$adc_token")
    gmail_token=$(exchange_jwt_for_token "$signed_jwt")
    send_email "$gmail_token"

    log_info "=========================================="
    log_info "Cloud Run Email Job - COMPLETE"
    log_info "=========================================="
}

main "$@"
