# Documentation Consolidation Execution Plan

**Date**: 2025-11-11
**Based On**: documentation-audit-comprehensive.md
**Ticket**: CUR-350

---

## Overview

This plan consolidates scattered documentation across the repository into a well-structured docs/ directory following the established hierarchical naming convention.

**Key Principles**:
1. **Keep tool-specific docs with tools** (tools/, database/, infrastructure/ code)
2. **Move operational/setup docs to docs/** (following prefix conventions)
3. **Create centralized guides** to eliminate redundancy
4. **Update cross-references** to maintain coherence

---

## Execution Phases

### Phase 1: High Priority Moves & Renames
**Estimated Time**: 30-45 minutes
**Risk**: Low (git mv preserves history)

#### Actions:

1. **Move infrastructure operational guide**:
   ```bash
   git mv infrastructure/ACTIVATION_GUIDE.md docs/ops-infrastructure-activation.md
   ```

2. **Move dev-env operational guides**:
   ```bash
   git mv tools/dev-env/README-MAINTENANCE.md docs/ops-dev-environment-maintenance.md
   ```

3. **Move database deployment guide**:
   ```bash
   git mv database/migrations/DEPLOYMENT_GUIDE.md docs/ops-database-deployment.md
   ```

4. **Rename for consistency**:
   ```bash
   git mv docs/backup-enablement.md docs/ops-database-backup-enablement.md
   ```

5. **Move traceability matrix**:
   ```bash
   mkdir -p docs/traceability
   git mv database/traceability_matrix.md docs/traceability/
   ```

6. **Update .gitignore if needed**:
   - Check if docs/traceability/ should be ignored (if generated)

#### Sub-Agent Task:
Use a general-purpose agent to execute these git moves and verify no broken links in moved files.

---

### Phase 2: Consolidate Database Migration Documentation
**Estimated Time**: 1-2 hours
**Risk**: Medium (must preserve all critical information)

#### Current State:
- database/migrations/README.md (migration standards)
- database/migrations/DEPLOYMENT_GUIDE.md (moved to docs/ in Phase 1)
- database/testing/migrations/README.md (detailed templates and best practices)

#### Actions:

1. **Create consolidated database/migrations/README.md**:
   - Merge best content from database/testing/migrations/README.md
   - Keep migration standards, conventions, header format
   - Add templates and best practices
   - Reference docs/ops-database-deployment.md for deployment procedures

2. **Delete redundant files**:
   ```bash
   git rm database/testing/README.md
   git rm database/testing/migrations/README.md
   ```

3. **Consider renaming/removing database/testing/ directory** if it only contained migrations

#### Sub-Agent Task:
Use a general-purpose agent to:
1. Read all three migration files
2. Create comprehensive consolidated version
3. Ensure no information is lost
4. Update cross-references

---

### Phase 3: Create New Centralized Guides
**Estimated Time**: 3-4 hours
**Risk**: Low (new files, no deletions)

#### New Files to Create:

1. **docs/development-prerequisites.md**
   - Purpose: Tool installation guide (jq, yq, Python packages, Node.js, etc.)
   - Content from: Multiple plugin READMEs
   - Sections:
     - Required tools by role (dev, qa, ops)
     - Installation instructions per OS
     - Verification procedures
     - Common troubleshooting

2. **docs/git-hooks-setup.md**
   - Purpose: Standard git hook configuration
   - Content from: Multiple plugin READMEs
   - Sections:
     - What hooks are installed
     - Manual installation process
     - Hook behavior and requirements
     - Bypassing hooks (when appropriate)
     - Troubleshooting

3. **docs/git-workflow.md**
   - Purpose: High-level workflow concepts
   - Content from: CLAUDE.md, workflow plugin docs
   - Sections:
     - Branching strategy (feature/, fix/, release/)
     - Commit message conventions
     - PR process
     - Requirement traceability in commits
     - Working with Linear tickets

4. **docs/security-secret-management.md**
   - Purpose: Secret management best practices
   - Content from: Multiple setup guides
   - Sections:
     - Doppler overview and best practices
     - Secret scanning with gitleaks
     - API token management (Linear, GitHub, etc.)
     - Rotating credentials
     - What NOT to commit
     - Emergency response for leaked secrets

5. **Enhance docs/cicd-setup-guide.md** OR create **docs/ops-cicd-integration.md**:
   - Add comprehensive CI/CD integration examples
   - GitHub Actions workflow patterns
   - Environment-specific configurations
   - Integration with tools (requirements validation, traceability, etc.)

#### Sub-Agent Tasks:
Use multiple general-purpose agents in parallel to create these files by:
1. Extracting relevant content from existing docs
2. Organizing into coherent structure
3. Adding examples and cross-references
4. Following docs/README.md style guide

---

### Phase 4: Update Plugin READMEs with Cross-References
**Estimated Time**: 2-3 hours
**Risk**: Low (adding references, not removing content)

#### Files to Update:

**In tools/requirements/**:
- tools/requirements/README.md
  - Add reference to spec/README.md for requirement format
  - Add reference to docs/ops-cicd-integration.md for CI/CD examples
  - Add reference to docs/git-hooks-setup.md

**In tools/build/**:
- tools/build/README.md
  - Add reference to docs/ops-cicd-integration.md for CI/CD integration

**In tools/anspar-cc-plugins/plugins/**:
- simple-requirements/README.md
  - Reference spec/README.md for requirement format
  - Reference docs/git-hooks-setup.md for hooks
  - Reference docs/development-prerequisites.md for tool installation

- spec-compliance/README.md
  - Reference spec/README.md for audience scope rules
  - Reference docs/git-hooks-setup.md for hooks

- traceability-matrix/README.md
  - Reference docs/git-hooks-setup.md for hooks
  - Reference docs/ops-cicd-integration.md for CI/CD

- workflow/README.md
  - Reference docs/git-workflow.md for high-level concepts
  - Reference docs/setup-dev-environment.md for dev container info
  - Reference docs/security-secret-management.md for secrets

- requirement-traceability/README.md
  - Reference tools/anspar-cc-plugins/plugins/linear-api/README.md for Linear config
  - Reference docs/git-workflow.md for workflow concepts

- compliance-verification/README.md
  - Reference tools/anspar-cc-plugins/plugins/linear-api/README.md for Linear config

- linear-api/README.md
  - Reference docs/security-secret-management.md for token management

#### Template for References:

```markdown
## Prerequisites

See the following guides for setup requirements:
- [Development Prerequisites](../../docs/development-prerequisites.md) - Required tools and installation
- [Git Hooks Setup](../../docs/git-hooks-setup.md) - Configuring project hooks
- [Secret Management](../../docs/security-secret-management.md) - API tokens and credentials

## Additional Resources

- [Git Workflow](../../docs/git-workflow.md) - Branching and commit conventions
- [CI/CD Integration](../../docs/ops-cicd-integration.md) - GitHub Actions examples
```

#### Sub-Agent Task:
Use a general-purpose agent to systematically update each plugin README with appropriate cross-references.

---

### Phase 5: Consolidate tools/dev-env/ Content
**Estimated Time**: 1-2 hours
**Risk**: Medium (merging content)

#### Actions:

1. **Identify unique content in tools/dev-env/README.md**:
   - Compare with docs/setup-dev-environment.md
   - Extract Docker-specific setup details
   - Extract role-based environment information

2. **Merge into docs/setup-dev-environment.md**:
   - Add Docker Compose details if missing
   - Add role-based environment sections
   - Ensure no duplicate information

3. **Replace tools/dev-env/README.md with redirect**:
   ```markdown
   # Development Environment Docker Configuration

   **See**: [Setup: Development Environment](../../docs/setup-dev-environment.md) for complete setup instructions and usage guide.

   ## This Directory

   This directory contains the Docker Compose configuration and Dockerfiles for the role-based development containers:

   - `docker-compose.yml` - Service definitions
   - `Dockerfile.base` - Base image with common tools
   - `Dockerfile.dev` - Development environment
   - `Dockerfile.qa` - QA/testing environment
   - `Dockerfile.ops` - Operations environment
   - `Dockerfile.mgmt` - Management (read-only) environment

   ## Architecture

   See [Development Environment Architecture](../../docs/setup-dev-environment-architecture.md) for detailed architecture documentation.

   ## Maintenance

   See [Dev Environment Maintenance](../../docs/ops-dev-environment-maintenance.md) for maintenance procedures.
   ```

4. **Delete tools/dev-env/TODO.md**:
   ```bash
   git rm tools/dev-env/TODO.md
   ```

#### Sub-Agent Task:
Use a general-purpose agent to merge content and create the redirect file.

---

### Phase 6: Update References in Core Files
**Estimated Time**: 1 hour
**Risk**: Low (updating links)

#### Files to Check and Update:

1. **CLAUDE.md**:
   - Check for references to moved files
   - Update paths

2. **README.md** (root):
   - Check for references to moved files
   - Update documentation structure section if needed

3. **spec/README.md**:
   - Check for references to moved docs

4. **spec/* files**:
   - Search for references to moved documentation
   - Update paths

5. **docs/README.md**:
   - Update if new file types were added
   - Update subdirectory descriptions

6. **All docs/ root files**:
   - Check for cross-references to moved files

#### Sub-Agent Task:
Use a general-purpose agent to:
1. Find all markdown files with cross-references
2. Identify broken links to moved files
3. Update paths
4. Report any ambiguous references

---

### Phase 7: Validation
**Estimated Time**: 30-45 minutes
**Risk**: Low (testing only)

#### Actions:

1. **Test Documentation Links**:
   ```bash
   # Find all markdown files with links
   find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" \
     -exec grep -l "\[.*\](.*\.md)" {} \;
   ```

2. **Validate Moved Files**:
   - Ensure all git mv operations preserved history
   - Check that no content was lost

3. **Test Plugin Functionality**:
   - Run workflow plugin
   - Run requirements plugin
   - Ensure hooks still work

4. **Build Documentation** (if applicable):
   - Test any documentation generation scripts

5. **Check for Broken Links**:
   - Use a markdown link checker if available
   - Manual verification of key cross-references

#### Sub-Agent Task:
Use a general-purpose agent to run validation checks and report issues.

---

## Sub-Agent Orchestration Plan

### Parallel Execution (where possible):

**Batch 1** (Phase 1 + Phase 2 start):
- Agent 1: Execute git mv operations (Phase 1)
- Agent 2: Start analyzing migration documentation (Phase 2)

**Batch 2** (Phase 3):
- Agent 1: Create development-prerequisites.md
- Agent 2: Create git-hooks-setup.md
- Agent 3: Create git-workflow.md
- Agent 4: Create security-secret-management.md
- Agent 5: Enhance cicd-setup-guide.md

**Batch 3** (Phase 4):
- Agent 1: Update tools/requirements/ READMEs
- Agent 2: Update simple-requirements, spec-compliance plugin READMEs
- Agent 3: Update traceability-matrix, workflow plugin READMEs
- Agent 4: Update requirement-traceability, compliance-verification plugin READMEs
- Agent 5: Update linear-api plugin README

**Batch 4** (Phase 5 + Phase 6):
- Agent 1: Consolidate tools/dev-env/ content (Phase 5)
- Agent 2: Update core file references (Phase 6)

**Batch 5** (Phase 7):
- Agent 1: Run all validation checks

### Sequential Dependencies:
- Phase 2 depends on Phase 1 (files moved)
- Phase 4 depends on Phase 3 (new files created to reference)
- Phase 7 depends on all previous phases (final validation)

---

## Success Criteria

### Documentation Structure:
✅ All operational guides in docs/
✅ All tool-specific docs remain with tools
✅ No duplicate migration guides
✅ Consistent naming conventions followed
✅ New centralized guides created

### Functionality:
✅ All plugins work correctly
✅ Git hooks function properly
✅ CI/CD pipelines unaffected
✅ No broken documentation links

### Quality:
✅ No information lost during consolidation
✅ Cross-references updated and working
✅ Style guide followed for new documents
✅ Requirement traceability maintained

---

## Rollback Plan

If issues are encountered:

1. **Phase 1-7**: Git history preserves all moves
   ```bash
   git log --follow <file>  # See history of moved file
   git revert <commit>      # Undo specific moves
   ```

2. **Consolidated Files**: Keep backups in docs/WIP/ during consolidation

3. **New Files**: Can be deleted if causing issues

4. **Updated References**: Git history shows all changes

---

## Post-Consolidation Maintenance

### Update Documentation:
- Add note in CLAUDE.md about documentation structure
- Update any onboarding materials
- Notify team of changes

### Monitor:
- Watch for broken links in new PRs
- Ensure new documentation follows structure
- Keep docs/README.md updated

### Continuous Improvement:
- Review documentation structure quarterly
- Consolidate further if new redundancies emerge
- Keep WIP/ directory clean

---

## Estimated Total Time

- Phase 1: 30-45 minutes
- Phase 2: 1-2 hours
- Phase 3: 3-4 hours
- Phase 4: 2-3 hours
- Phase 5: 1-2 hours
- Phase 6: 1 hour
- Phase 7: 30-45 minutes

**Total**: 9-13 hours (with sub-agents, can be reduced with parallelization)

**With Maximum Parallelization**: 4-6 hours

---

## Next Step

Execute the plan starting with Phase 1.

---

**End of Execution Plan**
