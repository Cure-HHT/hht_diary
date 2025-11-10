# Migration from tools/anspar-marketplace/

**Version**: 1.0.0
**Status**: Active (Phase 3 Complete - All Plugins Migrated)
**Last Updated**: 2025-11-10

## Overview

This document guides migration from `tools/anspar-marketplace/` to `tools/anspar-cc-plugins/`. The new marketplace solves a critical problem: **unreliable agent orchestration due to missing or improper agent definitions**.

## Why Migrate?

### Problems with Old Marketplace

1. **Inconsistent Agent Definitions**
   - Some plugins have agents without YAML frontmatter
   - Agent descriptions don't help orchestrator decide when to invoke
   - Tools field rarely specified
   - Main agent bypasses sub-agents, implements directly

2. **Poor Orchestration**
   - Main agent doesn't reliably discover plugin capabilities
   - `/agents` command shows agents but orchestrator doesn't use them
   - Duplicate implementations of logic that plugins already provide

3. **Flat Organization**
   - No shared utilities structure
   - Scripts scattered across plugins and tools/requirements/
   - Hard to find reusable components

4. **Manual Configuration**
   - No automatic CLAUDE.md setup for orchestration
   - Users don't know to check `/agents` first
   - No guidance on delegation patterns

### Benefits of New Marketplace

1. **Reliable Agent Orchestration**
   - All agents have proper YAML frontmatter (name, description, tools)
   - Orchestrator can discover and use agents effectively
   - Main agent delegates to specialists, doesn't reimplement

2. **Clear Structure**
   - `shared/` directory for cross-plugin utilities
   - `plugins/` for isolated plugin code
   - `docs/` for comprehensive guidance

3. **Automatic Configuration**
   - SessionStart hook configures CLAUDE.md idempotently
   - Users reminded to check `/agents` and delegate
   - Orchestration patterns documented and enforced

4. **Improved Development Workflow**
   - 2-phase plugin creation (agent definition → plugin scaffold)
   - Template system for consistent plugin structure
   - Validation tools for quality assurance

### Key Improvements

| Aspect | Old Marketplace | New Marketplace |
|--------|----------------|-----------------|
| **Agent Definitions** | Inconsistent or missing | Required YAML frontmatter |
| **Orchestration** | Bypassed | Reliable delegation |
| **Structure** | Flat | Organized with shared/ |
| **Configuration** | Manual | Automatic via hook |
| **Development** | Ad-hoc | 2-phase workflow |
| **Documentation** | Mixed | Comprehensive |

## Migration Strategy

### Approach: Clean Break (No Backward Compatibility)

**Why clean break?**
- Existing plugins need significant restructuring (YAML frontmatter)
- Different organizational philosophy (orchestration-first)
- Opportunity to fix architectural issues
- REQ tracing format preserved (MUST NOT change)

**What this means**:
- Both marketplaces run side-by-side during transition
- Plugins migrated one-by-one with proper agent definitions
- No automatic migration tools (manual review ensures quality)
- Old marketplace deprecated when all plugins migrated

### Migration Phases

#### Phase 1: Scaffold Creation ✅ COMPLETE

- [x] Create `tools/anspar-cc-plugins/` structure
- [x] Create marketplace.json with empty plugins array
- [x] Create SessionStart hook for CLAUDE.md configuration
- [x] Write comprehensive documentation
- [x] Test CLAUDE.md hook idempotency

#### Phase 2: Core Plugin Migration ✅ COMPLETE

**Migrated plugins**:
1. ✅ **plugin-wizard** - Created new with proper 2-phase workflow
2. ✅ **linear-api** - Added YAML frontmatter, updated references
3. ✅ **workflow** - Added YAML frontmatter, bumped to v3.0.0
4. ✅ **simple-requirements** - Already had frontmatter, preserved REQ format

**Migration steps completed**:
- [x] Audited existing agent definitions
- [x] Added/fixed YAML frontmatter
- [x] Verified skills match agent descriptions
- [x] Updated plugin.json homepage URLs
- [x] Registered in marketplace.json
- [x] Committed each plugin separately

#### Phase 3: Project-Specific Plugin Migration ✅ COMPLETE

**Migrated plugins**:
1. ✅ **requirement-traceability** - Added YAML frontmatter, updated linear-integration→linear-api
2. ✅ **spec-compliance** - Simplified YAML frontmatter from complex multiline
3. ✅ **compliance-verification** - Added YAML frontmatter, already referenced linear-api
4. ✅ **traceability-matrix** - Kept as separate hook-only plugin (no agent needed)

**Total plugin count**: 8 plugins migrated
- 4 core plugins (Phase 2)
- 4 project-specific plugins (Phase 3)

#### Phase 4: Deprecation and Cleanup

- Mark `tools/anspar-marketplace/` as deprecated
- Update all documentation to reference new marketplace
- Archive old marketplace (don't delete - historical reference)
- Update CI/CD to use new marketplace paths (if needed)

### Running Both Marketplaces During Transition

**Supported**: Both marketplaces can coexist

```
tools/
├── anspar-marketplace/         # Old (deprecated during migration)
│   └── plugins/               # 8 plugins
└── anspar-cc-plugins/         # New (active development)
    └── plugins/               # Migrated plugins only
```

**Claude Code behavior**:
- Discovers plugins from both marketplaces
- `/agents` shows agents from both
- No conflicts as long as plugin names differ

**Naming strategy**:
- New plugins keep same names (linear-api, workflow, etc.)
- If both exist: Old ones become `legacy-{name}` temporarily
- Or disable old marketplace during migration

## Plugin-by-Plugin Migration Guide

### General Migration Process

For each plugin:

1. **Read existing agent** (if exists):
   ```bash
   cat tools/anspar-marketplace/plugins/{plugin}/agents/*.md
   ```

2. **Identify issues**:
   - [ ] Missing YAML frontmatter?
   - [ ] Vague or missing description?
   - [ ] No tools specification?
   - [ ] Skills not documented in agent?
   - [ ] Hooks not mentioned in agent?

3. **Use 2-phase creation workflow**:
   ```
   Phase 1: Define agent with proper YAML + plugin boilerplate
   Phase 2: plugin-wizard creates scaffold
   ```

4. **Copy implementation**:
   - Scripts from old plugin → new plugin scripts/
   - Skills from old plugin → new plugin skills/
   - Hooks from old plugin → new plugin hooks/
   - Tests from old plugin → new plugin tests/

5. **Update plugin.json**:
   - Version: Start at 2.0.0 (signifies migration)
   - Agents: Point to new agent with YAML
   - Hooks: Verify references correct

6. **Test**:
   - Agent appears in `/agents`
   - Agent can be invoked by orchestrator
   - Skills work as expected
   - Hooks trigger appropriately

7. **Add to marketplace.json**:
   ```json
   {
     "plugins": [
       {
         "name": "plugin-name",
         "source": "./plugins/plugin-name",
         "description": "One-sentence description",
         "version": "2.0.0"
       }
     ]
   }
   ```

### Specific Plugin Migrations

#### plugin-wizard (Create New, Don't Migrate)

**Status**: Create from scratch using plugin-expert

**Why not migrate plugin-expert?**
- New 2-phase workflow is fundamentally different
- plugin-wizard simpler, more focused
- plugin-expert was meta-plugin for old marketplace paradigm

**Creation process**:
1. Use concept from `untracked-notes/plugin-wizard-concept.md`
2. Define agent via `/agent` with plugin boilerplate
3. plugin-expert creates initial scaffold (bootstrap)
4. Refine plugin-wizard to follow its own 2-phase pattern
5. Test by creating a test plugin

**Timeline**: After Phase 1 complete (scaffold exists)

#### linear-api (High Priority)

**Current state**:
- ✅ Has agent with YAML frontmatter (already compliant!)
- ✅ Good skill documentation
- ✅ Clear separation of concerns
- ✅ Generic, reusable

**Migration steps**:
1. Copy entire plugin directory to new marketplace
2. Update paths in scripts (if any hardcoded references)
3. Test agent invocation
4. Verify skills work
5. Done!

**Estimated effort**: 1-2 hours

#### workflow (High Priority)

**Current state**:
- ⚠️ Agent has complex prompt but may lack clear YAML description
- ✅ Well-defined hooks
- ✅ Comprehensive scripts
- ⚠️ Some cross-plugin awareness needs review

**Migration issues**:
- Ensure YAML frontmatter is clear
- Verify workflow agent knows about all hooks
- Test UserPromptSubmit hook still works
- Ensure claim/release/switch scripts work

**Estimated effort**: 3-4 hours

#### simple-requirements (Critical - REQ Format)

**Current state**:
- ✅ Has agent with YAML frontmatter
- ✅ Good skill documentation
- ✅ Clear purpose
- ⚠️ **CRITICAL**: Must preserve REQ format exactly

**Migration requirements**:
- ✅ REQ-{type}{5digits} format MUST NOT change
- ✅ Validation logic MUST be identical
- ✅ Hash calculation MUST be preserved
- ✅ INDEX.md format MUST NOT change

**Testing**:
- Run full validation suite on sample spec/ files
- Compare output with old plugin
- Verify hash calculations match
- Test INDEX.md validation

**Estimated effort**: 2-3 hours (mostly testing)

#### requirement-traceability (Diary-Specific)

**Current state**:
- ✅ Has agent with YAML frontmatter
- ✅ Depends on simple-requirements and linear-api
- ⚠️ May need orchestration updates

**Migration considerations**:
- Ensure cross-plugin coordination works with orchestrator
- Verify cache management (.requirement-cache.json)
- Test Linear integration
- Confirm REQ parsing uses simple-requirements logic

**Estimated effort**: 3-4 hours

#### spec-compliance (Diary-Specific)

**Current state**:
- ✅ Has agent with YAML frontmatter
- ✅ Clear validation rules
- ✅ Good hooks

**Migration**:
- Straightforward copy with minor updates
- Test spec/ validation logic
- Verify hooks trigger correctly

**Estimated effort**: 2-3 hours

#### compliance-verification (Diary-Specific)

**Current state**:
- ✅ Has agent
- ⚠️ May be underutilized

**Migration decision**: Consider merging into spec-compliance or simple-requirements if overlap exists

**Estimated effort**: 2 hours or defer

#### traceability-matrix (Consider Merging)

**Current state**:
- Simple plugin that regenerates matrices
- No agent (just hooks)
- Depends on tools/requirements/generate_traceability.py

**Migration decision**:
- Consider merging into simple-requirements plugin
- Or keep as standalone hook-only plugin
- Move generate_traceability.py to shared/scripts/

**Estimated effort**: 1 hour

## Breaking Changes

### Agent Frontmatter (REQUIRED)

**Old** (allowed but not enforced):
```markdown
# My Agent

You are an agent for doing X.
```

**New** (REQUIRED):
```markdown
---
name: my-agent
description: Clear, concise description of agent's purpose
tools: Read, Write, Bash  # Optional but recommended
---

# My Agent

You are an agent for doing X.
```

**Migration**: Add YAML frontmatter to all agents

### Directory Structure Changes

**Old**:
```
tools/
├── anspar-marketplace/plugins/plugin-name/
└── requirements/           # Shared Python scripts
```

**New**:
```
tools/
└── anspar-cc-plugins/
    ├── plugins/plugin-name/
    └── shared/
        ├── scripts/        # Cross-plugin utilities
        └── validators/     # Validation tools
```

**Migration**: Decide if tools/requirements/ stays or moves to shared/

### Hook System Updates

**No breaking changes** - hooks work the same

**Enhancement**: Marketplace-level SessionStart hook added

### Deprecated Patterns

❌ **Direct cross-plugin script sourcing**:
```bash
source ../other-plugin/helper.sh
```

✅ **Use shared utilities or public APIs**:
```bash
source tools/anspar-cc-plugins/shared/scripts/helper.sh
bash tools/anspar-cc-plugins/plugins/other/scripts/public-script.sh
```

## Configuration Updates

### CLAUDE.md References

**Old** (manual section):
```markdown
## Plugins

We use plugins from tools/anspar-marketplace/
```

**New** (automatic via SessionStart hook):
```markdown
## Agent Orchestration Pattern
<!-- ORCHESTRATION_V1 -->

- ALWAYS check for available sub-agents before implementing complex tasks
- Use `/agents` command to see available specialized agents
- Delegate to sub-agents when their expertise matches the task
- Act as orchestrator, not implementer, when agents are available
```

**Migration**: Run Claude Code session → hook adds section automatically

### CI/CD Pipeline Updates

**Check**: Does your CI/CD use tools/requirements/ scripts?

**Current**:
```yaml
python3 tools/requirements/validate_requirements.py
```

**Future Options**:
1. Keep as-is (tools/requirements/ stays)
2. Update to shared/validators/ (if moved)
3. Use plugin skill (if packaged as plugin)

**For this project**: Keep tools/requirements/ unchanged (REQ validation MUST NOT change)

### Documentation Updates

**Files to update after migration**:
- Main README.md → Reference new marketplace
- CLAUDE.md → Update any plugin references
- Individual spec/*.md files → If they reference plugins
- GitHub workflows → If they reference plugin paths

## Validation and Testing

### Pre-Migration Checklist

Before migrating a plugin:

- [ ] Read existing agent definition
- [ ] Identify all skills and hooks
- [ ] Document dependencies (other plugins, external tools)
- [ ] Review test suite (if exists)
- [ ] Check for hardcoded paths
- [ ] Verify no secrets in code

### Post-Migration Validation

After migrating a plugin:

- [ ] Agent appears in `/agents`
- [ ] Agent has proper YAML frontmatter
- [ ] Description is clear and helpful
- [ ] Orchestrator can invoke agent successfully
- [ ] All skills work as expected
- [ ] Hooks trigger appropriately
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Added to marketplace.json
- [ ] No regressions in functionality

### Testing Strategy

**1. Unit Tests** (plugin-level):
```bash
cd plugins/plugin-name
bash tests/test.sh
```

**2. Integration Tests** (orchestration):
```
Claude session:
1. Check /agents shows plugin agent
2. Request task that should trigger agent
3. Verify agent is invoked (not bypassed)
4. Confirm result is correct
```

**3. Hook Tests** (event-based):
```
1. Trigger relevant event (session start, tool use, etc.)
2. Verify hook executes
3. Check hook output/side effects
```

**4. Cross-Plugin Tests** (multi-agent):
```
1. Request task requiring multiple plugins
2. Verify orchestrator coordinates correctly
3. Confirm each agent does its part
4. Check combined result
```

### Rollback Procedures

**If migration fails**:

1. **Remove from marketplace.json**:
   ```json
   {
     "plugins": [] // Remove failed plugin entry
   }
   ```

2. **Keep old plugin active**:
   - Old marketplace still present
   - Plugin still works via old marketplace

3. **Debug and retry**:
   - Fix issues in new plugin
   - Test again
   - Re-add to marketplace.json when ready

**No data loss risk**: Migration is additive (doesn't delete old marketplace)

## Timeline and Milestones

### Phase 1: Scaffold Creation ✅ COMPLETE

**Duration**: Complete (Nov 2025)

**Deliverables**:
- [x] Marketplace structure at tools/anspar-cc-plugins/
- [x] Documentation (ARCHITECTURE, PLUGIN_DEVELOPMENT, ORCHESTRATION, MIGRATION)
- [x] SessionStart hook for CLAUDE.md configuration
- [x] Empty plugins/ directory ready for migration

### Phase 2: Core Plugin Migration (Next)

**Duration**: 1-2 weeks

**Deliverables**:
- [ ] plugin-wizard created (bootstrap)
- [ ] linear-api migrated and tested
- [ ] workflow migrated and tested
- [ ] simple-requirements migrated and tested (REQ format validated)

**Success criteria**:
- All 4 plugins appear in `/agents`
- Orchestrator reliably delegates to them
- No regressions in functionality
- Tests pass

### Phase 3: Project-Specific Plugin Migration

**Duration**: 1-2 weeks

**Deliverables**:
- [ ] requirement-traceability migrated
- [ ] spec-compliance migrated
- [ ] compliance-verification migrated or merged
- [ ] traceability-matrix migrated or merged

**Success criteria**:
- All diary-specific workflows work
- REQ traceability preserved
- Compliance checks functional

### Phase 4: Deprecation and Cleanup

**Duration**: 1 week

**Deliverables**:
- [ ] Mark tools/anspar-marketplace/ as deprecated
- [ ] Update all documentation
- [ ] Archive old marketplace (don't delete)
- [ ] Update CI/CD if needed
- [ ] Final validation

**Success criteria**:
- No references to old marketplace in active docs
- All plugins working in new marketplace
- CI/CD passing
- Users guided to new marketplace

### Total Estimated Timeline

**4-6 weeks** from Phase 2 start to completion

## Critical Constraints

### REQ Format Must Not Change (MANDATORY)

**Why**:
- Existing commits reference REQ IDs
- INDEX.md tracks requirements with specific format
- Git hooks enforce REQ-{type}{5digits} format
- Changing format breaks traceability

**Validation**:
```bash
# Before migration
cd tools/anspar-marketplace/plugins/simple-requirements
python3 scripts/validate.py > /tmp/old-output.txt

# After migration
cd tools/anspar-cc-plugins/plugins/simple-requirements
python3 scripts/validate.py > /tmp/new-output.txt

# Compare
diff /tmp/old-output.txt /tmp/new-output.txt
# Should be identical (or only cosmetic differences)
```

### Workflow Must Be Preserved

**Key behaviors**:
- Ticket must be claimed before commits
- REQ references required in commit messages
- Workflow state tracked in .git/WORKFLOW_STATE

**Validation**:
- Test full claim → edit → commit → release workflow
- Verify hooks block uncommitted without ticket
- Confirm REQ references validated

## Success Metrics

### Technical Metrics

- [ ] 100% of plugins have agents with YAML frontmatter
- [ ] Orchestrator delegates to sub-agents (>80% of relevant requests)
- [ ] No regressions in functionality
- [ ] All tests passing
- [ ] CI/CD green

### User Experience Metrics

- [ ] Users report more reliable plugin behavior
- [ ] Fewer instances of "reimplementation" by main agent
- [ ] Clear `/agents` output helps users understand capabilities
- [ ] Documentation clarity improved

### Development Metrics

- [ ] New plugins created via 2-phase workflow
- [ ] Plugin creation time reduced
- [ ] Consistent plugin quality (via templates)
- [ ] Easier debugging (clear agent boundaries)

## Getting Help

**During migration**:
- Reference this MIGRATION.md document
- Check ARCHITECTURE.md for design decisions
- Review PLUGIN_DEVELOPMENT.md for patterns
- Consult ORCHESTRATION.md for delegation patterns

**If stuck**:
- Compare with successfully migrated plugins
- Test with `/agents` to verify discoverability
- Use plugin-expert for validation
- Ask for clarification on ambiguous requirements

## References

- [Architecture Documentation](./ARCHITECTURE.md)
- [Plugin Development Guide](./PLUGIN_DEVELOPMENT.md)
- [Orchestration Patterns](./ORCHESTRATION.md)
- Plugin-wizard concept: `untracked-notes/plugin-wizard-concept.md`
- Old marketplace: `tools/anspar-marketplace/`
- New marketplace: `tools/anspar-cc-plugins/`
