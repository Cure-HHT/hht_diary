# Phase 9: Refactoring & Optimization

## Overview
This phase focuses on code quality improvements, removing duplication, and optimizing workflow performance.

## Scope
**16 issues** related to code duplication, inefficient patterns, and workflow optimization opportunities.

## Priority: LOW-MEDIUM
These issues:
- Increase maintenance burden
- Slow down CI/CD pipelines
- Create consistency problems
- Make updates error-prone

## Issues to Fix

### Code Duplication (8 issues)
1. **Issue #73** - `qa-automation.yml:145-189` - Duplicate test setup (4 times)
2. **Issue #74** - `build-publish-images.yml:234-278` - Repeated docker build
3. **Issue #75** - `deploy-*.yml` - Same deployment logic in 3 files
4. **Issue #76** - `archive-*.yml` - Duplicate S3 upload logic
5. **Issue #77** - `pr-validation.yml:67-89,134-156` - Repeated validation
6. **Issue #78** - `database-migration.yml:45-67,89-111` - Duplicate DB checks
7. **Issue #79** - `verify-archive-integrity.yml:23-45,78-100` - Same verification
8. **Issue #80** - `codespaces-prebuild.yml` - 3 nearly identical jobs

### Inefficient Patterns (5 issues)
9. **Issue #81** - `build-publish-images.yml:456` - Sequential builds (could parallel)
10. **Issue #82** - `qa-automation.yml:234` - Tests run serially (slow)
11. **Issue #83** - `deploy-production.yml:123` - Unnecessary sleep delays
12. **Issue #84** - `archive-audit-trail.yml:67` - Large file operations in memory
13. **Issue #85** - `pr-validation.yml:178` - Fetch full history unnecessarily

### Optimization Opportunities (3 issues)
14. **Issue #86** - Missing caching for dependencies
15. **Issue #87** - No artifact reuse between jobs
16. **Issue #88** - Workflows rebuild unchanged components

## Implementation Steps

### Step 1: Extract Reusable Workflows
```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      sponsor:
        required: true
        type: string
      version:
        required: false
        type: string
        default: ${{ github.sha }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.version }}

      - name: Setup environment
        uses: ./.github/actions/setup-deploy-env
        with:
          environment: ${{ inputs.environment }}
          sponsor: ${{ inputs.sponsor }}

      - name: Deploy application
        uses: ./.github/actions/deploy-app
        with:
          project_id: ${{ vars.SUPABASE_PROJECT_ID }}
          environment: ${{ inputs.environment }}

      - name: Verify deployment
        uses: ./.github/actions/verify-deployment
        with:
          url: ${{ vars.DEPLOYMENT_URL }}
          health_checks: true

      - name: Archive deployment
        uses: ./.github/actions/archive-to-s3
        with:
          artifact: deployment-log
          bucket: ${{ vars.S3_LOGS_BUCKET }}
          retention: ${{ vars.RETENTION_DAYS }}

# Use in specific deployment workflows
# deploy-production.yml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      sponsor: ${{ github.event.inputs.sponsor }}
    secrets: inherit
```

### Step 2: Create Composite Actions
```yaml
# .github/actions/setup-deploy-env/action.yml
name: Setup Deployment Environment
description: Configure environment for deployment

inputs:
  environment:
    required: true
    description: Target environment
  sponsor:
    required: true
    description: Sponsor to deploy

runs:
  using: composite
  steps:
    - name: Install tools
      shell: bash
      run: |
        # Install once, cache for reuse
        if ! command -v supabase &> /dev/null; then
          wget -qO- https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar xzf -
          sudo mv supabase /usr/local/bin/
        fi

        if ! command -v aws &> /dev/null; then
          curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -q awscliv2.zip
          sudo ./aws/install
        fi

    - name: Configure AWS
      shell: bash
      run: |
        aws configure set region ${{ env.AWS_REGION }}
        aws configure set output json

    - name: Load configuration
      shell: bash
      run: |
        CONFIG_FILE=".github/config/sponsors/${{ inputs.sponsor }}.yml"
        if [ -f "$CONFIG_FILE" ]; then
          echo "Loading sponsor configuration..."
          # Export config as environment variables
          yq eval '.sponsor | to_entries | .[] | "SPONSOR_" + (.key | upcase) + "=" + .value' "$CONFIG_FILE" >> $GITHUB_ENV
        fi

# .github/actions/archive-to-s3/action.yml
name: Archive to S3
description: Upload artifacts to S3 with retention

inputs:
  artifact:
    required: true
    description: Artifact to upload
  bucket:
    required: true
    description: S3 bucket name
  retention:
    required: false
    description: Retention in days
    default: "90"

runs:
  using: composite
  steps:
    - name: Package artifact
      shell: bash
      run: |
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        ARCHIVE_NAME="${{ inputs.artifact }}-$TIMESTAMP.tar.gz"
        tar -czf "$ARCHIVE_NAME" ${{ inputs.artifact }}
        echo "ARCHIVE_NAME=$ARCHIVE_NAME" >> $GITHUB_ENV

    - name: Generate checksum
      shell: bash
      run: |
        sha256sum "${{ env.ARCHIVE_NAME }}" > "${{ env.ARCHIVE_NAME }}.sha256"

    - name: Upload to S3
      shell: bash
      run: |
        # Upload with retry logic
        MAX_ATTEMPTS=3
        for i in $(seq 1 $MAX_ATTEMPTS); do
          if aws s3 cp "${{ env.ARCHIVE_NAME }}" \
            "s3://${{ inputs.bucket }}/$(date +%Y/%m/%d)/" \
            --storage-class STANDARD_IA \
            --metadata "retention_days=${{ inputs.retention }}"; then
            echo "✅ Upload successful"
            break
          fi
          echo "Attempt $i failed, retrying..."
          sleep 10
        done

    - name: Verify upload
      shell: bash
      run: |
        aws s3 ls "s3://${{ inputs.bucket }}/$(date +%Y/%m/%d)/${{ env.ARCHIVE_NAME }}"
```

### Step 3: Implement Matrix Strategies
```yaml
# qa-automation.yml - Parallel test execution
jobs:
  test:
    strategy:
      matrix:
        test_suite: [unit, integration, e2e, smoke]
        sponsor: [callisto, titan, europa]
      fail-fast: false
      max-parallel: 6

    runs-on: ubuntu-latest
    name: ${{ matrix.test_suite }} - ${{ matrix.sponsor }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup test environment
        uses: ./.github/actions/setup-test-env
        with:
          suite: ${{ matrix.test_suite }}
          sponsor: ${{ matrix.sponsor }}

      - name: Run tests
        run: |
          npm run test:${{ matrix.test_suite }} -- \
            --sponsor=${{ matrix.sponsor }} \
            --parallel \
            --output=results-${{ matrix.test_suite }}-${{ matrix.sponsor }}.xml

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: test-results-${{ matrix.test_suite }}-${{ matrix.sponsor }}
          path: results-*.xml

  # Aggregate results after all tests complete
  test-summary:
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Download all results
        uses: actions/download-artifact@v3
        with:
          pattern: test-results-*

      - name: Generate summary
        run: |
          echo "## Test Results Summary" >> $GITHUB_STEP_SUMMARY
          for result in */results-*.xml; do
            # Parse and summarize each result
            echo "- $(basename $result .xml): ✅" >> $GITHUB_STEP_SUMMARY
          done
```

### Step 4: Add Intelligent Caching
```yaml
# build-publish-images.yml - Smart caching
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Cache Docker layers
        uses: actions/cache@v3
        with:
          path: /tmp/.buildx-cache
          key: ${{ runner.os }}-buildx-${{ github.sha }}
          restore-keys: |
            ${{ runner.os }}-buildx-

      - name: Cache npm dependencies
        uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-npm-

      - name: Build with cache
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_TAG }}
          cache-from: type=local,src=/tmp/.buildx-cache
          cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

      - name: Move cache
        run: |
          rm -rf /tmp/.buildx-cache
          mv /tmp/.buildx-cache-new /tmp/.buildx-cache
```

### Step 5: Optimize Workflow Dependencies
```yaml
# Use job outputs to avoid rebuilding
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
      database: ${{ steps.filter.outputs.database }}

    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            backend:
              - 'apps/backend/**'
              - 'packages/**'
            frontend:
              - 'apps/frontend/**'
              - 'packages/**'
            database:
              - 'database/**'

  build-backend:
    needs: detect-changes
    if: needs.detect-changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    # Only builds if backend changed

  build-frontend:
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    # Only builds if frontend changed

  migrate-database:
    needs: detect-changes
    if: needs.detect-changes.outputs.database == 'true'
    runs-on: ubuntu-latest
    # Only runs if database changed
```

## Testing Requirements

1. **Reusable Workflow Tests**:
   - Test with different environments
   - Verify secrets inheritance
   - Check parameter passing

2. **Composite Action Tests**:
   - Test in isolation
   - Verify error handling
   - Check idempotency

3. **Performance Tests**:
   - Measure before/after times
   - Verify caching works
   - Check parallel execution

## CI Success Criteria

- [ ] 40% reduction in workflow code duplication
- [ ] 30% faster average CI/CD execution time
- [ ] All reusable components have tests
- [ ] Cache hit rate > 80%
- [ ] Parallel jobs utilize available runners

## Known Risks

1. **Complexity**:
   - More abstraction layers
   - Harder to debug
   - Learning curve for team

2. **Cache Invalidation**:
   - Stale caches cause issues
   - Cache size limits
   - Cross-job cache conflicts

## Success Metrics

- Workflow maintenance time reduced by 50%
- CI/CD pipeline time reduced by 35%
- Code duplication reduced from 40% to 10%
- Cache hit rate consistently > 85%
- Zero regression in functionality