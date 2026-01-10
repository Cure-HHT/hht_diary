#!/usr/bin/env bash
# list service-accounts:
#gcloud iam service-accounts list --project=hht-diary-mvp
gcloud iam service-accounts add-iam-policy-binding \
  hht-diary-mvp@appspot.gserviceaccount.com \
  --project=hht-diary-mvp \
  --member="serviceAccount:firebase-deploy@hht-diary-mvp.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"