# Bot Security Policy

## Overview

This repository uses automated bots to maintain specific files while enforcing strict security controls. This document outlines the security model and enforcement mechanisms.

## BOT_BYPASS_MAIN_PROTECTION Token

The `BOT_BYPASS_MAIN_PROTECTION` repository secret contains a Personal Access Token that allows bypassing branch protection rules for automated workflows.

**⚠️ SECURITY CRITICAL**: This token bypasses all branch protection. It should only be used by authorized bot workflows.

### Current Authorized Use

**ONLY** the following workflow is authorized to use `BOT_BYPASS_MAIN_PROTECTION`:
- **Workflow**: `.github/workflows/claim-requirement-number.yml`
- **Purpose**: Claim next available requirement number
- **Files Modified**: `spec/INDEX.md` ONLY

## Security Enforcement

### 1. Workflow-Level Validation

Each bot workflow includes pre- and post-execution checks:
- Pre-check: Ensures working tree is clean
- Post-check: Verifies only authorized files were modified
- Fails immediately if unauthorized changes detected

### 2. Repository-Level Validation

**Workflow**: `.github/workflows/validate-bot-commits.yml`

Runs on **every push to main** and:
1. Detects if commit was made by a bot (github-actions[bot] or "Bot:" prefix)
2. If bot commit, validates **only `spec/INDEX.md`** was modified
3. **Fails if any other files were changed**
4. Should be configured as a **required status check**

### 3. Detection Criteria

A commit is considered a "bot commit" if:
- Author email is `github-actions[bot]@users.noreply.github.com`, OR
- Commit message starts with `Bot:`

## Adding a New Bot

If you need to create a new bot that bypasses branch protection:

1. **Document the purpose** - Create an ADR explaining why the bot is needed
2. **Specify files** - Clearly define which files the bot can modify
3. **Create dedicated token** - Create a new secret with explicit name (e.g., `NEW_BOT_NAME_BYPASS_MAIN_BRANCH_PROTECTION`)
4. **Update validation** - Modify `.github/workflows/validate-bot-commits.yml` to allow the new bot's file changes
5. **Review security** - Get approval from security/compliance team
6. **Update this document** - Add the new bot to the "Current Authorized Use" section

**⚠️ DO NOT reuse `BOT_BYPASS_MAIN_PROTECTION` for other bots** - each bot should have its own dedicated token with an explicit name.

## Security Rationale

### Why This Matters

Branch protection exists to enforce code review, testing, and validation. The `BOT_BYPASS_MAIN_PROTECTION` token bypasses these protections, which creates security risks:

- **Risk**: Malicious or buggy bot could commit arbitrary changes
- **Risk**: Developer could create bot to bypass review process
- **Risk**: Compromised workflow could alter critical files

### Defense in Depth

Our multi-layer approach:

1. **Workflow validation** - Bot validates itself before committing
2. **Repository validation** - GitHub Actions validates after commit
3. **Required status checks** - Prevents merge if validation fails
4. **Audit trail** - All bot commits clearly marked and logged

### Limitations

⚠️ **Important**: This validation runs AFTER the commit is pushed to main. It cannot prevent the commit, only detect violations.

**To fully enforce**:
1. Make `validate-bot-commits` a **required status check** in branch protection
2. Enable "Require status checks to pass before merging"
3. Do NOT allow administrators to bypass these checks

Without these settings, the validation is detective (alerts on violations) rather than preventive (blocks violations).

## Incident Response

If a bot commits unauthorized changes:

1. **Immediate**: Revert the commit
2. **Investigate**: Review workflow logs to determine root cause
3. **Rotate**: If compromise suspected, rotate `BOT_BYPASS_MAIN_PROTECTION` immediately
4. **Update**: Fix the bot workflow or validation rules
5. **Document**: Create incident report in security log

## Monitoring

### Regular Audits

- **Weekly**: Review bot commits (`git log --author="github-actions[bot]"`)
- **Monthly**: Verify all bots are still authorized
- **Quarterly**: Review BOT_PAT access and rotate if needed

### Alerts

Configure GitHub notifications for:
- Failed workflow runs on `validate-bot-commits`
- Any push to main by github-actions[bot]
- Changes to `.github/workflows/` directory

## Questions?

For questions about bot security:
- **Technical**: Review `.github/workflows/validate-bot-commits.yml`
- **Policy**: See `docs/adr/` for architecture decisions
- **Compliance**: Contact security team

---

**Last Updated**: 2025-01-24
**Owner**: DevOps / Security Team
**Review Frequency**: Quarterly
