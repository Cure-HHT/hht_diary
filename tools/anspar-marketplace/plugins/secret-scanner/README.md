# Secret Scanner Plugin

**Version:** 1.0.0
**Status:** Active
**Type:** Security / Git Workflow

## Overview

Automatic secret detection plugin that prevents accidental commits of sensitive information (API keys, tokens, passwords, credentials) using gitleaks.

## Purpose

This plugin integrates gitleaks secret scanning into the git commit workflow to catch and block secrets before they enter the repository history.

## Features

- ✅ Automatic scanning of staged files on commit
- ✅ Blocks commits containing detected secrets
- ✅ Clear error messages with remediation steps
- ✅ Configurable via `.gitleaks.toml`
- ✅ Graceful degradation if gitleaks not installed

## How It Works

The plugin provides a git pre-commit hook that:

1. Runs when you execute `git commit`
2. Scans only staged files using `gitleaks protect --staged`
3. Blocks the commit if secrets are detected
4. Provides clear guidance on how to fix the issue

## Installation

### Prerequisites

- Gitleaks v8.18.0+ installed (automatic in dev containers using base.Dockerfile)
- Git hooks enabled: `git config core.hooksPath .githooks`

### Setup

1. **Gitleaks is pre-installed** in dev containers via `tools/dev-env/docker/base.Dockerfile`
2. **Git hooks are auto-enabled** in dev containers via `postCreateCommand`
3. **Plugin hook is auto-discovered** by `.githooks/pre-commit` orchestrator

No manual installation required when using dev containers!

### Manual Installation (outside dev containers)

```bash
# Install gitleaks
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz -C /usr/local/bin
rm gitleaks_8.18.0_linux_x64.tar.gz

# Windows
# Download from https://github.com/gitleaks/gitleaks/releases

# Verify installation
gitleaks version

# Enable git hooks
git config core.hooksPath .githooks
```

## Usage

### Normal Workflow

```bash
# Make changes (example shows WRONG approach - hardcoding a secret)
echo "API_KEY=EXAMPLE_SECRET_VALUE" > config.sh

# Stage files
git add config.sh

# Attempt commit - will be BLOCKED
git commit -m "Add config"

# Output:
🔍 Scanning staged files for secrets...
❌ SECRETS DETECTED IN STAGED FILES!
```

### Fixing Secret Detections

**Option 1: Remove the secret**
```bash
# Use environment variables instead
echo "API_KEY=\${API_KEY}" > config.sh
git add config.sh
git commit -m "Add config (using env var)"
```

**Option 2: Use Doppler**
```bash
# Store in Doppler instead of code
doppler secrets set API_KEY YOUR_ACTUAL_SECRET_HERE
rm config.sh
git add config.sh
git commit -m "Remove hardcoded secret"
```

**Option 3: Allowlist false positives**

If gitleaks detects something that's not actually a secret (e.g., example code, test fixtures):

```toml
# Add to .gitleaks.toml
[[rules]]
description = "Allow example API keys in documentation"
id = "allow-docs-examples"
path = "docs/.*\\.md"
```

### Bypass (Emergency Only)

```bash
# Only use in emergencies (e.g., incident response)
git commit --no-verify -m "Emergency fix"
```

## Configuration

The plugin uses `.gitleaks.toml` in the repository root for configuration.

### Example Configuration

See `.gitleaks.toml` for the complete configuration including:
- Custom secret patterns
- File path exclusions
- Allowlisted false positives
- Entropy thresholds

## Hook Execution Order

1. `.githooks/pre-commit` (orchestrator)
2. `tools/anspar-marketplace/plugins/workflow/hooks/pre-commit` (ticket validation)
3. **`tools/anspar-marketplace/plugins/secret-scanner/hooks/pre-commit`** ← This plugin
4. Other plugin pre-commit hooks (alphabetical)
5. `.githooks/commit-msg` (requirement validation)

## Troubleshooting

### "gitleaks: command not found"

**Problem:** Gitleaks not installed

**Solution:**
- In dev container: Rebuild container with updated base image
- Local environment: Install gitleaks manually (see Installation)

### False Positives

**Problem:** Gitleaks flags non-secret content (test data, examples)

**Solution:** Add to `.gitleaks.toml` allowlist:

```toml
[allowlist]
description = "Allowlist test fixtures"
paths = [
  "test/fixtures/.*",
  "docs/examples/.*"
]
```

### Performance Issues

**Problem:** Slow commit times on large changesets

**Solution:**
- Gitleaks only scans staged files (`--staged`)
- Commits with <100 files should be instant
- For very large commits (1000+ files), expect 1-5 seconds

### Hook Not Running

**Problem:** Commits succeed without scanning

**Solution:**
1. Check git hooks enabled: `git config core.hooksPath`
2. Should output: `.githooks`
3. If not: `git config core.hooksPath .githooks`
4. Verify hook executable: `ls -l tools/anspar-marketplace/plugins/secret-scanner/hooks/pre-commit`

## Security Model

### What It Catches

✅ API keys (AWS, Stripe, Linear, GitHub, etc.)
✅ Database credentials (PostgreSQL, MySQL, MongoDB)
✅ Private keys (SSH, TLS, JWT signing keys)
✅ OAuth tokens and client secrets
✅ Generic secrets (high-entropy strings)
✅ Passwords in configuration files

### What It Doesn't Catch

❌ Secrets in commit messages (use BFG or git-filter-repo to fix)
❌ Secrets already in history (use `gitleaks detect` to scan)
❌ Obfuscated secrets (base64, hex-encoded)
❌ Secrets in binary files

### Limitations

- Pre-commit hooks can be bypassed with `--no-verify`
- Does not scan existing repository history
- Cannot prevent secrets in commit messages
- Relies on gitleaks detection rules (may have false negatives)

## Related Security Measures

This plugin is part of a defense-in-depth strategy:

1. **Local pre-commit** (this plugin) - First line of defense
2. **PR validation** - `.github/workflows/pr-validation.yml` security-check job
3. **GitHub secret scanning** - Automatic detection in pushes
4. **Doppler** - Proper secret storage and injection

## Root Cause

This plugin was created in response to commit `ae20725b0f4e19ac82b742b45805ee722c23172b` where a Linear API key was accidentally committed because:
- Git hooks were not automatically enabled
- No secret scanning at commit time
- Direct merge to main bypassed PR validation

## Testing

### Test the Hook

```bash
# Create test file with fake secret
echo "aws_access_key_id=AKIAIOSFODNN7EXAMPLE" > test-secret.txt
git add test-secret.txt

# Should be blocked
git commit -m "Test secret detection"

# Clean up
git restore --staged test-secret.txt
rm test-secret.txt
```

### Test Configuration

```bash
# Validate .gitleaks.toml syntax
gitleaks detect --config .gitleaks.toml --no-git --verbose

# Scan entire repository
gitleaks detect --verbose
```

## Maintenance

### Updating Gitleaks

Gitleaks version is pinned in `tools/dev-env/docker/base.Dockerfile`:

```dockerfile
ENV GITLEAKS_VERSION=v8.18.0
```

To update:
1. Check releases: https://github.com/gitleaks/gitleaks/releases
2. Update `GITLEAKS_VERSION` in base.Dockerfile
3. Rebuild dev containers
4. Test with known secrets
5. Update this README with new version

### Updating Detection Rules

Update `.gitleaks.toml` to:
- Add new secret patterns
- Adjust entropy thresholds
- Modify allowlist rules

## Requirements

Implements security improvements related to:
- Investigation of exposed API key (commit ae20725)
- Prevention of future secret exposures

## License

Same as parent project (see root LICENSE file)

## Support

- Issues: GitHub Issues
- Documentation: This README
- Configuration: `.gitleaks.toml`

## Changelog

### 1.0.0 (2024-11-08)
- Initial release
- Gitleaks v8.18.0 integration
- Pre-commit hook implementation
- Basic .gitleaks.toml configuration
