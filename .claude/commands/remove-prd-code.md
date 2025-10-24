---
description: Remove implementation code from PRD files to enforce audience scope
---

# Task: Remove Implementation Code from PRD Files

Your task is to systematically remove code blocks from PRD (Product Requirements) files to enforce proper audience scope separation.

## Context

Per spec/README.md audience scope rules:
- **prd- files**: Define WHAT and WHY (requirements, not implementation)
- **FORBIDDEN in prd- files**: Code examples, SQL, CLI commands, API definitions
- **ASCII diagrams are OK**: Plain ``` blocks without language tags for diagrams

## Instructions

1. **Identify target files**: Ask user which files to clean, or scan all `spec/prd-*.md` files

2. **For each file**:
   - Read the file to understand structure
   - Identify code blocks with language tags (sql, javascript, js, dart, typescript, bash, etc.)
   - Preserve ASCII diagrams (code blocks without language tags)
   - Remove all code blocks with language tags using this Python approach:

```python
import re

with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

# Remove code blocks with language tags, preserve plain ``` blocks (diagrams)
cleaned = re.sub(r'^```(?:sql|javascript|js|typescript|ts|dart|bash|sh|python|java|go|rust)\n.*?\n```\n?',
                 '', content, flags=re.MULTILINE | re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(cleaned)
```

3. **Validate**: After cleaning each file:
   - Count remaining code blocks
   - Verify ASCII diagrams preserved
   - Report what was removed

4. **Summary**: Report files cleaned and total code blocks removed

## Expected Output Format

```
Cleaned prd-app.md:
  - Removed: 37 code blocks (Dart, TypeScript, SQL)
  - Preserved: 0 ASCII diagrams
  - Remaining: 0 code blocks

Cleaned prd-security-RLS.md:
  - Removed: 21 SQL blocks
  - Preserved: 2 ASCII diagrams
  - Remaining: 4 markers (2 diagrams)

Total: Removed 58 code blocks from 2 files
```

## Notes

- Always use encoding='utf-8', errors='replace' to handle encoding issues
- Never recreate content with AI - only delete mechanically
- User should review and commit changes separately
- This command does NOT commit - it only cleans files
