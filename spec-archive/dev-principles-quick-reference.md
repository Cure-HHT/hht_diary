# Constitutional Principles - Quick Reference Card

## 🔒 The Five Immutable Principles

### I. Library-First Architecture
**Rule**: Major features MUST begin as standalone libraries (minor tweaks don't need this)
**Major Features**: New capabilities, complex logic, reusable components, >1 day work
**Minor Tweaks**: UI adjustments, config changes, bug fixes, simple utilities
**Why**: Forces modularity for substantial features, avoids overhead for simple changes
**When Unclear**: AI asks user or developer evaluates reusability/complexity

### II. Test-Driven Development (TDD)
**Rule**: Tests → Review → Fail → Implement → Pass → Refactor
**Why**: Tests become specification, prevents untested code, enables safe refactoring
**Exception**: NONE - This is non-negotiable

### III. Integration-First Testing  
**Rule**: Prefer real databases/services over mocks before merging with main
**Why**: Catches integration issues early, tests reflect reality
**Exception**: Mocks allowed only when justified (cost, impracticality)

### IV. Anti-Abstraction
**Rule**: Use framework features directly, don't wrap them
**Why**: Reduces complexity, avoids maintenance burden, keeps code clear
**Exception**: Requires documented justification (vendor isolation, compliance, etc.)

### V. Simplicity Gates
**Rule**: Max 3 projects initially, max 3 abstraction layers, YAGNI enforced
**Why**: Prevents over-engineering, forces justification of complexity
**Exception**: Additional complexity requires documented rationale + approval

---

## Phase -1 Validation Gates

**MUST PASS BEFORE WRITING ANY CODE**

```markdown
### Simplicity Gate
[] Using <= 3 projects/modules?
[] Maximum 3 abstraction layers?
[] No future-proofing without justification?
[] Documented rationale for any complexity?

### Anti-Abstraction Gate
[] Using framework features directly?
[] All abstractions justified with documentation?
[] No "just in case" wrapper layers?

### Integration-First Gate
[] Contract tests defined?
[] Using real environments over mocks?
[] Mock usage explicitly justified?

### TDD Gate
[] Unit tests written for all requirements?
[] Tests reviewed and approved by peer?
[] Tests confirmed to FAIL (Red phase)?
[] Ready to implement to make tests pass?
```

---

## Audit Trail vs. Operational Logging

### Audit Trail (Data Integrity)
- **Purpose**: Ensure database integrity, regulatory compliance
- **Retention**: 7+ years (regulatory requirement)
- **Immutability**: Cannot be modified or deleted
- **Audience**: Compliance officers, regulators, auditors
- **What**: WHO changed WHAT data, WHEN, WHY
- **System**: `auditTrail.append(entry)`

### Operational Logging (Debugging)
- **Purpose**: Debugging, monitoring, performance evaluation
- **Retention**: 30-90 days (operational needs)
- **Format**: Structured JSON with correlation IDs
- **Audience**: Developers, operations teams
- **What**: System events, errors, performance metrics
- **System**: `logger.info(entry)` / `logger.error(entry)`

**Never confuse these two systems!**

---

## TDD Workflow (Non-Negotiable)

1. **Write Tests**
   - Cover all requirements
   - Include edge cases
   - Document expected behavior

2. **Review Tests**
   - Peer review required
   - Verify completeness
   - Approve or request changes

3. **Confirm Red Phase**
   - Run tests
   - MUST fail (no implementation yet)
   - Confirms tests are actually testing something

4. **Implement**
   - Write minimal code to pass tests
   - Focus on making tests green
   - Don't add extra features

5. **Confirm Green Phase**
   - All tests pass
   - No test failures
   - Ready for refactoring

6. **Refactor**
   - Improve code quality
   - Maintain passing tests
   - Document decisions

**No shortcuts. Tests MUST precede code.**

---

## AI Development Rules

### AI-Generated Code MUST:
[] Follow all constitutional principles
[] Include full audit trail support
[] Pass Phase -1 validation gates
[] Have tests written BEFORE implementation
[] Be reviewed by human developer
[] Follow ALCOA+ principles for data handling

### Human Developer MUST Verify:
[] Audit trail capture is correct
[] Authentication/authorization present
[] No hardcoded credentials
[] Proper error handling
[] Compliance requirements met
[] Tests precede implementation

**AI accelerates but cannot bypass our standards.**

---