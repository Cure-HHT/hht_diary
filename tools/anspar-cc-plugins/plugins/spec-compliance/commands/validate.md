---
name: validate
description: Validate spec/ files against guidelines
arguments: "[FILE-PATH...]"
---

# /spec:validate Command

Validate spec/ directory files against compliance rules defined in spec/README.md.

## Purpose

The `/spec:validate` command ensures compliance by:
- Validating file naming conventions (prd-*, ops-*, dev-*)
- Checking YAML frontmatter structure
- Verifying requirement ID format (REQ-{p|o|d}NNNNN)
- Detecting code examples in PRD files (prohibited)
- Ensuring proper requirement headers
- Validating content scope matches file type

## Usage

```bash
/spec:validate                             # Validate all spec/*.md files
/spec:validate spec/prd-authentication.md  # Validate specific file
/spec:validate spec/prd-*.md               # Validate all PRD files
/spec:validate spec/dev-database.md spec/ops-deployment.md  # Validate multiple files
```

## Arguments

### `FILE-PATH` *(optional, multiple allowed)*

Path(s) to spec files to validate:
- Default: All `spec/*.md` files
- Supports glob patterns
- Multiple files can be specified
- Example: `spec/prd-authentication.md`

## Behavior

### Validation Rules

**All spec files**:
- Filename matches pattern: `{prd|ops|dev}-*.md`
- Contains YAML frontmatter with required fields
- Requirement IDs follow format: `REQ-{p|o|d}NNNNN`
- No trailing whitespace
- Proper markdown formatting

**PRD files** (`prd-*.md`):
- NO code examples allowed
- CLI commands prohibited
- Focus on WHAT, not HOW
- Requirement IDs start with `REQ-p`

**Ops files** (`ops-*.md`):
- CLI commands allowed
- Deployment instructions allowed
- Requirement IDs start with `REQ-o`

**Dev files** (`dev-*.md`):
- Code examples allowed and encouraged
- Implementation details expected
- Requirement IDs start with `REQ-d`

### Validation Output

**Success**:
```
✅ spec/prd-authentication.md
✅ spec/ops-deployment.md
✅ spec/dev-database.md

All validations passed! (3 files)
```

**Failures**:
```
❌ spec/prd-authentication.md
  - Code example found (line 45)
  - Requirement ID format invalid: REQ-auth-001 (line 12)

⚠️  spec/dev-database.md
  - Missing YAML frontmatter

✅ spec/ops-deployment.md

Validation failed: 2 errors, 1 warning
```

## Examples

### Validate All Spec Files

```bash
/spec:validate

# Output:
# Validating spec/ files...
#
# ✅ spec/prd-authentication.md
# ✅ spec/prd-diary-entry.md
# ✅ spec/ops-deployment.md
# ✅ spec/ops-security.md
# ✅ spec/dev-database.md
# ✅ spec/dev-event-sourcing.md
#
# All validations passed! (6 files)
```

### Validate Specific File

```bash
/spec:validate spec/prd-authentication.md

# Output:
# Validating: spec/prd-authentication.md
#
# ✅ Filename format correct (prd-*.md)
# ✅ YAML frontmatter present
# ✅ Requirement IDs valid (REQ-p00001, REQ-p00042)
# ✅ No code examples found
# ✅ Content scope appropriate for PRD
#
# Validation passed!
```

### Validate PRD Files Only

```bash
/spec:validate spec/prd-*.md

# Output:
# Validating PRD files...
#
# ✅ spec/prd-authentication.md
# ✅ spec/prd-diary-entry.md
# ✅ spec/prd-multi-sponsor.md
#
# All validations passed! (3 files)
```

### Validation Failures

```bash
/spec:validate spec/prd-authentication.md

# Output:
# Validating: spec/prd-authentication.md
#
# ❌ Code example detected (line 45):
#    ```python
#    def authenticate(user, password):
#    ```
#    PRD files should not contain code examples.
#    Move implementation details to dev-*.md files.
#
# ❌ Invalid requirement ID (line 12):
#    Found: REQ-auth-001
#    Expected: REQ-p00001 (format: REQ-{p|o|d}NNNNN)
#
# ⚠️  CLI command found (line 67):
#    `docker-compose up`
#    PRD files should focus on WHAT, not HOW.
#    Consider moving to ops-*.md.
#
# Validation failed: 2 errors, 1 warning
```

## Integration Points

This command integrates with:
- **spec/README.md**: Source of validation rules
- **spec/INDEX.md**: Validates requirement IDs exist
- **CI/CD pipeline**: Automated validation on PR
- **spec-compliance plugin**: Enforcement of guidelines

## Exit Codes

- `0` - All validations passed
- `1` - Validation failures found
- `2` - Script error (missing dependencies, file not found)

## Error Handling

The command validates:
- File exists and is readable
- spec/ directory exists
- Files are valid markdown
- YAML frontmatter is valid JSON/YAML
- Requirement IDs are in INDEX.md

### File Not Found

```
Error: File not found: spec/nonexistent.md

Available spec files:
  spec/prd-authentication.md
  spec/prd-diary-entry.md
  spec/ops-deployment.md
  ...

Usage:
  /spec:validate [file1.md file2.md ...]
```

### Invalid File Type

```
Error: File is not in spec/ directory: docs/README.md

Only spec/*.md files can be validated.

Usage:
  /spec:validate spec/prd-*.md
```

### Missing spec/README.md

```
Error: spec/README.md not found

Validation rules are defined in spec/README.md.

This file is required and should contain:
- File naming conventions
- Content scope guidelines
- Requirement ID format rules

Please ensure spec/README.md exists.
```

## Validation Rule Details

### Filename Validation

**Valid patterns**:
- `prd-*.md` - Product requirements
- `ops-*.md` - Operations/deployment
- `dev-*.md` - Development/implementation

**Invalid patterns**:
- `requirement.md` - Missing prefix
- `prd_auth.md` - Wrong separator (use dash)
- `PRD-auth.md` - Wrong case (lowercase only)

### YAML Frontmatter

**Required fields**:
```yaml
---
title: Document Title
description: Brief description
version: 1.0
last_updated: 2025-11-19
---
```

### Requirement ID Format

**Valid**:
- `REQ-p00001` - PRD requirement
- `REQ-o00042` - Ops requirement
- `REQ-d00027` - Dev requirement

**Invalid**:
- `REQ-00001` - Missing type prefix
- `REQ-p1` - Wrong number format (need 5 digits)
- `REQ-auth-001` - Non-numeric ID

### Code Example Detection

**Prohibited in PRD files**:
```markdown
# ❌ NOT ALLOWED in prd-*.md
```python
def example():
    pass
```

# ❌ NOT ALLOWED in prd-*.md
```bash
docker-compose up
```
```

**Allowed in Dev files**:
```markdown
# ✅ ALLOWED in dev-*.md
```python
def implement_feature():
    # Implementation details
    pass
```
```

## Best Practices

1. **Validate before committing**: Catch issues early
2. **Run on all spec files regularly**: Ensure consistency
3. **Fix errors before warnings**: Errors block compliance
4. **Keep PRD files code-free**: Move examples to dev files
5. **Use consistent requirement IDs**: Follow INDEX.md

## Related Commands

- **/requirements:report** - Generate requirement reports
- **/req:scan** - Scan tickets for requirement references
- **spec/README.md** - Validation rule definitions

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/../spec-compliance/scripts/validate-spec-compliance.sh "$@"
```

## Notes

- Validation rules sourced from spec/README.md
- PRD files strictly prohibit code examples
- Ops files allow CLI commands
- Dev files encourage code examples
- Requirement IDs must exist in INDEX.md
- YAML frontmatter is optional but recommended
- Runs in CI/CD to block non-compliant merges
- Color-coded output for readability
