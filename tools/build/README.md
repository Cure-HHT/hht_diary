# Build Tools

Sponsor integration and build automation tools.

## IMPLEMENTS REQUIREMENTS
- REQ-d00070: Sponsor integration automation
- REQ-d00069: Doppler manifest system

## Scripts

### integrate-sponsors.sh

Integrates sponsor modules into the core application during build. Supports both mono-repo (local) and multi-repo modes.

**Usage:**
```bash
# From Doppler (CI/CD)
doppler run -- ./tools/build/integrate-sponsors.sh

# From file (testing)
./tools/build/integrate-sponsors.sh --manifest /tmp/test-manifest.yml
```

**Environment Variables:**
- `SPONSOR_MANIFEST` - YAML manifest from Doppler (required if `--manifest` not provided)
- `SPONSOR_REPO_TOKEN` - GitHub PAT for cloning private repos (required for multi-repo mode)

**Output:**
- Clones/verifies sponsor repositories
- Validates sponsor directory structure
- Creates `build/sponsor-build-manifest.json` with full traceability

**Mono-Repo Mode:**
```yaml
sponsors:
  - name: callisto
    repo: local  # Points to sponsor/callisto/ directory
    tag: main    # Not used
```

**Multi-Repo Mode:**
```yaml
sponsors:
  - name: callisto
    repo: cure-hht/sponsor-callisto  # Clones from GitHub
    tag: v1.2.3                       # Git tag to clone
```

**Build Manifest Example:**
```json
{
  "sponsors": [
    {
      "name": "callisto",
      "code": "CAL",
      "repo": "local",
      "tag": "main",
      "git_sha": "a1b2c3d4...",
      "mobile_module": true,
      "portal": true,
      "region": "eu-west-1"
    }
  ],
  "timestamp": "2025-01-10T12:34:56Z",
  "git_sha": "e5f6g7h8..."
}
```

### verify-sponsor-structure.sh

Verifies sponsor directory structure matches template requirements.

**Usage:**
```bash
./tools/build/verify-sponsor-structure.sh <sponsor-name>
```

**Example:**
```bash
./tools/build/verify-sponsor-structure.sh callisto
```

**Checks:**
- ✅ Sponsor directory exists
- ✅ `sponsor-config.yml` exists and valid
- ✅ Config name matches directory name
- ✅ Namespace matches sponsor code
- ✅ Code is 3 uppercase letters (e.g., `CAL`)
- ✅ Mobile module structure (if enabled)
- ✅ Portal structure (if enabled)
- ✅ Database schema exists (if portal enabled)
- ✅ Schema marked as standalone
- ✅ Infrastructure configuration
- ✅ AWS region and S3 bucket naming

**Exit Codes:**
- `0` - Verification passed
- `1` - Verification failed (errors found)

## Dependencies

### Required
- `bash` 4.0+
- `git` 2.0+
- `jq` 1.6+ (JSON processing)

### Optional
- `yq` 4.0+ (YAML processing) - Required for full config validation
- `doppler` CLI (secrets management)

### Installation

**macOS:**
```bash
brew install jq yq doppler
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install jq
sudo snap install yq
curl -Ls --tlsv1.2 --proto "=https" https://cli.doppler.com/install.sh | sudo sh
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Integrated App

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
          sudo snap install yq

      - name: Install Doppler CLI
        uses: dopplerhq/cli-action@v3

      - name: Integrate Sponsors
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN_CORE }}
          SPONSOR_REPO_TOKEN: ${{ secrets.SPONSOR_REPO_TOKEN }}
        run: |
          doppler run -- ./tools/build/integrate-sponsors.sh

      - name: Verify Callisto
        run: ./tools/build/verify-sponsor-structure.sh callisto

      - name: Build Mobile App
        run: flutter build apk --release

      - name: Upload Build Manifest
        uses: actions/upload-artifact@v4
        with:
          name: sponsor-build-manifest
          path: build/sponsor-build-manifest.json
```

## Testing Locally

### 1. Create Test Manifest

```bash
cat > /tmp/test-manifest.yml <<'EOF'
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: local
    tag: main
    mobile_module: true
    portal: true
    region: eu-west-1
EOF
```

### 2. Run Integration

```bash
./tools/build/integrate-sponsors.sh --manifest /tmp/test-manifest.yml
```

### 3. Verify Structure

```bash
./tools/build/verify-sponsor-structure.sh callisto
```

### 4. Check Build Manifest

```bash
cat build/sponsor-build-manifest.json | jq '.'
```

## Troubleshooting

### "yq: command not found"

Install yq:
```bash
brew install yq  # macOS
sudo snap install yq  # Linux
```

### "SPONSOR_MANIFEST not set"

Provide manifest via file or environment variable:
```bash
# Via file
./tools/build/integrate-sponsors.sh --manifest manifest.yml

# Via environment
export SPONSOR_MANIFEST="$(cat manifest.yml)"
./tools/build/integrate-sponsors.sh
```

### "Failed to clone sponsor repo"

Ensure `SPONSOR_REPO_TOKEN` is set with appropriate permissions:
```bash
export SPONSOR_REPO_TOKEN="ghp_xxxxxxxxxxxxx"
./tools/build/integrate-sponsors.sh
```

### "Namespace mismatch"

Verify `sponsor-config.yml` has matching code and namespace:
```yaml
sponsor:
  code: "CAL"

requirements:
  namespace: "CAL"  # Must match code
```

## Future Enhancements

- [ ] Parallel sponsor clone (multi-repo mode)
- [ ] Incremental integration (skip unchanged sponsors)
- [ ] Sponsor dependency resolution
- [ ] Build cache optimization
- [ ] Automated sponsor updates (Dependabot-style)

## See Also

- Sponsor Manifest Schema: `.github/config/sponsor-manifest-schema.yml`
- Doppler Setup: `docs/doppler-setup.md`
- Sponsor Template: `sponsor/template/README.md`
- Phase 8 Implementation: `cicd-phase8-implementation-plan.md`
