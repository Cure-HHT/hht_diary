# Core Development Practices

> **Usage**: Include in ALL development prompts to ensure consistent practices
>
> **Constitutional Status**: Contains IMMUTABLE principles (marked 🔒) that form the architectural foundation, and FLEXIBLE guidelines that evolve with project needs.
>
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture and core/sponsor separation

**Version**: 2.1.0 | **Last Amended**: 2025-01-24

## 🔒 Architectural Constitution

> **IMMUTABLE**: These principles are non-negotiable and define the core identity of our development approach.

### 🔒 I. Library-First Architecture (NON-NEGOTIABLE)

Major features MUST begin as standalone libraries before integration into the application.

**Scope Definition**:

**Requires Library-First** (Major Features):
- New functional capabilities that could be reused
- Anything that takes >1 day to implement
- New domain models or entities

**Does NOT Require Library-First** (Minor Tweaks):
- UI/UX adjustments (styling, layout changes)
- Configuration changes
- Bug fixes to existing code
- Simple data transformations
- Single-use utility functions
- Logging or monitoring additions
- Documentation updates
- Refactoring existing code structure

**When Unclear**:
- AI agents MUST ask the user: "Should this be implemented as a library (reusable, testable component) or as direct application code (minor tweak)?"
- If ticket doesn't specify, developer should evaluate:
  - Could this be reused elsewhere? → Library
  - Does this contain complex logic? → Library
  - Is this a simple one-off change? → Direct implementation
  - When in doubt → Ask technical lead or treat as library

**Requirements for Libraries**:
- Features MUST be self-contained with clear boundaries
- Libraries MUST be independently testable without application context
- Libraries MUST have documented public interfaces
- Library purpose must be functional, not just organizational

**Exception Process**: 
For cases where library-first is clearly impractical, document:
- Why library abstraction is inappropriate for this specific feature
- What alternatives were considered
- Mitigation plan for testability concerns
- Technical lead approval required

**Rationale**: Forces modular design for substantial features while avoiding overhead for simple changes. Ensures reusability is built-in for major capabilities, prevents tight coupling for complex logic, but doesn't create unnecessary abstraction for minor tweaks.

### 🔒 II. Test-Driven Development (NON-NEGOTIABLE)

All implementation MUST follow strict Test-Driven Development. No exceptions.

**Requirements**:
1. **Tests MUST be written before any implementation code**
2. **Tests MUST be reviewed and approved** by another developer
3. **Tests MUST fail** (Red phase confirmed) before implementation begins
4. **Then and only then** can implementation code be written
5. **Implementation continues** until all tests pass (Green phase)
6. **Refactor** to improve code quality while maintaining green tests

**Validation Gates**:
- [ ] Unit tests written covering all requirements
- [ ] Tests reviewed by peer (not the implementer)
- [ ] Tests confirmed to fail (Red phase)
- [ ] Approval granted to proceed with implementation
- [ ] Implementation makes tests pass (Green phase)
- [ ] Code refactored for quality (tests still pass)

**This is Not Flexible**: "Write tests immediately after" is NOT acceptable. Tests MUST precede implementation.

**Rationale**: Tests become specification of behavior, prevent feature creep, serve as documentation, and provide regression safety for refactoring.

### 🔒 III. Integration-First Testing (NON-NEGOTIABLE)

Tests MUST include realistic environments, not mocks, before merging to main.
Tests MAY use mocks for unit testing locally.

**Requirements**:
- **Prefer**: Real databases over mocks
- **Prefer**: Actual service instances over stubs
- **Mandatory**: Contract tests before any inter-service implementation
- **Mandatory**: Real databases must be used for testing before commits or merges 
- **Mocking allowed only when**: Unit testing, External costs prohibit (paid APIs), real environment impractical (hardware dependencies), or explicitly justified

**Contract Testing**:
- Define contracts between components before implementation
- Write contract tests that both sides must pass
- Contract changes require explicit version management
- Both provider and consumer must validate against contracts

**Rationale**: Prevents "works in isolation, fails in integration" problems. Mocks can drift from reality. Real environments catch integration issues early.

### 🔒 IV. Anti-Abstraction Principle (NON-NEGOTIABLE)

Use framework features directly rather than wrapping them. Every abstraction layer MUST be justified.

**Default Approach**:
- Use framework/library APIs directly
- Trust the framework to do its job
- Avoid "just in case" abstraction layers
- Don't create wrappers for future flexibility

**When Abstraction IS Justified**:
- Isolating external service that may change vendors
- Simplifying complex framework API for team consistency
- Compliance requirement for audit trail on framework calls
- Performance optimization requiring caching layer

**Required Documentation for Abstractions**:
- Why direct framework use is insufficient
- What specific problem the abstraction solves
- Cost/benefit analysis of added complexity
- Approval from technical lead

**Rationale**: Abstractions add complexity, obscure actual behavior, require maintenance, and often solve problems that never materialize.

### 🔒 V. Simplicity Gates (NON-NEGOTIABLE)

Complexity MUST be justified with documented rationale.

**Quantifiable Limits**:
- Maximum 3 projects/modules for initial implementation
- Maximum 3 layers of abstraction in any call stack
- Additional complexity requires explicit approval

**Before Adding Complexity, Document**:
- Why simpler approach is insufficient
- What specific problem complexity solves
- Alternatives considered and rejected
- Long-term maintenance implications

**YAGNI Enforcement**:
- Do not build for hypothetical future requirements
- Implement only what current requirements demand
- Future-proofing must be explicitly justified
- "We might need it later" is not justification

**Phase -1 Validation Gates** (Before Any Implementation):

```markdown
## Pre-Implementation Validation

### Simplicity Gate
- [ ] Using ≤3 projects/modules?
- [ ] Maximum 3 abstraction layers?
- [ ] No future-proofing without justification?
- [ ] Documented rationale for complexity?

### Anti-Abstraction Gate  
- [ ] Using framework features directly?
- [ ] Abstractions justified with documentation?
- [ ] No "just in case" wrapper layers?

### Integration-First Gate
- [ ] Contract tests defined?
- [ ] Using real environments over mocks?
- [ ] Mock usage explicitly justified?
```

**These gates MUST pass before writing any implementation code.**

---

## Multi-Sponsor Architecture Boundaries

### Public Core Repository (`clinical-diary`)

**Purpose**: Shared, reusable components across all sponsors

**Contains**:
- Abstract base classes and interfaces
  - `SponsorConfig` - Sponsor configuration interface
  - `EdcSync` - EDC integration interface
  - `PortalCustomization` - Portal customization interface
- Core database schema (`packages/database/`)
- Mobile app framework (Flutter)
- Shared UI components
- Build tooling and validation scripts
- Contract tests

**Must NOT contain**:
- Sponsor-specific business logic
- Proprietary algorithms or integrations
- Authentication credentials or secrets
- Sponsor-specific branding or configuration
- Any information that could identify a sponsor

**Development Principles**:
- Library-First applies: All shared functionality as packages
- Test-Driven Development: Contract tests define sponsor obligations
- Anti-Abstraction: No "just in case" sponsor hooks
- Integration-First: Contract tests verify sponsor implementations

### Private Sponsor Repositories (`clinical-diary-{sponsor}`)

**Purpose**: Sponsor-specific implementations and customizations

**Contains**:
- Concrete implementations of core interfaces
  - Sponsor-specific `SponsorConfig` implementation
  - EDC integration (if proxy mode)
  - Custom portal pages and reports
- Sponsor database extensions (`database/extensions.sql`)
- Edge Functions (Deno/TypeScript)
- Sponsor branding (logos, themes, colors)
- Site configurations and initial data
- Supabase project configuration

**Must NOT contain**:
- Modifications to core schema (use extensions)
- Forks of core components (extend, don't fork)
- Core framework code (import from published packages)

**Development Principles**:
- Import core from GitHub Package Registry
- Pass all core contract tests before deployment
- TDD for sponsor-specific logic
- Integration testing with real Supabase instance

### Contract Testing (Core ↔ Sponsor)

**Core Provides Contract Tests**:
```dart
// In core repository: packages/contracts/test/sponsor_config_test.dart
void main() {
  test('SponsorConfig must provide valid Supabase URL', () {
    final config = getSponsorConfig(); // Implemented by sponsor
    expect(config.supabaseUrl, startsWith('https://'));
    expect(config.supabaseUrl, endsWith('.supabase.co'));
  });

  test('SponsorConfig must provide theme colors', () {
    final config = getSponsorConfig();
    expect(config.theme.primaryColor, isNotNull);
    expect(config.theme.secondaryColor, isNotNull);
  });
}
```

**Sponsors Must Pass Contract Tests**:
```bash
# In sponsor repository
npm install @clinical-diary/contracts@latest
npm test  # Runs contract tests against sponsor implementation

# Build system enforces: All contract tests must pass
```

### Build System Validation

**Core Package Publishing**:
```bash
# In core repository
cd packages/database
npm version patch
npm publish  # Publishes to GitHub Package Registry
# → @clinical-diary/database@1.2.4
```

**Sponsor Build Process**:
```bash
# In sponsor repository
# 1. Install core packages
npm install @clinical-diary/database@1.2.4
npm install @clinical-diary/contracts@1.2.4

# 2. Run contract tests
npm test  # MUST pass before build

# 3. Build with sponsor implementation
dart run build_runner build

# 4. Deploy to Supabase
supabase db push
supabase functions deploy
```

### Code Review Requirements

**Core Repository PRs**:
- Review by core team
- No sponsor-specific logic allowed
- Breaking changes require migration path
- Contract test updates coordinated with sponsors

**Sponsor Repository PRs**:
- Review by sponsor team
- Contract tests must pass
- Core version pinned (no automatic upgrades)
- Security review for proprietary code

---

## Code Quality Standards

> **Note**: These standards support the Constitutional Principles above. When in conflict, Constitutional Principles take precedence.

### Always Follow These Practices

1. **Update Documentation Immediately**
   - When adding a library: Update `technical-stack.md` immediately
   - When removing a library: Document why and update dependencies
   - When making architectural decisions: Document in ADR (Architecture Decision Record)
   - When implementing compliance features: Update compliance documentation

2. **Branch Strategy**
   - Create a new feature branch for each ticket: `feature/TICKET-XXX-brief-description`
   - Create hotfix branches from main: `hotfix/TICKET-XXX-brief-description`
   - Never commit directly to `main` or `develop`
   - Keep branches focused on single tickets/features

3. **Commit Practices**
   - Write clear, descriptive commit messages
   - Format: `[TICKET-XXX] Brief description of change`
   - Include "why" in commit body, not just "what"
   - Commit frequently with logical units of work

4. **Code Review Requirements**
   - All code must be reviewed before merge
   - Self-review your own PR first
   - Run all tests locally before creating PR
   - Address all review comments or explain why not

## Implementation Standards

### Before Writing Code

1. **Understand the Requirement**
   - Read the ticket completely
   - Understand how it connects to phase and project goals
   - Identify dependencies and blockers
   - Ask questions before starting

2. **Plan the Implementation**
   - Identify affected components
   - Consider edge cases
   - Plan for error handling
   - Think about testing strategy

3. **Check Existing Patterns**
   - Review similar existing code
   - Follow established patterns in the codebase
   - Don't introduce new patterns without discussion
   - Maintain architectural consistency

### While Writing Code

1. **Write Clean Code**
   - Functions should do one thing
   - Use descriptive names (prefer clarity over brevity)
   - Avoid deep nesting (max 3 levels)
   - Keep files focused and reasonably sized
   - Extract magic numbers to named constants

2. **Handle Errors Properly**
   - Never silently catch exceptions
   - Log errors with context
   - Fail fast for programming errors
   - Gracefully handle user errors
   - Provide actionable error messages

3. **Observability Through Structured Logging**
   - Use structured logging (JSON format) for all operational events
   - Include correlation IDs for request tracing
   - Log performance metrics for operations >100ms
   - Separate operational logs from audit trails
   - **Never log**: credentials, PII, PHI, or sensitive data
   - Log levels: DEBUG (development), INFO (operations), WARN (unexpected), ERROR (failures), FATAL (critical)
   - **Purpose**: Debugging and performance evaluation
   - **See Compliance Practices for audit trail requirements (data integrity)**

3. **Write Defensive Code**
   - Validate inputs
   - Check preconditions
   - Assert invariants
   - Handle null/undefined explicitly
   - Consider concurrency issues

4. **Document as You Go**
   - Add comments for "why", not "what"
   - Document complex algorithms
   - Explain non-obvious code
   - Add TODOs for future improvements (with ticket references)

### After Writing Code

1. **🔒 Write Tests BEFORE Code (Constitutional Requirement)**
   - **MUST follow TDD**: Tests → Review → Fail → Implement → Pass → Refactor
   - Unit tests for business logic
   - Integration tests for component interactions (prefer real environments)
   - Contract tests before any inter-service implementation
   - E2E tests for critical user flows
   - Aim for 80%+ coverage
   - Test edge cases and error conditions
   - **See Constitutional Principle II for non-negotiable TDD process**

2. **Self-Review**
   - Read your own diff
   - Check for debug code, console logs
   - Verify variable names make sense
   - Ensure consistent formatting
   - Remove commented-out code

3. **Update Related Documentation**
   - README if setup changed
   - API documentation if contracts changed
   - User documentation if features added
   - Compliance docs if security/audit affected

## Performance & Optimization

### Always Consider

- **Database Queries**: Use indexes, avoid N+1 queries, paginate results
- **Network Calls**: Batch when possible, cache appropriately, handle retries
- **Memory Usage**: Clean up resources, avoid memory leaks, use appropriate data structures
- **UI Performance**: Keep UI thread responsive, use async operations, optimize renders

### Don't Optimize Prematurely

- Profile before optimizing
- Measure impact of optimizations
- Document performance requirements
- Only optimize hot paths

## Security Practices

### Every Developer's Responsibility

1. **Input Validation**
   - Validate all user input
   - Sanitize data before display
   - Use parameterized queries
   - Avoid injection vulnerabilities

2. **Authentication & Authorization**
   - Never trust client-side checks
   - Verify permissions on backend
   - Use secure session management
   - Implement proper logout

3. **Sensitive Data**
   - Never log sensitive information
   - Encrypt sensitive data at rest
   - Use HTTPS for all network communication
   - Follow key management best practices

4. **Dependencies**
   - Keep dependencies updated
   - Review security advisories
   - Audit new dependencies
   - Minimize attack surface

## Refactoring Guidelines

> **Constitutional Requirement**: Refactoring MUST maintain green tests. No test-less refactoring.

### When to Refactor

- You need to modify code and it's hard to understand
- You notice duplicated code
- A function has grown too large
- Complexity is increasing
- You're about to add a third similar case (Rule of Three)

### How to Refactor Safely

1. Ensure good test coverage first
2. Make small, incremental changes
3. Run tests after each change
4. Keep refactoring separate from feature work
5. Document what changed and why

### Don't Refactor Without Tests

- High risk of introducing bugs
- No way to verify behavior unchanged
- Write tests first, then refactor

## Technical Debt Management

### Identify Debt Explicitly

- Mark with TODO comments including ticket reference
- Log in technical debt backlog
- Estimate impact and effort
- Don't let debt accumulate silently

### Balance Debt and Features

- Allocate time to pay down debt (e.g., 20% of sprints)
- Fix debt when working in area
- Prioritize debt that blocks features
- Don't gold-plate, but don't build on quicksand

## Common Pitfalls to Avoid

❌ Committing code that doesn't compile
❌ Pushing failing tests
❌ Skipping code review
❌ Writing code without understanding requirements
❌ Ignoring linter warnings
❌ Hardcoding configuration values
❌ Copying and pasting without understanding
❌ Making changes without testing
❌ Leaving debug statements in production code
❌ Assuming users will never do X

## Getting Unstuck

If you're blocked for more than 2 hours:

1. **Clearly define the problem**
   - What are you trying to accomplish?
   - What have you tried?
   - What's not working?

2. **Research**
   - Check documentation
   - Search error messages
   - Look for similar issues in codebase
   - Review relevant tests

3. **Ask for Help**
   - Provide context and what you've tried
   - Share relevant code snippets
   - Explain your understanding of the problem
   - Don't let blockers fester

## Continuous Improvement

### Learn from Each PR

- What went well?
- What took longer than expected?
- What would you do differently?
- What patterns emerged?

### Stay Current

- Read release notes of dependencies
- Follow security advisories
- Learn new language/framework features
- Share knowledge with team

### Contribute to Standards

- These standards evolve
- Propose improvements
- Document new patterns
- Share lessons learned

## 🔒 Constitutional Governance

### Amendment Process

The Constitutional Principles (marked 🔒) are IMMUTABLE and require formal amendment to change.

**To Amend a Constitutional Principle**:

1. **Proposal Phase**
   - Document the proposed change in detail
   - Explain why the current principle is insufficient
   - Provide concrete examples of problems caused by current principle
   - Assess impact on existing codebase
   
2. **Review Phase**
   - Technical lead review required
   - Architecture review board consideration
   - Team discussion and feedback period (minimum 1 week)
   - Compliance officer review if amendment affects regulatory compliance
   
3. **Approval Phase**
   - Requires approval from:
     - Technical lead
     - Project maintainers
     - Compliance officer (if applicable)
   - Vote must be unanimous for core safety/compliance principles
   - Simple majority for architectural preferences
   
4. **Implementation Phase**
   - Update constitution document with new version number
   - Document rationale in amendment history
   - Update all dependent templates and processes
   - Communicate change to all team members
   - Create migration plan for existing code (if needed)
   - Set effective date for new principle

5. **Backwards Compatibility Assessment**
   - How does this affect existing code?
   - What migration path exists?
   - Are there any compliance implications?
   - Timeline for existing code to comply

### Amendment History

**Version 2.0.0** - [Current Date]
- Added Library-First Architecture principle
- Strengthened TDD from "first or immediately" to "strictly before implementation"
- Added Integration-First Testing principle
- Added Anti-Abstraction principle
- Added Simplicity Gates with quantifiable limits
- Added Constitutional Governance structure
- Distinguished between audit trails (compliance) and operational logs (debugging)
- Added AI Development governance principles

**Version 1.0.0** - [Original Date]
- Initial core practices established

### Flexible Guidelines vs. Immutable Principles

**Immutable Constitutional Principles** (🔒):
- Library-First Architecture
- Test-Driven Development (strict)
- Integration-First Testing
- Anti-Abstraction Principle
- Simplicity Gates

These form our architectural identity and can only change through formal amendment process.

**Flexible Guidelines** (No 🔒):
- Code formatting standards
- Specific technology choices
- Branch naming conventions
- Commit message formats
- Performance optimization techniques
- Documentation styles

These can evolve with project needs through normal team discussion and consensus.

### Compliance with Constitution

**Every PR Must**:
- Pass Phase -1 Validation Gates
- Follow TDD process (tests approved before implementation)
- Demonstrate library-first approach (or justified exception)
- Use real environments in tests (or justified mocking)
- Avoid unnecessary abstractions (or justified complexity)

**Code Reviewers Must Verify**:
- Constitutional compliance before approving
- Phase -1 gates passed
- TDD process followed
- No architectural violations
- Complexity is justified

### When Principles Conflict

If multiple constitutional principles appear to conflict:

1. Safety and compliance principles override architectural preferences
2. Consult technical lead for interpretation
3. Document the conflict and resolution in PR
4. Consider if conflict indicates need for constitutional amendment

**Priority Order**:
1. Regulatory compliance requirements (highest priority)
2. Security principles
3. Test-Driven Development
4. Library-First Architecture  
5. Integration-First Testing
6. Anti-Abstraction / Simplicity

### Living Constitution

While principles are immutable, our understanding of them evolves:

- Document patterns that exemplify principles
- Share case studies of principle application
- Clarify edge cases through team discussion
- Update examples and guidance regularly
- Maintain FAQ for common questions

**The constitution is stable but our mastery of it deepens with experience.**
