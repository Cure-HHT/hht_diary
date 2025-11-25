# Cloud Run Deployment Guide

**Version**: 1.0
**Status**: Active
**Created**: 2025-11-25

> **Purpose**: Guide for deploying the Clinical Trial Diary Dart backend and Flutter web portal to Google Cloud Run.

---

## Executive Summary

The Clinical Trial Diary Platform deploys two Cloud Run services per sponsor:

1. **API Server**: Dart backend handling database operations, authentication, and business logic
2. **Web Portal**: Flutter web application for investigators and administrators

Both services use private connectivity to Cloud SQL and integrate with Identity Platform for authentication.

---

## Architecture Overview

```
                    ┌─────────────────────────────────────────────┐
                    │           GCP Project (per sponsor)         │
                    │                                             │
 Users ─────────────┼──▶ Cloud Run                               │
 (HTTPS)            │    ├─ API Server (Dart)                    │
                    │    │   └─▶ Cloud SQL (private IP)          │
                    │    │   └─▶ Secret Manager                  │
                    │    │   └─▶ Identity Platform (verify JWT)  │
                    │    │                                        │
                    │    └─ Web Portal (Flutter/nginx)           │
                    │        └─▶ API Server (internal)           │
                    │                                             │
                    │  Artifact Registry                          │
                    │    └─ Container images                      │
                    │                                             │
                    └─────────────────────────────────────────────┘
```

---

## Prerequisites

1. **GCP Project Configured**: See docs/gcp/project-structure.md
2. **Cloud SQL Instance Running**: See docs/gcp/cloud-sql-setup.md
3. **Identity Platform Configured**: See docs/gcp/identity-platform-setup.md
4. **APIs Enabled**:
   ```bash
   gcloud services enable \
     run.googleapis.com \
     artifactregistry.googleapis.com \
     cloudbuild.googleapis.com \
     secretmanager.googleapis.com \
     vpcaccess.googleapis.com
   ```

---

## Service Account Setup

### Create Service Accounts

```bash
export PROJECT_ID="hht-diary-orion-prod"
export SPONSOR="orion"
export ENV="prod"

# API Server service account
gcloud iam service-accounts create api-server \
  --display-name="API Server" \
  --project=$PROJECT_ID

# Portal service account
gcloud iam service-accounts create portal-server \
  --display-name="Portal Server" \
  --project=$PROJECT_ID

# CI/CD deployer
gcloud iam service-accounts create cicd-deployer \
  --display-name="CI/CD Deployer" \
  --project=$PROJECT_ID
```

### Grant Permissions

```bash
# API Server permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:api-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:api-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:api-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

# CI/CD permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cicd-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cicd-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cicd-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

---

## Artifact Registry Setup

### Create Repository

```bash
export REGION="europe-west1"  # EU region for GDPR compliance

gcloud artifacts repositories create ${SPONSOR}-images \
  --repository-format=docker \
  --location=$REGION \
  --description="Container images for ${SPONSOR}" \
  --project=$PROJECT_ID
```

### Configure Docker Authentication

```bash
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

---

## API Server Deployment

### Dockerfile

```dockerfile
# apps/api_server/Dockerfile
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./
RUN dart pub get

# Copy source code
COPY . .

# Build AOT compiled executable
RUN dart compile exe bin/server.dart -o bin/server

# Production image
FROM debian:bookworm-slim

# Install CA certificates for HTTPS
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy compiled binary
COPY --from=build /app/bin/server /app/server

# Cloud Run expects PORT environment variable
ENV PORT=8080
EXPOSE 8080

CMD ["/app/server"]
```

### Build and Push

```bash
cd apps/api_server

# Build image
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/api-server:latest .

# Push to Artifact Registry
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/api-server:latest
```

### Deploy to Cloud Run

```bash
# Get Cloud SQL connection name
INSTANCE_CONNECTION_NAME="${PROJECT_ID}:${REGION}:${SPONSOR}-db-${ENV}"

# Deploy API server
gcloud run deploy api-${SPONSOR}-${ENV} \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/api-server:latest \
  --platform=managed \
  --region=$REGION \
  --project=$PROJECT_ID \
  --service-account=api-server@${PROJECT_ID}.iam.gserviceaccount.com \
  --add-cloudsql-instances=$INSTANCE_CONNECTION_NAME \
  --vpc-connector=${SPONSOR}-vpc-connector \
  --vpc-egress=private-ranges-only \
  --set-secrets=DATABASE_PASSWORD=db-app-password:latest \
  --set-env-vars="\
DATABASE_HOST=/cloudsql/${INSTANCE_CONNECTION_NAME},\
DATABASE_NAME=clinical_diary,\
DATABASE_USER=app_user,\
SPONSOR_ID=${SPONSOR},\
ENVIRONMENT=${ENV}" \
  --min-instances=1 \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1 \
  --timeout=60s \
  --concurrency=80 \
  --ingress=all \
  --allow-unauthenticated
```

### Configure Custom Domain (Optional)

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service=api-${SPONSOR}-${ENV} \
  --domain=api.${SPONSOR}.clinicaltrial.app \
  --region=$REGION \
  --project=$PROJECT_ID
```

---

## Web Portal Deployment

### Dockerfile

```dockerfile
# apps/web_portal/Dockerfile

## Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./
RUN flutter pub get

# Copy source code
COPY . .

# Build arguments for environment configuration
ARG FIREBASE_API_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG GCP_PROJECT_ID
ARG FIREBASE_APP_ID
ARG API_BASE_URL

# Build web app
RUN flutter build web --release --web-renderer html \
    --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY \
    --dart-define=FIREBASE_AUTH_DOMAIN=$FIREBASE_AUTH_DOMAIN \
    --dart-define=GCP_PROJECT_ID=$GCP_PROJECT_ID \
    --dart-define=FIREBASE_APP_ID=$FIREBASE_APP_ID \
    --dart-define=API_BASE_URL=$API_BASE_URL

## Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built web app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
```

### nginx Configuration

```nginx
# apps/web_portal/nginx.conf
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing - serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://*.run.app https://*.googleapis.com; frame-ancestors 'none';";

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Build and Deploy Portal

```bash
cd apps/web_portal

# Build with environment-specific configuration
docker build \
  --build-arg FIREBASE_API_KEY="AIza..." \
  --build-arg FIREBASE_AUTH_DOMAIN="${PROJECT_ID}.firebaseapp.com" \
  --build-arg GCP_PROJECT_ID="${PROJECT_ID}" \
  --build-arg FIREBASE_APP_ID="1:123456789:web:abc123" \
  --build-arg API_BASE_URL="https://api-${SPONSOR}-${ENV}-xxxxx-uc.a.run.app" \
  -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/portal:latest .

# Push to Artifact Registry
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/portal:latest

# Deploy to Cloud Run
gcloud run deploy portal-${SPONSOR}-${ENV} \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/${SPONSOR}-images/portal:latest \
  --platform=managed \
  --region=$REGION \
  --project=$PROJECT_ID \
  --service-account=portal-server@${PROJECT_ID}.iam.gserviceaccount.com \
  --min-instances=0 \
  --max-instances=5 \
  --memory=256Mi \
  --cpu=1 \
  --timeout=60s \
  --concurrency=100 \
  --ingress=all \
  --allow-unauthenticated
```

---

## VPC Connector Setup

Required for private Cloud SQL access:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create ${SPONSOR}-vpc-connector \
  --region=$REGION \
  --network=default \
  --range=10.8.0.0/28 \
  --min-instances=2 \
  --max-instances=10 \
  --project=$PROJECT_ID
```

---

## CI/CD with GitHub Actions

### Workflow Configuration

```yaml
# .github/workflows/deploy-cloud-run.yml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      sponsor:
        description: 'Sponsor to deploy'
        required: true
        type: choice
        options:
          - orion
          - andromeda
      environment:
        description: 'Environment'
        required: true
        type: choice
        options:
          - staging
          - prod

env:
  REGION: europe-west1  # EU region for GDPR compliance

jobs:
  deploy-api:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.DEPLOY_SA }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build and push API image
        run: |
          docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/api-server:${{ github.sha }} ./apps/api_server
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/api-server:${{ github.sha }}

      - name: Deploy to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: api-${{ inputs.sponsor }}-${{ inputs.environment }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/api-server:${{ github.sha }}
          region: ${{ env.REGION }}
          project_id: ${{ vars.PROJECT_ID }}

  deploy-portal:
    runs-on: ubuntu-latest
    needs: deploy-api
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.DEPLOY_SA }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Get API URL
        id: api-url
        run: |
          API_URL=$(gcloud run services describe api-${{ inputs.sponsor }}-${{ inputs.environment }} --region=${{ env.REGION }} --format='value(status.url)')
          echo "api_url=$API_URL" >> $GITHUB_OUTPUT

      - name: Build and push Portal image
        run: |
          docker build \
            --build-arg API_BASE_URL=${{ steps.api-url.outputs.api_url }} \
            --build-arg FIREBASE_API_KEY=${{ secrets.FIREBASE_API_KEY }} \
            --build-arg FIREBASE_AUTH_DOMAIN=${{ vars.PROJECT_ID }}.firebaseapp.com \
            --build-arg GCP_PROJECT_ID=${{ vars.PROJECT_ID }} \
            --build-arg FIREBASE_APP_ID=${{ secrets.FIREBASE_APP_ID }} \
            -t ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/portal:${{ github.sha }} \
            ./apps/web_portal
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/portal:${{ github.sha }}

      - name: Deploy Portal to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: portal-${{ inputs.sponsor }}-${{ inputs.environment }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ vars.PROJECT_ID }}/${{ inputs.sponsor }}-images/portal:${{ github.sha }}
          region: ${{ env.REGION }}
          project_id: ${{ vars.PROJECT_ID }}
```

### Workload Identity Federation Setup

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project=$PROJECT_ID

# Create Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location="global" \
  --workload-identity-pool=github-pool \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=$PROJECT_ID

# Grant access to service account
gcloud iam service-accounts add-iam-policy-binding cicd-deployer@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/Cure-HHT/hht_diary" \
  --project=$PROJECT_ID
```

---

## Terraform Configuration

### Cloud Run Module

```hcl
# infrastructure/terraform/modules/cloud-run/main.tf
resource "google_cloud_run_service" "api" {
  name     = "api-${var.sponsor}-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.api.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.sponsor}-images/api-server:${var.image_tag}"

        resources {
          limits = {
            memory = var.api_memory
            cpu    = var.api_cpu
          }
        }

        env {
          name  = "DATABASE_HOST"
          value = "/cloudsql/${var.cloudsql_connection_name}"
        }

        env {
          name  = "DATABASE_NAME"
          value = "clinical_diary"
        }

        env {
          name  = "DATABASE_USER"
          value = "app_user"
        }

        env {
          name = "DATABASE_PASSWORD"
          value_from {
            secret_key_ref {
              name = "db-app-password"
              key  = "latest"
            }
          }
        }

        env {
          name  = "SPONSOR_ID"
          value = var.sponsor
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      }

      container_concurrency = 80
      timeout_seconds       = 60
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"        = var.min_instances
        "autoscaling.knative.dev/maxScale"        = var.max_instances
        "run.googleapis.com/cloudsql-instances"   = var.cloudsql_connection_name
        "run.googleapis.com/vpc-access-connector" = var.vpc_connector_id
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }

      labels = var.labels
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

resource "google_cloud_run_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  service  = google_cloud_run_service.api.name
  location = google_cloud_run_service.api.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

---

## Monitoring and Logging

### View Logs

```bash
# API server logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-${SPONSOR}-${ENV}" \
  --limit=50 \
  --project=$PROJECT_ID

# Structured log query
gcloud logging read 'resource.type="cloud_run_revision" severity>=WARNING' \
  --project=$PROJECT_ID \
  --format="table(timestamp,severity,textPayload)"
```

### Create Dashboard

Cloud Run automatically creates metrics. Create custom dashboard:

```bash
# Export dashboard JSON
cat > dashboard.json << 'EOF'
{
  "displayName": "Cloud Run - ${SPONSOR}",
  "gridLayout": {
    "widgets": [
      {
        "title": "Request Count",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "resource.type=\"cloud_run_revision\" metric.type=\"run.googleapis.com/request_count\""
              }
            }
          }]
        }
      }
    ]
  }
}
EOF

gcloud monitoring dashboards create --config-from-file=dashboard.json --project=$PROJECT_ID
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check recent logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-${SPONSOR}-${ENV} AND severity>=ERROR" \
  --limit=20 \
  --project=$PROJECT_ID

# Check revision status
gcloud run revisions list --service=api-${SPONSOR}-${ENV} --region=$REGION --project=$PROJECT_ID
```

### Database Connection Issues

```bash
# Verify VPC connector
gcloud compute networks vpc-access connectors describe ${SPONSOR}-vpc-connector \
  --region=$REGION \
  --project=$PROJECT_ID

# Test Cloud SQL connectivity
gcloud run services update api-${SPONSOR}-${ENV} \
  --add-cloudsql-instances=${PROJECT_ID}:${REGION}:${SPONSOR}-db-${ENV} \
  --region=$REGION \
  --project=$PROJECT_ID
```

### Cold Start Issues

```bash
# Increase minimum instances
gcloud run services update api-${SPONSOR}-${ENV} \
  --min-instances=1 \
  --region=$REGION \
  --project=$PROJECT_ID
```

---

## Security Checklist

- [ ] Service accounts created with minimal permissions
- [ ] VPC connector configured for private database access
- [ ] Secrets stored in Secret Manager (not environment variables)
- [ ] Container images scanned for vulnerabilities
- [ ] Ingress restricted appropriately
- [ ] HTTPS enforced (automatic with Cloud Run)
- [ ] Authentication middleware validates JWT tokens
- [ ] CORS configured correctly
- [ ] Security headers set in nginx (portal)

---

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Deployment](https://cloud.google.com/run/docs/deploying)
- [Cloud Run + Cloud SQL](https://cloud.google.com/sql/docs/postgres/connect-run)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- **Project Structure**: docs/gcp/project-structure.md
- **Cloud SQL Setup**: docs/gcp/cloud-sql-setup.md
- **Identity Platform**: docs/gcp/identity-platform-setup.md

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-11-25 | 1.0 | Initial Cloud Run deployment guide | Claude |
