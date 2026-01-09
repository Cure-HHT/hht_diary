# Cost Control Cloud Function

Automatically stops Cloud Run services when budget is exceeded to prevent runaway cloud costs.

## Overview

This Cloud Function is triggered by Pub/Sub messages from GCP billing budget alerts. When the budget threshold is exceeded (100%), it automatically scales all Cloud Run services in the project to 0 instances, effectively stopping billing.

**Important**: This is only deployed to non-production environments (dev, qa, uat). Production environments receive alerts but do NOT auto-stop to avoid service disruptions.

## How It Works

```
Budget exceeded (100%)
    → Pub/Sub message sent to {sponsor}-{env}-budget-alerts topic
    → Cloud Function triggered
    → All Cloud Run services scaled to 0 instances
    → Billing stops
```

## Why This Exists

A common cause of unexpected cloud bills:

1. **Health check misconfiguration** - Cloud Run health checks fail, causing rapid container restarts
2. **Always-allocated CPU** - Paying for idle time when `cpu_idle = false`
3. **Restart loops** - Container crashes, restarts, crashes again
4. **No max instance limits** - Autoscaling without bounds

The $300/day incident that prompted this was caused by a Dart container with an aggressive health check timing. The container couldn't JIT compile fast enough, failed the probe, restarted, repeat forever.

## Deployment

The Terraform bootstrap creates the infrastructure (Pub/Sub topic, subscription, service account). Deploy the function manually or via CI/CD:

```bash
# Set variables
SPONSOR="callisto"
ENV="dev"
PROJECT_ID="cure-hht-${SPONSOR}-${ENV}"
REGION="europe-west9"
SERVICE_ACCOUNT="${SPONSOR}-${ENV}-cost-ctrl@${PROJECT_ID}.iam.gserviceaccount.com"

# Deploy the function
gcloud functions deploy ${SPONSOR}-${ENV}-cost-control \
  --gen2 \
  --runtime=python311 \
  --region=${REGION} \
  --source=. \
  --entry-point=stop_cloud_run_services \
  --trigger-topic=${SPONSOR}-${ENV}-budget-alerts \
  --service-account=${SERVICE_ACCOUNT} \
  --set-env-vars=GCP_PROJECT=${PROJECT_ID},REGION=${REGION} \
  --memory=256MB \
  --timeout=60s \
  --project=${PROJECT_ID}
```

## Recovery

After services are stopped, to restore them:

### Option 1: GCP Console

1. Go to Cloud Run in GCP Console
2. Select the service
3. Edit & Deploy New Revision
4. Set Min instances back to 1 (or desired value)
5. Set Max instances back to 5 (or desired value)
6. Deploy

### Option 2: gcloud CLI

```bash
gcloud run services update diary-server \
  --min-instances=1 \
  --max-instances=5 \
  --region=europe-west9 \
  --project=cure-hht-${SPONSOR}-${ENV}
```

### Option 3: Re-run Terraform

```bash
cd infrastructure/terraform/scripts
doppler run -- ./deploy-environment.sh ${SPONSOR} ${ENV} --apply
```

## Testing

To test without exceeding budget, manually send a test message to the Pub/Sub topic:

```bash
# Create a test budget notification
cat > /tmp/test-budget-alert.json << 'EOF'
{
  "budgetDisplayName": "callisto-dev-budget",
  "costAmount": 600,
  "budgetAmount": 500,
  "alertThresholdExceeded": 1.2
}
EOF

# Publish to the topic
gcloud pubsub topics publish callisto-dev-budget-alerts \
  --message="$(cat /tmp/test-budget-alert.json)" \
  --project=cure-hht-callisto-dev
```

## Disabling Cost Controls

To disable for a specific sponsor, set in the bootstrap tfvars:

```hcl
# bootstrap/sponsor-configs/{sponsor}.tfvars
enable_cost_controls = false
```

This will:
- Still create budget alerts
- NOT create the Pub/Sub topic or service account
- NOT auto-stop services (alerts only)

## Related Files

- `infrastructure/terraform/modules/billing-budget/main.tf` - Creates Pub/Sub infrastructure
- `infrastructure/terraform/modules/cloud-run/main.tf` - Cloud Run with safe health check timeouts
- `infrastructure/terraform/bootstrap/variables.tf` - `enable_cost_controls` variable
