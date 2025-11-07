# Project Context

This is a multi-sponsor clinical trial platform with strict requirement traceability. The project uses codenames for sponsors (e.g., Orion, Andromeda) and enforces formal requirements linking.

## 🚨 CRITICAL RULES

1. **⚠️ REQUIREMENT TRACEABILITY**: ALL code and specs MUST link to requirements (REQ-{p|o|d}NNNNN)
2. **📁 DOCUMENTATION HIERARCHY**: `spec/` defines WHAT/WHY/HOW to build, `docs/` explains WHY decisions were made
3. **🔒 SPONSOR ISOLATION**: Each sponsor has isolated code in `sponsor/{name}/`, NEVER cross-reference sponsors
4. **🔐 SECURITY**: NEVER commit secrets, use `.env` files (gitignored)

## Project Structure

```
.
├── spec/               # Formal requirements (prd-*, ops-*, dev-*)
├── docs/               # Decision records (ADRs) and guides
├── database/           # Shared schema (deployed per-sponsor)
├── packages/           # Core Flutter abstractions
├── apps/               # Flutter app templates
├── sponsor/            # Sponsor-specific implementations
├── tools/              # Development and automation tools
│   ├── requirements/   # Validation and traceability
│   └── claude-marketplace/  # Plugins (see individual READMEs)
└── untracked-notes/    # Scratch work (gitignored)
```

## ⚡ Development Workflow

**⚠️ ALWAYS start with `git pull` to sync with remote and resolve conflicts early**

1. **Sync with remote** - Run `git pull` on startup and before claiming tickets
2. **Claim ticket** (enforced by workflow plugin)
3. **Assess if ADR needed** - Significant architectural decision? **ASK USER if they agree**
4. **Create requirements** - Use requirements subagent for proper cascade (PRD→Ops→Dev)
5. **Implement** - Add requirement references in file headers
6. **Commit** - Include ticket and REQ references

### Commit Format
```
[TICKET-123] Brief description

Detailed changes.

Implements: REQ-p00xxx, REQ-d00yyy
```

## 📋 Quick Reference

| Action | Command/Location |
|--------|-----------------|
| **Validate requirements** | `python3 tools/requirements/validate_requirements.py` |
| **Validate INDEX.md** | `python3 tools/requirements/validate_index.py` |
| Generate traceability | `python3 tools/requirements/generate_traceability.py --format markdown` |
| **Claim new REQ#** | **Actions** → **Claim Requirement Number** (GitHub UI) |
| Enable git hooks | `git config core.hooksPath .githooks` |
| Find requirements | `spec/{prd,ops,dev}-*.md` |
| Find decisions | `docs/adr/ADR-*.md` |
| Requirements index | `spec/INDEX.md` |

## Documentation Guidelines

### spec/ Directory (WHAT to build)
- **prd-**: Product requirements (**NO CODE**)
- **ops-**: Deployment/operations (CLI commands OK)
- **dev-**: Implementation (code examples OK)
- Format: `{audience}-{topic}(-{subtopic}).md`

### docs/ Directory (WHY we chose)
- **ADRs**: Architecture decisions with trade-offs
- Format: `ADR-{number}-{title}.md`
- Create when: Major architectural choices, security models, compliance approaches

⚠️ **IMPORTANT**: Always read `spec/README.md` before modifying spec/ files.

## Plugins & Automation

The project uses Claude Code marketplace plugins in `tools/claude-marketplace/`. These provide:
- Requirement validation and traceability
- spec/ compliance enforcement
- Workflow enforcement
- Linear integration

See individual plugin READMEs for details.