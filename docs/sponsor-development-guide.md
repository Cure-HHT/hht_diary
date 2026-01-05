# Sponsor Repository Development Guide

This guide covers the development workflow for working with sponsor repositories in the multi-repo architecture.

## Overview

The platform uses a multi-repo architecture where:
- **Core repository** (`hht_diary`) contains shared platform code
- **Sponsor repositories** (`hht_diary_{sponsor}`) contain sponsor-specific code and specs

Each sponsor repository references a specific worktree in the core repository, enabling isolated development per sponsor.

## Directory Structure

Recommended local directory layout:

```
~/cure-hht/
├── hht_diary/                      # Core repo (main worktree)
├── hht_diary-worktrees/
│   ├── callisto/                   # Core worktree for Callisto work
│   ├── titan/                      # Core worktree for Titan work
│   └── sponsor-repos/              # Core worktree for multi-repo infra
│
├── callisto/                       # Sponsor repo: hht_diary_callisto
│   ├── .core-repo                  # -> ../hht_diary-worktrees/callisto
│   ├── sponsor-config.yml
│   └── spec/
│
└── titan/                          # Sponsor repo: hht_diary_titan
    ├── .core-repo                  # -> ../hht_diary-worktrees/titan
    ├── sponsor-config.yml
    └── spec/
```

## Initial Setup

### 1. Clone the Core Repository

```bash
cd ~/cure-hht
git clone https://github.com/cure-hht/hht_diary.git
```

### 2. Create Sponsor-Specific Worktrees

Create a worktree for each sponsor you'll work with:

```bash
cd hht_diary

# Create worktrees directory
mkdir -p ../hht_diary-worktrees

# Create worktree for Callisto sponsor work
git worktree add ../hht_diary-worktrees/callisto -b sponsor/callisto

# Create worktree for Titan sponsor work (if needed)
git worktree add ../hht_diary-worktrees/titan -b sponsor/titan
```

### 3. Clone Sponsor Repositories

Clone sponsor repos as siblings to the worktrees directory:

```bash
cd ~/cure-hht

# Clone Callisto sponsor repo
git clone https://github.com/cure-hht/hht_diary_callisto.git callisto

# Clone Titan sponsor repo (if needed)
git clone https://github.com/cure-hht/hht_diary_titan.git titan
```

### 4. Verify .core-repo Configuration

Each sponsor repo must have a `.core-repo` file pointing to its corresponding core worktree:

```bash
# Check Callisto's .core-repo
cat callisto/.core-repo
# Should output: ../hht_diary-worktrees/callisto

# If missing or incorrect, create/update it
echo "../hht_diary-worktrees/callisto" > callisto/.core-repo
```

## Development Workflow

### Working on Sponsor-Specific Features

1. **Navigate to the sponsor repo**:
   ```bash
   cd ~/cure-hht/callisto
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/CAL-custom-forms
   ```

3. **Make changes** to sponsor-specific code in the sponsor repo

4. **If you need to modify core code**, switch to the core worktree:
   ```bash
   cd ../hht_diary-worktrees/callisto
   # Make core changes here
   ```

### Requirement References

When committing sponsor-specific changes, use the sponsor REQ namespace:

```bash
# In sponsor repo
git commit -m "[CUR-XXX] Add custom form validation

Implements: REQ-CAL-d00001"
```

When a sponsor requirement implements a core requirement:

```bash
git commit -m "[CUR-XXX] Implement Callisto EDC sync

Implements: REQ-CAL-d00005
# REQ-CAL-d00005 implements core REQ-p00042"
```

### Validating Requirements

From the sponsor repo, validate requirements against the core:

```bash
cd ~/cure-hht/callisto

# Validate sponsor requirements (auto-detects core via .core-repo)
python3 ../hht_diary-worktrees/callisto/tools/requirements/validate_requirements.py \
  --path . \
  --core-repo ../hht_diary-worktrees/callisto
```

From the core repo, validate with sponsor mode:

```bash
cd ~/cure-hht/hht_diary-worktrees/callisto

# Validate core + specific sponsor
python3 tools/requirements/validate_requirements.py --mode sponsor --sponsor callisto

# Validate core + all sponsors
python3 tools/requirements/validate_requirements.py --mode combined
```

## Sponsor Configuration

### sponsor-config.yml

Each sponsor repo must have a `sponsor-config.yml` at the root:

```yaml
sponsor:
  name: "callisto"
  code: "CAL"
  display_name: "Callisto Clinical Trial"

requirements:
  namespace: "CAL"  # Must match code, used for REQ-CAL-xxxxx

mobile_module:
  enabled: true
  features:
    - custom_forms
    - medication_tracking

portal:
  enabled: true

infrastructure:
  gcp:
    region: "europe-west1"
    project_id: "clinical-diary-callisto"
```

### .core-repo

Simple text file containing the relative path to the core repository worktree:

```
../hht_diary-worktrees/callisto
```

## Tools Reference

### resolve-sponsors.sh

List active sponsors from the core repo:

```bash
# List all enabled sponsor names
./tools/build/resolve-sponsors.sh --names --enabled-only

# Get full JSON with details
./tools/build/resolve-sponsors.sh --enabled-only

# Filter to specific sponsor
./tools/build/resolve-sponsors.sh --sponsor callisto
```

### validate_requirements.py

Validate requirement format and traceability:

```bash
# Core only (default)
python3 tools/requirements/validate_requirements.py

# With specific sponsor
python3 tools/requirements/validate_requirements.py --mode sponsor --sponsor callisto

# All sponsors
python3 tools/requirements/validate_requirements.py --mode combined
```

### generate_traceability.py

Generate traceability matrices:

```bash
# Combined matrix (all sponsors)
python3 tools/requirements/generate_traceability.py \
  --mode combined \
  --format markdown \
  --output-dir build-reports/combined/traceability

# Sponsor-specific matrix
python3 tools/requirements/generate_traceability.py \
  --mode sponsor \
  --sponsor callisto \
  --format html \
  --output-dir build-reports/callisto/traceability
```

### verify-sponsor-structure.sh

Validate sponsor directory structure:

```bash
./tools/build/verify-sponsor-structure.sh callisto
```

## Common Tasks

### Adding a New Sponsor Requirement

1. Create the requirement in `spec/` with namespaced ID:
   ```markdown
   ### REQ-CAL-d00001: Custom Form Validation

   **Status**: Draft | **Hash**: TBD

   **Implements**: REQ-p00042

   [Requirement body...]
   ```

2. Calculate the hash:
   ```bash
   python3 ../hht_diary-worktrees/callisto/tools/requirements/requirement_hash.py \
     --file spec/dev-custom-forms.md \
     --req CAL-d00001
   ```

3. Update the hash in the requirement

4. Validate:
   ```bash
   python3 ../hht_diary-worktrees/callisto/tools/requirements/validate_requirements.py \
     --path . --core-repo ../hht_diary-worktrees/callisto
   ```

### Syncing Core Changes to Sponsor Worktree

When the core repo is updated, sync your sponsor worktree:

```bash
cd ~/cure-hht/hht_diary-worktrees/callisto
git fetch origin
git rebase origin/main
```

### Running CI Validation Locally

Simulate what CI does for sponsor validation:

```bash
cd ~/cure-hht/hht_diary-worktrees/callisto

# Validate structure
./tools/build/verify-sponsor-structure.sh callisto

# Validate requirements
python3 tools/requirements/validate_requirements.py --mode sponsor --sponsor callisto

# Generate traceability
python3 tools/requirements/generate_traceability.py --mode sponsor --sponsor callisto
```

## Troubleshooting

### "Core repo spec directory not found"

The `.core-repo` path is incorrect or the worktree doesn't exist:

```bash
# Check the path
cat .core-repo

# Verify the worktree exists
ls -la ../hht_diary-worktrees/callisto/spec/

# Fix if needed
echo "../hht_diary-worktrees/callisto" > .core-repo
```

### "Namespace mismatch"

The `requirements.namespace` in `sponsor-config.yml` doesn't match the sponsor code:

```yaml
# Correct
sponsor:
  code: "CAL"
requirements:
  namespace: "CAL"  # Must match
```

### "REQ reference not found"

When a sponsor REQ implements a core REQ that doesn't exist:

1. Check the core REQ ID is correct
2. Ensure your core worktree is up to date:
   ```bash
   cd ../hht_diary-worktrees/callisto
   git pull origin main
   ```

## Related Documentation

- [Multi-Sponsor Architecture](../spec/dev-architecture-multi-sponsor.md)
- [Sponsor Repository Ops](../spec/ops-sponsor-repos.md)
- [Sponsor Repository Dev](../spec/dev-sponsor-repos.md)
- [Requirements Format](../spec/dev-requirements-format.md)
