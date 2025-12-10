# QA/SDET Onboarding Guide

Welcome to the HHT Clinical Trial Diary Platform team. This guide supplements the [Developer Onboarding Guide](README-Onboarding.md)—read that first for system context, then return here for QA-specific orientation.

## Your Role in a Regulated Environment

In clinical trial software under FDA 21 CFR Part 11, QA isn't just about finding bugs—it's about **proving the system works correctly** and **maintaining audit-ready evidence**.

### What Makes Clinical Trial QA Different

| Traditional QA | Clinical Trial QA |
| -------------- | ----------------- |
| "Does it work?" | "Can we prove it works?" |
| Test reports for the team | Test reports for FDA auditors |
| Fix bugs before release | Document that bugs were found and fixed |
| Coverage is a metric | Coverage is compliance evidence |
| Tests verify features | Tests verify requirements (traceability) |

### The Audit Mindset

An FDA inspector may ask:
- "Show me the test that validates requirement REQ-p00042"
- "Prove this feature was tested before release"
- "Where is the evidence that defect #123 was resolved?"

**Your test artifacts are legal documents.** They must be traceable, timestamped, and retained for 7+ years.

## Testing Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     CI/CD Pipeline                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Flutter Unit │  │  TypeScript  │  │  PostgreSQL  │          │
│  │    Tests     │  │    Tests     │  │    Tests     │          │
│  │  (flutter)   │  │   (Jest)     │  │   (pgTAP)    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Integration  │  │   Security   │  │  Compliance  │          │
│  │    Tests     │  │  Scanners    │  │  Validation  │          │
│  │  (Flutter)   │  │(Trivy,etc)   │  │  (Custom)    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              Build Reports & Evidence               │        │
│  │    (Traceability matrices, test results, coverage)  │        │
│  └─────────────────────────────────────────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Test Suites by Component

### 1. Flutter/Dart Tests (Mobile App & Core Packages)

**Location**: `apps/clinical_diary/test/`

```
test/
├── screens/       # UI screen tests (15+ files)
├── widgets/       # Widget component tests (12+ files)
├── services/      # Service layer tests (auth, enrollment, etc.)
├── models/        # Data model tests
├── config/        # Configuration tests
└── test_helpers/  # Shared utilities, flavor setup
```

**Run locally**:
```bash
cd apps/clinical_diary
flutter test                           # All unit tests
flutter test test/screens/             # Screen tests only
flutter test --coverage                # With coverage report
```

**Integration tests**: `apps/clinical_diary/integration_test/`
```bash
flutter test integration_test/         # Requires desktop target
```

Key integration tests:
- `home_screen_integration_test.dart` - Main screen flows
- `recording_save_flow_test.dart` - Diary entry save workflow
- `delete_record_integration_test.dart` - Record deletion
- `partial_save_test.dart` - Interrupted save recovery

### 2. TypeScript/Firebase Tests

**Location**: `apps/clinical_diary/functions/src/__tests__/`

```
__tests__/
├── auth.test.ts              # Authentication flows
├── sponsor.test.ts           # Sponsor configuration
├── sponsor.integration.test.ts
├── cors.test.ts              # CORS handling
├── validators.test.ts        # Input validation
└── index.test.ts             # Main function tests
```

**Run locally**:
```bash
cd apps/clinical_diary/functions
npm test                      # Jest unit tests
npm run test:integration      # Requires Firebase emulator
```

### 3. Database Tests

**Location**: `database/tests/`

```
tests/
├── test_audit_trail.sql        # Audit trail verification
├── test_compliance_functions.sql # Compliance function tests
└── run_all_tests.sh            # Test runner
```

**Run locally**:
```bash
cd database/tests
./run_all_tests.sh              # Requires PostgreSQL connection
```

### 4. Comprehensive Test Suite

**The main test orchestrator**: `apps/clinical_diary/tool/test.sh`

This 380+ line script runs everything:
- Flutter unit tests (configurable concurrency)
- Flutter integration tests (desktop targets)
- TypeScript unit tests (ESLint, build, Jest)
- TypeScript integration tests (Firebase emulator)

```bash
cd apps/clinical_diary
./tool/test.sh                  # Full suite
```

## CI/CD Workflows

### QA Automation (`qa-automation.yml`)

**Implements**: REQ-d00031 (Automated QA Testing), REQ-d00033 (FDA Validation)

This is the primary QA workflow:
- Smart trigger detection (skips docs-only changes)
- Multi-stage Docker builds with caching
- Flutter unit tests with coverage
- Comprehensive QA suite via `qa-runner.sh`
- Test report generation with PR comments
- 30-day artifact retention

### Other Key Workflows

| Workflow | Purpose | Trigger |
| -------- | ------- | ------- |
| `clinical_diary-ci.yml` | Flutter analysis + unit tests | PR to main |
| `clinical_diary-coverage.yml` | Coverage reporting to Codecov | PR to main |
| `build-test.yml` | Requirement validation + traceability | PR to main |
| `pr-validation.yml` | PR gate checks | All PRs |
| `requirement-verification.yml` | Requirement compliance | On demand |

## Security Scanning

QA owns security validation. Our defense-in-depth strategy:

| Scanner | What It Checks | Blocks PR? |
| ------- | -------------- | ---------- |
| **Gitleaks** | Secrets in code | Yes |
| **Trivy** | Dependency vulnerabilities, IaC issues | No (reports only) |
| **Flutter Analyze** | Dart static analysis | Yes |
| **Squawk** | Dangerous PostgreSQL migrations | Yes |

**Read**: `docs/security/scanning-strategy.md`

### Squawk Rules (Critical for DB Changes)

Squawk prevents migrations that could cause production issues:
- Table locks during ALTER TABLE
- Missing indexes on foreign keys
- NOT NULL without DEFAULT
- Unsafe column type changes

If you're reviewing database migrations, understand these rules.

## Requirement Traceability for QA

### Understanding Requirements

Requirements use the format `REQ-{type}{number}`:
- `REQ-p#####` - Product requirements (what users need)
- `REQ-o#####` - Operations requirements (deployment, monitoring)
- `REQ-d#####` - Development requirements (how we build)

**Browse all requirements**: `spec/INDEX.md`

### Mapping Tests to Requirements

Every test should trace to a requirement. In test files:

```dart
// Tests for REQ-p00042: Diary entry must capture timestamp
void main() {
  group('Diary Entry Timestamp', () {
    test('captures entry time on creation', () {
      // ...
    });
  });
}
```

### Traceability Matrix

The CI generates traceability matrices showing requirement-to-test coverage:
- **Location**: `build-reports/` (generated artifacts)
- **Workflow**: `build-test.yml` generates per-sponsor and combined matrices
- **Retention**: 90 days in GitHub Actions, 7 years in S3

## Validation Reports

### What Gets Validated

1. **Spec compliance** - Do spec files follow format rules?
2. **Requirement format** - Are REQ IDs valid?
3. **Git hook validation** - Are hooks properly installed?
4. **Build integrity** - Do builds complete without errors?

### Where Reports Live

```
build-reports/
├── templates/           # Reference formats
├── combined/            # Cross-sponsor reports
├── callisto/            # Sponsor-specific
└── titan/               # Sponsor-specific

validation-reports/      # Compliance validation results
```

## Key QA-Related Requirements

| Requirement | Description |
| ----------- | ----------- |
| REQ-d00031 | Automated QA Testing |
| REQ-d00033 | FDA Validation Documentation |
| REQ-p01018 | Security Audit and Compliance |
| REQ-d00004 | Local-First Data Entry (heavily tested) |
| REQ-d00005 | Sponsor Configuration Detection |

## Testing Best Practices for This Project

### 1. Test Naming Convention

Tests should clearly indicate what requirement they validate:

```dart
// Good
test('REQ-p00042: entry timestamp is immutable after submission', ...)

// Also acceptable
group('Diary Entry - REQ-p00042', () { ... })
```

### 2. Evidence Generation

Tests that validate compliance requirements should produce artifacts:
- Screenshots for UI validation
- Logs for workflow verification
- Data exports for integrity checks

### 3. Audit Trail Testing

Always verify:
- Events are recorded for all state changes
- Timestamps are captured correctly
- User attribution is accurate
- Hash chains are unbroken

### 4. Multi-Sponsor Testing

Remember sponsor isolation:
- Test that Sponsor A cannot see Sponsor B's data
- Verify RLS policies work at the database level
- Test sponsor-specific configurations independently

## Local Development Setup for QA

### Prerequisites

1. Complete [Developer Onboarding](Onboarding%20-%20Developer.md) setup
2. Install Flutter: `docs/development-prerequisites.md`
3. Configure Doppler: `docs/setup-doppler-new-dev.md`

### Quick Test Commands

```bash
# Flutter unit tests
cd apps/clinical_diary && flutter test

# Flutter with coverage
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html

# TypeScript tests
cd apps/clinical_diary/functions && npm test

# Database tests (requires DB connection)
cd database/tests && ./run_all_tests.sh

# Full suite
cd apps/clinical_diary && ./tool/test.sh
```

### Running Security Scans Locally

```bash
# Gitleaks (secret detection)
gitleaks detect --source .

# Flutter analysis
flutter analyze --fatal-infos

# SQL migration safety (on changed files)
squawk *.sql
```

## Defect Management

### Linking Defects to Requirements

When logging defects:
1. Identify which requirement is affected
2. Reference the requirement in the ticket: "Violates REQ-p00042"
3. When fixed, the commit must include: `Fixes: REQ-p00042`

### Defect Evidence

For audit purposes, document:
- Steps to reproduce
- Expected vs. actual behavior
- Which requirement is violated
- Test case that would have caught it

## Specifications to Read First

In priority order for QA/SDET:

1. `spec/README.md` - Documentation structure
2. `spec/prd-event-sourcing-system.md` - How audit trails work
3. `spec/prd-security.md` - Security requirements you'll validate
4. `spec/dev-compliance-practices.md` - Compliance testing approach
5. `docs/security/scanning-strategy.md` - Security scanner details

## Summary

As QA/SDET on this project, you're responsible for:

1. **Proving compliance** - Tests as evidence, not just verification
2. **Requirement traceability** - Every test maps to a requirement
3. **Audit readiness** - Artifacts retained, searchable, timestamped
4. **Security validation** - Understanding and monitoring security scans
5. **Multi-sponsor isolation** - Verifying data separation works

Your test results may be reviewed by FDA inspectors years from now. Write tests and documentation accordingly.

Welcome to the team.
