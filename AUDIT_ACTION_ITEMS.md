# Audit Action Items - Remediation Checklist
**Date**: 2025-10-25
**Source**: Internal Consistency Audit

Use this checklist to track remediation of audit findings.

---

## Priority 1: Quick Fixes (Est. 30 min total)

### 1.1 Missing Implementation Headers

- [ ] **database/init.sql** - Add requirement header
  - Suggested requirements: REQ-o00004 (Database Schema Deployment)
  - Format:
    ```sql
    -- IMPLEMENTS REQUIREMENTS:
    --   REQ-o00004: Database Schema Deployment
    --
    -- Database initialization and bootstrap script
    ```

- [ ] **database/seed_data.sql** - Add header or mark as test fixture
  - Option A: If used in production: Add relevant requirements
  - Option B: If test-only: Add comment:
    ```sql
    -- TEST FIXTURE - No production requirements
    -- Used for: Development and testing environments only
    ```

**Estimated Time**: 10 minutes

---

### 1.2 ADR Format Standardization

- [ ] **docs/adr/ADR-001-event-sourcing-pattern.md**
  - Change line 4 from: `**Status**: Accepted`
  - To section format:
    ```markdown
    ## Status

    Accepted
    ```

- [ ] **docs/adr/ADR-002-jsonb-flexible-schema.md** - Same fix

- [ ] **docs/adr/ADR-003-row-level-security.md** - Same fix

- [ ] **docs/adr/ADR-004-investigator-annotations.md** - Same fix

**Estimated Time**: 15 minutes

**Reference**: See docs/adr/README.md for template and ADR-005 for correct format

---

### 1.3 ~~Document Orphaned Requirements~~ [NOT AN ISSUE]

**Status**: ✅ **RESOLVED** - Requirements are NOT orphaned

- **REQ-o00009: Portal Deployment Per Sponsor** (ops-deployment.md:811)
  - **Parent**: REQ-p00008 (Multi-Sponsor Architecture)
  - **Status**: Properly implements parent PRD requirement
  - No Dev requirement needed - uses standard deployment platforms

- **REQ-o00008: Backup and Retention Policy** (ops-operations.md:853)
  - **Parent**: REQ-p00012 (Data Retention Requirements)
  - **Status**: Properly implements parent PRD requirement
  - No Dev requirement needed - uses Supabase managed backups

**Validation warnings about "no child requirements" are expected for Ops-level requirements that use managed services or standard tooling without custom code.**

---

## Priority 2: Documentation Enhancements (Est. 1-2 hours)

### 2.1 Document Refinement Hierarchies

- [ ] **spec/requirements-format.md** - Add new section
  - Section title: "Requirement Refinement Hierarchies"
  - Content should explain:
    - Same-level refinement (PRD→PRD for broad→specific)
    - Cross-level cascade (PRD→Ops→Dev for implementation)
    - When each pattern is appropriate
  - Example:
    ```markdown
    ## Refinement Hierarchies Within Same Level

    Requirements can form hierarchies within the same level (PRD, Ops, or Dev)
    when a specific requirement refines or elaborates a broader requirement.

    **Example**: Compliance decomposition
    - REQ-p00010: FDA 21 CFR Part 11 Compliance (broad)
      - REQ-p00011: ALCOA+ Principles (specific aspect)
      - REQ-p00012: Data Retention (specific aspect)

    This is distinct from cross-level cascade (PRD→Ops→Dev) which represents
    implementation levels, not requirement refinement.
    ```

**Estimated Time**: 30 minutes

---

### 2.2 Document Migration File Headers

- [ ] **database/migrations/README.md** or **DEPLOYMENT_GUIDE.md**
  - Add section: "Migration File Header Format"
  - Document the standard header template:
    ```sql
    -- =====================================================
    -- Migration: [Description]
    -- Number: NNN
    -- Description: [Detailed purpose]
    -- Dependencies: [Prerequisites]
    -- Reference: [spec/file.md or ADR reference]
    -- =====================================================
    ```
  - Note: Migration files use different header format than implementation files

**Estimated Time**: 15 minutes

---

### 2.3 Update Validation Tool Messages

- [ ] **tools/requirements/validate_requirements.py**
  - Update warning message for PRD→PRD relationships
  - Change from: `"Unusual hierarchy (expected: PRD -> Ops -> Dev)"`
  - To: `"Same-level refinement (PRD→PRD). If this is cross-level implementation, expected: PRD → Ops → Dev"`
  - Add link to requirements-format.md section on refinement hierarchies

**Estimated Time**: 15 minutes

---

## Priority 3: Automation (Est. 4-8 hours)

### 3.1 Cross-Reference Link Validation

- [ ] **Create** `tools/validation/check_links.py`
  - Scan all markdown files for cross-reference patterns
  - Validate referenced files exist
  - Validate referenced sections exist (grep for headings)
  - Report broken or outdated links
  - Integration: Add to pre-commit hook and CI/CD

**Estimated Time**: 2-3 hours

**Test Cases**:
```python
# Should pass
"**See**: prd-app.md for application features"

# Should fail
"**See**: nonexistent-file.md for details"
```

---

### 3.2 ADR Format Validation

- [ ] **Create** `tools/validation/check_adr_format.py`
  - Verify ADR files match template structure
  - Required sections: Status, Context, Decision, Consequences, Alternatives
  - Status format: `## Status\n\nAccepted|Proposed|Deprecated|Superseded`
  - Integration: Add to pre-commit hook

**Estimated Time**: 1-2 hours

---

### 3.3 CI/CD Pipeline Implementation

- [ ] **Create** `.github/workflows/requirements-validation.yml`
  - Trigger: On pull request to main
  - Jobs:
    1. Run `validate_requirements.py` (fail on errors, warn on warnings)
    2. Run `check_links.py` (fail on broken links)
    3. Run `check_adr_format.py` (fail on format violations)
    4. Generate traceability matrix (artifact)
  - Status check: Required for merge

**Estimated Time**: 2-3 hours (including testing)

**Reference**: See TODO_CI_CD_SETUP.md

---

### 3.4 Audience Scoping Validation

- [ ] **Create** `tools/validation/check_audience_scoping.py`
  - Verify PRD files don't contain code blocks (```sql, ```dart, etc.)
  - Verify DEV files DO contain implementation examples
  - Verify OPS files contain only operational commands, not app code
  - Integration: Add to CI/CD pipeline

**Estimated Time**: 1-2 hours

---

## Completion Tracking

### Priority 1 (Quick Fixes)
- [x] All 2 missing headers added (2025-10-26)
- [x] All 4 ADRs standardized (2025-10-26)
- [x] ~~Orphaned requirements~~ - Verified as NOT orphaned (2025-10-26)

**Status**: ✅ **COMPLETED** (2025-10-26)

### Priority 2 (Documentation)
- [ ] Refinement hierarchies documented
- [ ] Migration headers documented
- [ ] Validation messages updated

**Target**: Complete within 2 weeks

### Priority 3 (Automation)
- [ ] Link checker implemented
- [ ] ADR format checker implemented
- [ ] CI/CD pipeline live
- [ ] Audience scoping checker implemented

**Target**: Complete within 1 month

---

## Notes

- Create feature branch for each priority level
- Update this checklist as items are completed
- Re-run audit after Priority 1 completion to verify fixes
- Consider adding audit schedule to CLAUDE.md (quarterly?)

---

**Created**: 2025-10-25
**Last Updated**: 2025-10-26
**Next Review**: Before starting Priority 2 implementation
