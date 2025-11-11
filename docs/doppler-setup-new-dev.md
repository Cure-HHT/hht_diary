# Doppler Setup for New Developers

**Audience**: Software Developers
**Frequency**: Once per developer joining the project
**Prerequisites**: Access to the project's Doppler organization

## IMPLEMENTS REQUIREMENTS
- REQ-d00069: Doppler manifest system
- REQ-o00015: Secrets management

## Overview

This guide helps you set up Doppler on your local development machine to access the project's secrets without storing them in files. After setup, you'll be able to run commands like:

```bash
doppler run -- flutter run
doppler run -- npm start
```

Doppler ensures you always have the latest secrets without manual `.env` file management.

## Quick Start (5 minutes)

### 1. Install Doppler CLI

Choose your operating system:

**macOS**:
```bash
brew install gnupg
brew install dopplerhq/cli/doppler
```

**Linux (Debian/Ubuntu 22.04+)**:
```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | sudo tee /etc/apt/sources.list.d/doppler-cli.list
sudo apt-get update && sudo apt-get install doppler
```

**Universal Shell Script (any Linux/BSD/macOS)**:
```bash
(curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh
```

**Verify installation**:
```bash
doppler --version
```

### 2. Authenticate

Login to Doppler (opens browser):

```bash
doppler login
```

**Troubleshooting**: If the browser doesn't open, you can authenticate with a token:
```bash
doppler configure set token <your-personal-token>
```

Get your personal token from: https://dashboard.doppler.com/workplace/tokens

### 3. Configure Your Project

Navigate to the project directory and set up Doppler:

```bash
cd /path/to/hht-diary
doppler setup
```

You'll be prompted to select:
1. **Project**: `hht-diary-core` (or specific sponsor project if working on sponsor-specific code)
2. **Config**: `dev` (for local development)

**Example**:
```
? Select a project: hht-diary-core
? Select a config: dev
```

This creates a `.doppler.yaml` file in your project directory.

### 4. Test Your Setup

Verify you can access secrets:

```bash
doppler run -- env | grep DOPPLER
```

You should see environment variables injected by Doppler.

## Daily Usage

### Running Commands with Doppler

**Prefix any command** with `doppler run --` to inject secrets:

```bash
# Flutter development
doppler run -- flutter run

# Build APK with production secrets
doppler run --project hht-diary-core --config production -- flutter build apk

# Start web server
doppler run -- npm start

# Run tests
doppler run -- flutter test

# Run database migrations
doppler run -- npm run migrate
```

### Switching Environments

Override the default config temporarily:

```bash
# Use staging secrets
doppler run --config staging -- flutter run

# Use production secrets (careful!)
doppler run --config production -- flutter build
```

### Working on Sponsor-Specific Code

When working in `sponsor/<sponsor>/` directory:

```bash
cd sponsor/callisto
doppler setup --project hht-diary-callisto --config staging
doppler run -- flutter run
```

## Configuration Files

### .doppler.yaml (Project Config)

Created by `doppler setup`. Defines default project and config:

```yaml
setup:
  project: hht-diary-core
  config: dev
```

**Important**: This file is listed in `.gitignore` - each developer has their own.

### Per-Directory Configuration

You can have different Doppler configurations in different directories:

```
hht-diary/
  .doppler.yaml          # project: hht-diary-core, config: dev
  sponsor/callisto/
    .doppler.yaml        # project: hht-diary-callisto, config: staging
```

## Viewing Secrets

### List Available Secrets

```bash
doppler secrets list
```

### Get Specific Secret

```bash
doppler secrets get SUPABASE_PROJECT_ID --plain
```

### Download All Secrets (for debugging)

```bash
doppler secrets download --no-file --format env
```

**Never commit this output** to version control!

## Common Workflows

### Initial Project Setup

```bash
# Clone repository
git clone https://github.com/cure-hht/hht-diary.git
cd hht-diary

# Install Doppler CLI (if not already installed)
brew install dopplerhq/cli/doppler

# Login
doppler login

# Configure project
doppler setup --project hht-diary-core --config dev

# Run application
doppler run -- flutter run
```

### Switching Between Sponsors

```bash
# Work on Callisto sponsor
cd sponsor/callisto
doppler setup --project hht-diary-callisto --config staging
doppler run -- flutter run

# Return to core development
cd ../..
doppler setup --project hht-diary-core --config dev
doppler run -- flutter run
```

### Using Dev Container

If using the `.devcontainer/` setup:

1. Doppler CLI is pre-installed in the dev container
2. Authenticate inside the container: `doppler login`
3. Configure project: `doppler setup`
4. Use normally: `doppler run -- flutter run`

## Troubleshooting

### "Project not found" error

**Cause**: You don't have access to the Doppler project.

**Solution**: Ask your team lead to invite you to the Doppler organization:
1. Share your Doppler account email
2. They'll invite you via Doppler dashboard
3. Accept the invitation
4. Run `doppler setup` again

### "Config not found" error

**Cause**: Selected config doesn't exist in the project.

**Solution**: List available configs:
```bash
doppler configs list --project hht-diary-core
```

Then select an existing one:
```bash
doppler setup --project hht-diary-core --config dev
```

### Secrets not loading

**Verify authentication**:
```bash
doppler me
```

**Re-authenticate if needed**:
```bash
doppler login
```

**Check project configuration**:
```bash
cat .doppler.yaml
```

### "Too many requests" error

**Cause**: Rate limiting (rare).

**Solution**: Wait a few minutes and try again. For frequent local runs, consider caching:
```bash
doppler secrets download --no-file --format env > .env.local
# Use .env.local temporarily (NOT committed to git!)
```

### Wrong secrets loaded

**Check which config is active**:
```bash
doppler configure get
```

**Verify you're in the correct directory** - `.doppler.yaml` files are directory-specific.

## Security Best Practices

### DO:
- ✅ Use `doppler run` for all commands requiring secrets
- ✅ Use `dev` config for local development
- ✅ Keep `.doppler.yaml` in `.gitignore`
- ✅ Use personal Doppler account (not shared credentials)
- ✅ Logout when leaving the company: `doppler logout`

### DON'T:
- ❌ Commit `.env` files with real secrets
- ❌ Share your Doppler personal token
- ❌ Download production secrets unless absolutely necessary
- ❌ Run `doppler run --config production` for local development
- ❌ Commit `.doppler.yaml` to git

## Migrating from .env Files

If you previously used `.env` files:

1. **Stop using .env files** - Doppler replaces them
2. **Remove local .env files** (they're in `.gitignore`)
3. **Use `doppler run`** instead of loading `.env`

**Example migration**:

**Before**:
```bash
source .env
flutter run
```

**After**:
```bash
doppler run -- flutter run
```

## Advanced Usage

### Shell Completion

Enable command completion for your shell:

```bash
# Bash
doppler completion install --shell bash

# Zsh
doppler completion install --shell zsh

# Fish
doppler completion install --shell fish
```

### IDE Integration

**VS Code**: Set environment variables in `launch.json`:
```json
{
  "configurations": [
    {
      "name": "Flutter (with Doppler)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "env": {
        // Doppler CLI must be run first to populate env vars
      }
    }
  ]
}
```

**Better approach**: Run VS Code through Doppler:
```bash
doppler run -- code .
```

### Debugging Secret Issues

View exactly what environment variables will be injected:

```bash
doppler run -- printenv | sort
```

Compare with expected secrets:
```bash
doppler secrets list
```

## Getting Help

### Check Doppler Status
```bash
doppler me
doppler configure get
```

### Update Doppler CLI
```bash
doppler update
```

### View Documentation
- Doppler CLI Docs: https://docs.doppler.com/docs/cli
- Project Setup Guide: [doppler-setup-project.md](./doppler-setup-project.md)
- Sponsor Setup Guide: [doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)

### Contact Team
- Ask in team chat for access issues
- Check `spec/ops-security.md` for security policies
- DevOps lead can grant Doppler access

## Next Steps

After setup:
1. Read project documentation in `spec/README.md`
2. Review architecture in `spec/prd-architecture-multi-sponsor.md`
3. Check development practices in `spec/dev-core-practices.md`
4. Start coding with `doppler run -- flutter run`

## References

- Doppler CLI Documentation: https://docs.doppler.com/docs/cli
- Doppler Dashboard: https://dashboard.doppler.com/
- Project Setup: [doppler-setup-project.md](./doppler-setup-project.md)
- Security Practices: `spec/ops-security.md`
