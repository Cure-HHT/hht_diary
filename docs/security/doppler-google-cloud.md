# Doppler Integration with Google Cloud & Firebase Functions

This document describes how Doppler is used for secrets management in this project, including integration with Firebase Functions.

## Overview

Doppler provides centralized secrets management with:
- **Automatic team sharing** - Teammates get access via Doppler project membership
- **Environment separation** - dev, staging, production configs
- **No .env files** - Secrets injected at runtime, never stored in files
- **Audit logging** - Git-style activity logs with rollback support
- **CI/CD integration** - Service tokens for automated deployments

## Project Structure
TODO - per sponsor projects (for at least qa, uat & prod  )
```
Doppler Project: hht-diary
├── dev         # Local development
├── qa          # QA environment
├── uat         # User acceptance testing
├── prd         # Production environment
```

## Initial Setup

### Prerequisites

1. Install Doppler CLI: https://docs.doppler.com/docs/install-cli
2. Authenticate: `doppler login`
3. Request project access from a team admin

### One-Time Setup (Already Done for Clinical Diary)

The Doppler project and Firebase integration have been configured. New team members only need to:

```bash
# In the functions directory
cd apps/clinical_diary/functions
doppler setup
```

Select:
- Project: `hht-diary`
- Config: `dev` (for local development)

### Detailed Setup Guide

For complete Doppler setup instructions, see:
- [Doppler CLI Installation](https://docs.doppler.com/docs/install-cli)
- [Firebase Functions Integration](https://docs.doppler.com/docs/firebase-installation)

## Secrets Inventory

| Secret | Description | Environments |
| ------ | ----------- | ------------ |
| `CUREHHT_QA_API_KEY` | API key for sponsor config endpoint | dev, qa |
| `FIREBASE_PROJECT_ID` | Firebase project identifier | all |
| `JWT_SECRET` | JWT signing secret for auth | all |

## Local Development

### Running Firebase Functions Locally

The `package.json` scripts are configured to inject Doppler secrets automatically:

```bash
cd apps/clinical_diary/functions

# Start emulator with Doppler secrets
npm run serve

# Or run shell with Doppler secrets
npm run shell
```

### How It Works

Doppler injects secrets as environment variables. The `npm run serve` script uses `doppler run` to inject secrets before starting the emulator:

```bash
doppler run -- firebase emulators:start --only functions
```

### Accessing Secrets in Code

```typescript
// Access secrets via environment variables
const apiKey = process.env.CUREHHT_QA_API_KEY;
```

This works for both v1 and v2 Firebase Functions.

## CI/CD Deployment

### GitHub Actions Setup

1. Create a Doppler Service Token for production:
   - Go to Doppler Dashboard > Project > prd config
   - Generate a Service Token (read-only)
   - Add as GitHub secret: `DOPPLER_TOKEN`

2. The deploy workflow uses `doppler run --` to inject secrets:

```yaml
- name: Deploy Functions
  env:
    DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}
  run: |
    cd apps/clinical_diary/functions
    npm run deploy
```

The `npm run deploy` script uses `doppler run -- firebase deploy` which injects
environment variables from Doppler before deploying.

### Manual Deployment

```bash
cd apps/clinical_diary/functions

# Deploy with Doppler secrets injected
npm run deploy
```

## Integration Tests (Audit Evidence)

Integration tests in `functions/src/__tests__/sponsor.integration.test.ts` prove
fail-closed behavior for auditors:

### Running Integration Tests

The easiest way to run integration tests is via the test script:

```bash
cd apps/clinical_diary

# Run only TypeScript integration tests (starts emulator automatically)
./tool/test.sh -ti

# Or run all TypeScript tests (unit + integration)
./tool/test.sh -t
```

For manual testing:

```bash
cd apps/clinical_diary/functions

# Terminal 1: Start emulator WITHOUT Doppler (no secrets)
npm run serve:no-doppler

# Terminal 2: Run integration tests
npm run test:integration
```

### What These Tests Prove

1. **AUDIT: returns 500 when CUREHHT_QA_API_KEY is not configured**
   - When the emulator runs without Doppler, `CUREHHT_QA_API_KEY` is not set
   - The function returns 500 "Server configuration error"
   - This proves fail-closed behavior: misconfigured server rejects all requests

2. **returns 401 for missing apiKey**
   - Requests without an API key are rejected before checking config

3. **returns 400 for missing sponsorId**
   - Parameter validation happens before API key validation

### Test Scripts

| Script | Description |
| ------ | ----------- |
| `npm test` | Unit tests only (mocked, fast) |
| `npm run test:integration` | Integration tests (requires emulator) |
| `npm run test:all` | Both unit and integration tests |

## Doppler vs Google Secret Manager

This project uses Doppler as the primary secrets manager. Here's how it compares:

| Feature | Doppler | Google Secret Manager |
| ------- | ------- | --------------------- |
| Team sharing | Automatic via project membership | Manual IAM configuration |
| Local dev | `doppler run --` or script injection | Download service account key |
| CI/CD | Service Token as `DOPPLER_TOKEN` | Workload Identity Federation |
| Cost | Free tier (5 users, unlimited secrets) | $0.06/10k access operations |
| Multi-cloud | Yes | GCP only |
| Rollback | Built-in | Manual version selection |

### When to Use Google Secret Manager

- Native GCP services that don't support external secret injection
- Compliance requirements mandating GCP-native solutions
- Already have extensive GCP IAM infrastructure

### Hybrid Approach

You can use both:
- **Doppler** for development, CI/CD, and Firebase Functions
- **Google Secret Manager** for other GCP services (Cloud Run, GKE)

To sync Doppler secrets to Google Secret Manager:
```bash
doppler secrets download --no-file | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while read line; do
  key=$(echo $line | cut -d= -f1)
  value=$(echo $line | cut -d= -f2-)
  echo -n "$value" | gcloud secrets create $key --data-file=- 2>/dev/null || \
  echo -n "$value" | gcloud secrets versions add $key --data-file=-
done
```

## Troubleshooting

### "doppler: command not found"

Install the Doppler CLI:
```bash
# macOS
brew install dopplerhq/cli/doppler

# Linux
curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | sudo tee /etc/apt/sources.list.d/doppler-cli.list
sudo apt update && sudo apt install doppler
```

### "config not found" Error

Run `doppler setup` in the functions directory and select the correct project/config.

### Secrets Not Available in Functions

1. Verify secrets are synced: `doppler secrets`
2. For deployed functions, ensure `npm run secrets-sync` was run
3. Check `functions.config().doppler` is not undefined

### Access Denied

Contact a team admin to grant access to the Doppler project.

## Security Considerations

- **Never commit secrets** - Doppler eliminates .env files
- **Use Service Tokens** - Read-only tokens for CI/CD, not user credentials
- **Rotate secrets regularly** - Doppler supports instant rotation
- **Audit access** - Review Doppler activity logs periodically
- **Least privilege** - Give CI/CD only production read access

## References

- [Doppler Documentation](https://docs.doppler.com/)
- [Doppler Firebase Integration](https://docs.doppler.com/docs/firebase-installation)
- [Doppler CLI Reference](https://docs.doppler.com/docs/cli)
- [Google Secret Manager](https://cloud.google.com/secret-manager/docs)
