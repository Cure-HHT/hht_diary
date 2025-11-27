# Firebase Cloud Functions Setup Guide

This document explains how the Firebase Cloud Functions work in this project and how to set up a new Firebase/GCP project with the proper permissions.

## Architecture Overview

### Authentication Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Flutter   │────▶│  /api/enroll     │────▶│  Firestore  │
│     App     │     │  (Cloud Function)│     │   (users)   │
└─────────────┘     └──────────────────┘     └─────────────┘
       │                    │
       │                    ▼
       │            ┌──────────────┐
       │            │  Returns JWT │
       │            │  + userId    │
       │            └──────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  Subsequent API calls use JWT in Authorization header   │
│  Authorization: Bearer <jwt>                            │
└─────────────────────────────────────────────────────────┘
```

### Enrollment Process

1. User enters 8-character code (MVP format: `CUREHHT#` where # is 0-9)
2. Flutter app calls `/api/enroll` with the code
3. Cloud Function:
   - Validates code format
   - Checks if code has been used (one-time use)
   - Creates user document in Firestore with:
     - `userId`: UUID
     - `authCode`: Random 64-char hex string
     - `enrollmentCode`: The CUREHHT# code
     - `createdAt`, `lastActiveAt`: Timestamps
   - Generates JWT containing `authCode` and `userId`
   - Returns JWT and userId to client
4. Flutter app stores JWT locally for subsequent API calls

### API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/health` | GET | None | Health check |
| `/api/enroll` | POST | None | Enroll with code, get JWT |
| `/api/sync` | POST | JWT | Sync records to Firestore |
| `/api/getRecords` | POST | JWT | Get all user's records |

## Why v1 Functions?

We use **Firebase Functions v1** instead of v2 because:
1. There's no Firebase Authentication, no authentication at all.  
2. **v2 functions** are backed by Cloud Run, which requires IAM authentication by default
3. **Organization policies** often restrict adding `allUsers` to Cloud Run services
4. **v1 functions** use the legacy Cloud Functions infrastructure, which is publicly accessible by default

### v1 vs v2 Syntax

**v2 (Cloud Run based - has IAM restrictions):**
```typescript
import {onRequest} from "firebase-functions/v2/https";

export const myFunc = onRequest((req, res) => { ... });
```

**v1 (Legacy - publicly accessible by default):**
```typescript
import * as functions from "firebase-functions/v1";

export const myFunc = functions
  .runWith({ timeoutSeconds: 60, memory: "256MB" })
  .region("europe-west1")
  .https.onRequest((req, res) => { ... });
```

## CORS Configuration

The `cors.ts` file configures CORS for the Firebase Hosting domain:

```typescript
import cors = require('cors');

export const corsHandlerFnc = () => cors({
    origin: ['https://YOUR-PROJECT.web.app','https://www.YOUR-PROJECT.web.app'],
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
});
```

## Firebase Hosting Rewrites

The `firebase.json` configures URL rewrites so the Flutter app can call `/api/*` URLs:

```json
{
  "hosting": {
    "rewrites": [
      { "source": "/api/enroll", "function": "enroll", "region": "europe-west1" },
      { "source": "/api/health", "function": "health", "region": "europe-west1" },
      { "source": "/api/sync", "function": "sync", "region": "europe-west1" },
      { "source": "/api/getRecords", "function": "getRecords", "region": "europe-west1" },
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

## Required GCP Permissions

### 1. Organization Policy Override

If your GCP organization restricts IAM members (common in enterprise setups), you need to create a project-level override:

```bash
# Check if org policy is blocking allUsers
gcloud org-policies describe iam.allowedPolicyMemberDomains --organization=YOUR_ORG_ID

# Create project-level override to allow all domains
cat > /tmp/policy.yaml << 'EOF'
name: projects/YOUR_PROJECT_ID/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
  - allowAll: true
EOF

gcloud org-policies set-policy /tmp/policy.yaml --project=YOUR_PROJECT_ID
```

### 2. Cloud Functions Public Access

After deploying functions, grant public access:

```bash
for fn in enroll health sync getRecords; do
  gcloud functions add-iam-policy-binding $fn \
    --region=europe-west1 \
    --member="allUsers" \
    --role="roles/cloudfunctions.invoker" \
    --project=YOUR_PROJECT_ID
done
```

### 3. Firestore Access for Functions

The Cloud Functions service account needs Firestore access:

```bash
# Get project number
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

# Grant Firestore access to the compute service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/datastore.owner"
```

## Setup Script

See `scripts/setup-firebase-permissions.sh` for an automated setup script.

## Troubleshooting

### 403 Forbidden on Function Calls

**Symptom:** Functions return HTML with "403 Forbidden"

**Causes:**
1. IAM policy not set to allow `allUsers`
2. Organization policy blocking `allUsers`

**Fix:** Run the setup script or manually set IAM policies.

### Internal Server Error on Enroll

**Symptom:** Enroll returns "Internal Server Error"

**Check logs:**
```bash
gcloud functions logs read enroll --region=europe-west1 --project=YOUR_PROJECT_ID --limit=20
```

**Common causes:**
1. Firestore permissions not granted to service account
2. Firestore not enabled in the project

### Hosting Rewrites Not Working

**Symptom:** `/api/*` URLs return the Flutter app HTML instead of function response

**Fix:** Redeploy hosting after deploying functions:
```bash
firebase deploy --only hosting
```

## Security Considerations

1. **JWT Secret**: The `JWT_SECRET` should be stored in Secret Manager in production, not hardcoded
2. **One-time codes**: Each CUREHHT# code can only be used once
3. **Auth codes**: The `authCode` in JWT is verified against Firestore on each protected API call
4. **CORS**: Only the Firebase Hosting domain is allowed

## Files Reference

| File | Purpose |
|------|---------|
| `functions/src/index.ts` | Cloud Functions implementation |
| `functions/src/cors.ts` | CORS configuration |
| `firebase.json` | Firebase config including hosting rewrites |
| `lib/config/app_config.dart` | Flutter app API URLs |
| `lib/services/enrollment_service.dart` | Flutter enrollment logic |
| `lib/services/nosebleed_service.dart` | Flutter sync/fetch logic |
