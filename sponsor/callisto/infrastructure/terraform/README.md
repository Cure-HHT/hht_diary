# Callisto Terraform Infrastructure

Terraform configuration for Callisto sponsor AWS infrastructure.

## IMPLEMENTS REQUIREMENTS
- REQ-CAL-o00001: Callisto infrastructure
- REQ-o00016: FDA compliance archival
- REQ-o00017: Per-sponsor infrastructure isolation

## Resources Created

### S3 Buckets

**Artifacts Bucket** (`hht-diary-artifacts-callisto-eu-west-1`):
- Purpose: FDA-compliant build artifact storage
- Versioning: Enabled
- Encryption: AES256
- Lifecycle:
  - 90 days: Transition to Glacier
  - 7 years (2555 days): Transition to Deep Archive
  - 8 years (2920 days): Expiration
- Retention: 7 years (FDA 21 CFR Part 11)
- Object Lock: Optional (WORM mode for compliance)

**Backups Bucket** (`hht-diary-backups-callisto-eu-west-1`):
- Purpose: Portal database backups
- Versioning: Enabled
- Encryption: AES256
- Lifecycle:
  - 30 days: Transition to Standard-IA
  - 90 days: Expiration
- Retention: 90 days

**Logs Bucket** (`hht-diary-logs-callisto-eu-west-1`):
- Purpose: Portal application logs
- Encryption: AES256
- Lifecycle:
  - 7 days: Transition to Standard-IA
  - 30 days: Expiration
- Retention: 30 days

### IAM Resources

**CI/CD Access Policy** (`CAL-cicd-artifacts-access`):
- Actions: ListBucket, GetObject, PutObject
- Resources: Artifacts bucket (standard or locked)
- Purpose: GitHub Actions artifact upload

**CI/CD User** (Optional):
- Name: `CAL-cicd-user`
- Attached Policy: `CAL-cicd-artifacts-access`
- Recommendation: Use GitHub Actions OIDC instead

## Prerequisites

1. **Terraform** 1.5.0+
   ```bash
   brew install terraform  # macOS
   ```

2. **AWS CLI** configured
   ```bash
   aws configure
   ```

3. **AWS Credentials** with permissions:
   - `s3:CreateBucket`, `s3:PutBucketPolicy`, `s3:PutBucketVersioning`
   - `s3:PutBucketEncryption`, `s3:PutLifecycleConfiguration`
   - `iam:CreatePolicy`, `iam:CreateUser`, `iam:AttachUserPolicy`

## Usage

### Initial Setup

1. **Navigate to Terraform directory**
   ```bash
   cd sponsor/callisto/infrastructure/terraform
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review plan**
   ```bash
   terraform plan
   ```

4. **Apply configuration**
   ```bash
   terraform apply
   ```

5. **Save outputs to Doppler**
   ```bash
   # Get artifacts bucket name
   BUCKET_NAME=$(terraform output -raw artifacts_bucket_name)

   # Set in Doppler (hht-diary-callisto/production)
   doppler secrets set SPONSOR_ARTIFACTS_BUCKET="$BUCKET_NAME" \
     --project hht-diary-callisto --config production
   ```

### Enabling Object Lock (Production)

**WARNING**: Object Lock can only be enabled on bucket creation. If you need to enable it after initial setup, you must create a new bucket.

1. **Destroy existing buckets** (if already created without lock)
   ```bash
   terraform destroy -target=module.s3_buckets.aws_s3_bucket.artifacts
   ```

2. **Enable Object Lock**
   ```bash
   terraform apply -var="enable_object_lock=true"
   ```

3. **Update Doppler** with new bucket name

### Creating CI/CD User (Not Recommended)

**Recommendation**: Use GitHub Actions OIDC instead for better security.

If you must create an IAM user:

```bash
terraform apply -var="create_cicd_user=true"

# Create access keys (do this in AWS Console or via CLI)
aws iam create-access-key --user-name CAL-cicd-user

# Store in Doppler
doppler secrets set AWS_ACCESS_KEY_ID="AKIAXXXXX" \
  --project hht-diary-callisto --config production
doppler secrets set AWS_SECRET_ACCESS_KEY="xxxxxxxx" \
  --project hht-diary-callisto --config production
```

### GitHub Actions OIDC (Recommended)

1. **Create OIDC provider** (one-time, organization-wide)
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Create IAM role** for GitHub Actions
   ```bash
   # See: docs/github-actions-oidc.md
   ```

3. **Attach CI/CD policy** to role
   ```bash
   POLICY_ARN=$(terraform output -raw cicd_policy_arn)

   aws iam attach-role-policy \
     --role-name GitHubActions-Callisto \
     --policy-arn "$POLICY_ARN"
   ```

4. **Update workflow** to use OIDC
   ```yaml
   - name: Configure AWS Credentials
     uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: arn:aws:iam::123456789012:role/GitHubActions-Callisto
       aws-region: eu-west-1
   ```

## Configuration

### Variables

Create `terraform.tfvars`:

```hcl
aws_region         = "eu-west-1"
environment        = "production"
enable_object_lock = false  # Change to true for production compliance
create_cicd_user   = false  # Use OIDC instead
```

### Backend (Recommended)

Store Terraform state in S3:

1. **Create state bucket** (manually, one-time)
   ```bash
   aws s3 mb s3://hht-diary-terraform-state-callisto --region eu-west-1
   aws s3api put-bucket-versioning \
     --bucket hht-diary-terraform-state-callisto \
     --versioning-configuration Status=Enabled
   ```

2. **Create DynamoDB lock table**
   ```bash
   aws dynamodb create-table \
     --table-name hht-diary-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region eu-west-1
   ```

3. **Uncomment backend block** in `s3-buckets.tf`

4. **Initialize backend**
   ```bash
   terraform init -migrate-state
   ```

## Verification

### Check Bucket Configuration

```bash
# List buckets
aws s3 ls | grep hht-diary

# Check versioning
aws s3api get-bucket-versioning \
  --bucket hht-diary-artifacts-callisto-eu-west-1

# Check encryption
aws s3api get-bucket-encryption \
  --bucket hht-diary-artifacts-callisto-eu-west-1

# Check lifecycle
aws s3api get-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-callisto-eu-west-1
```

### Test Upload

```bash
# Create test file
echo "test" > /tmp/test.txt

# Upload
aws s3 cp /tmp/test.txt \
  s3://hht-diary-artifacts-callisto-eu-west-1/test/test.txt

# Verify
aws s3 ls s3://hht-diary-artifacts-callisto-eu-west-1/test/

# Cleanup
aws s3 rm s3://hht-diary-artifacts-callisto-eu-west-1/test/test.txt
```

## Maintenance

### Updating Infrastructure

1. Modify Terraform files
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes
4. Update Doppler secrets if bucket names change

### Monitoring Costs

```bash
# Check bucket sizes
aws s3 ls s3://hht-diary-artifacts-callisto-eu-west-1 --summarize --recursive

# Estimate costs (use AWS Cost Explorer)
# Typical costs:
# - S3 Standard: $0.023/GB/month
# - S3 Glacier: $0.004/GB/month
# - S3 Deep Archive: $0.00099/GB/month
```

### Disaster Recovery

All buckets have versioning enabled. To recover deleted objects:

```bash
# List versions
aws s3api list-object-versions \
  --bucket hht-diary-artifacts-callisto-eu-west-1 \
  --prefix builds/

# Restore specific version
aws s3api copy-object \
  --copy-source "bucket/key?versionId=xxx" \
  --bucket bucket \
  --key key
```

## Troubleshooting

### "Bucket already exists"

If bucket names conflict:
1. Choose different region
2. Modify bucket naming in locals block
3. Ensure buckets were fully deleted (check S3 console)

### "Access Denied"

Check IAM permissions:
```bash
# Test permissions
aws s3 ls s3://hht-diary-artifacts-callisto-eu-west-1
aws s3 cp /tmp/test.txt s3://hht-diary-artifacts-callisto-eu-west-1/test.txt
```

### "Cannot enable object lock on existing bucket"

Object Lock requires new bucket:
1. Destroy existing bucket
2. Apply with `enable_object_lock=true`
3. Migrate data (if needed)

## See Also

- Terraform Module: `infrastructure/terraform/modules/sponsor-s3/`
- Build Workflow: `.github/workflows/build-integrated.yml`
- Doppler Setup: `docs/doppler-setup.md`
- Phase 8 Documentation: `cicd-phase8-implementation-plan.md`
