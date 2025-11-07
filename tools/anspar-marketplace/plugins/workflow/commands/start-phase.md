# Start Project Phase Command

**USAGE**: `/start_phase <phase>`

**ARGUMENTS**:
- `<phase>`: Project phase to activate (currently supported: `production`)

---

## ⚠️ CRITICAL WORKFLOW PHASE TRANSITION ⚠️

You are about to transition the project to a new phase with **SIGNIFICANT SECURITY AND WORKFLOW CHANGES**.

### Current Request

Transition to phase: **{{phase}}**

---

## What Will Happen: Production Phase Activation

### 🔒 Security Controls Being Enabled

1. **Repository Variable: `WORKFLOW_PROTECTION_ENABLED=true`**
   - Enables automated workflow change detection
   - Triggers security alerts on PRs that modify workflows
   - Posts security checklists for reviewer approval

2. **CODEOWNERS Enforcement**
   - Renames `CODEOWNERS-PRE-PRODUCTION` → `CODEOWNERS`
   - **REQUIRES admin approval** for all changes to:
     - `.github/workflows/` (all workflow files)
     - `.github/BOT_SECURITY.md` (security policies)
     - `.github/rulesets/` (branch protection)
     - `.github/WORKFLOW_PROTECTION.md` (protection docs)

### 📋 Impact on Development Workflow

**BEFORE** (Current State):
- ✅ Anyone with write access can modify workflows
- ✅ No approval gates for `.github/` changes
- ✅ Fast iteration on automation

**AFTER** (Production Phase):
- ⚠️ All workflow changes require admin approval
- ⚠️ Automated security scanning active
- ⚠️ Slower iteration (by design for safety)

### ⏱️ Estimated Time

- **Immediate**: Repository variable set (~30 seconds)
- **Requires PR**: CODEOWNERS activation (~5-10 minutes including review)

---

## 🛑 CONFIRMATION REQUIRED 🛑

**TASK**: Use the `AskUserQuestion` tool to confirm this action.

**Question**: "Are you sure you want to activate PRODUCTION phase protections?"

**Header**: "Phase Change"

**Options**:
1. **"Yes, activate production protections"**
   - Description: "Enable full workflow protection (repository variable + CODEOWNERS enforcement)"
2. **"No, cancel this operation"**
   - Description: "Keep current development-mode settings, make no changes"

---

## If User Confirms: Execute Activation

Run the activation script:

```bash
tools/anspar-marketplace/plugins/workflow/scripts/start-phase.sh production
```

This script will:
1. Set `WORKFLOW_PROTECTION_ENABLED=true` via GitHub API
2. Create branch `activate-production-phase`
3. Rename `CODEOWNERS-PRE-PRODUCTION` → `CODEOWNERS`
4. Commit and push changes
5. Create pull request
6. Display next steps for user

---

## If User Cancels

Display:
```
❌ Production phase activation cancelled.

No changes made. Project remains in development mode.
```

---

## Error Handling

If the phase argument is not recognized:
- Display available phases: `production`
- Exit with helpful message

If GitHub API fails:
- Display error message
- Provide manual activation instructions from `.github/WORKFLOW_PROTECTION.md`

---

## Documentation Reference

See `.github/WORKFLOW_PROTECTION.md` for:
- Complete activation procedures
- Manual fallback steps
- Deactivation procedures
- Troubleshooting guide
