# Test Results Integration

This directory contains test results and mappings for requirement traceability.

## Overview

The traceability matrix can display test coverage and results for each requirement. This provides visibility into which requirements are tested and their current pass/fail status.

## Directory Structure

```
test_results/
├── README.md                    # This file
├── requirement_test_mapping.json # Maps requirements to test cases
├── jenkins/                     # Jenkins test results (JUnit XML)
│   ├── latest.xml              # Most recent test run
│   └── archive/                # Historical test results
│       ├── 2025-10-25_build-123.xml
│       └── ...
└── manual/                      # Manual test results
    └── manual_test_results.json
```

## Test Result Formats

### 1. JUnit XML (Jenkins Output)

**Location**: `test_results/jenkins/latest.xml`

Jenkins generates standard JUnit XML format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="DatabaseTests" tests="10" failures="0" errors="0" skipped="0" time="5.234">
    <testcase classname="DatabaseTests" name="test_separate_database_per_sponsor" time="0.523">
      <!-- PASSED -->
    </testcase>
    <testcase classname="DatabaseTests" name="test_audit_trail_immutability" time="0.812">
      <failure message="Audit record was modified" type="AssertionError">
        Expected audit record to be immutable, but UPDATE succeeded
      </failure>
    </testcase>
  </testsuite>
</testsuites>
```

### 2. Requirement-Test Mapping

**Location**: `test_results/requirement_test_mapping.json`

Maps requirements to test cases:

```json
{
  "version": "1.0",
  "generated": "2025-10-25T17:30:00Z",
  "mappings": {
    "p00001": {
      "requirement_id": "p00001",
      "requirement_title": "Complete Multi-Sponsor Data Separation",
      "tests": [
        {
          "test_id": "test_separate_database_per_sponsor",
          "test_name": "Test Separate Database Per Sponsor",
          "test_file": "tests/test_database_isolation.py",
          "test_suite": "DatabaseTests",
          "test_type": "integration"
        },
        {
          "test_id": "test_no_cross_sponsor_queries",
          "test_name": "Test No Cross-Sponsor Queries",
          "test_file": "tests/test_database_isolation.py",
          "test_suite": "DatabaseTests",
          "test_type": "integration"
        }
      ],
      "manual_tests": [
        {
          "test_id": "manual_001",
          "test_name": "Manual verification of database separation",
          "tester": "QA Team",
          "last_run": "2025-10-20",
          "status": "passed"
        }
      ]
    },
    "p00004": {
      "requirement_id": "p00004",
      "requirement_title": "Immutable Audit Trail via Event Sourcing",
      "tests": [
        {
          "test_id": "test_audit_trail_immutability",
          "test_name": "Test Audit Trail Immutability",
          "test_file": "database/tests/test_audit_trail.sql",
          "test_suite": "DatabaseTests",
          "test_type": "database"
        }
      ]
    }
  }
}
```

### 3. Manual Test Results

**Location**: `test_results/manual/manual_test_results.json`

For requirements tested manually (UI, usability, compliance):

```json
{
  "version": "1.0",
  "test_run_id": "manual-2025-10-25",
  "test_date": "2025-10-25",
  "tester": "QA Team",
  "results": [
    {
      "test_id": "manual_001",
      "requirement_id": "p00001",
      "status": "passed",
      "notes": "Verified separate databases in Supabase console"
    },
    {
      "test_id": "manual_002",
      "requirement_id": "p00006",
      "status": "not_tested",
      "notes": "Offline functionality - awaiting mobile app deployment"
    }
  ]
}
```

## Test Status Values

| Status | Meaning | Display Color |
|--------|---------|---------------|
| `passed` | All tests passed | Green ✅ |
| `failed` | One or more tests failed | Red ❌ |
| `error` | Test encountered error | Orange ⚠️ |
| `skipped` | Test was skipped | Gray ⊘ |
| `not_tested` | No tests exist for this requirement | Yellow ⚡ |
| `unknown` | Test status unknown | Gray ❓ |

## Integration with Traceability Matrix

The traceability generator reads these files and displays test status:

```bash
# Generate with test results
python3 tools/requirements/generate_traceability.py \
  --format html \
  --test-results test_results/jenkins/latest.xml \
  --test-mapping test_results/requirement_test_mapping.json
```

**HTML Output** will show:
- Test coverage percentage per requirement
- Pass/fail status with color coding
- Number of tests (automated + manual)
- Last test run timestamp
- Links to failing tests (if available)

**Markdown Output** will show:
- ✅/❌ icons for test status
- Test count in metadata
- Coverage information

## Jenkins Integration

### Jenkins Pipeline Configuration

Add to `Jenkinsfile`:

```groovy
pipeline {
    agent any

    stages {
        stage('Test') {
            steps {
                // Run tests
                sh 'pytest --junitxml=test_results/jenkins/latest.xml'

                // Archive results
                sh 'cp test_results/jenkins/latest.xml test_results/jenkins/archive/$(date +%Y-%m-%d)_build-${BUILD_NUMBER}.xml'
            }
        }

        stage('Generate Traceability') {
            steps {
                sh '''
                    python3 tools/requirements/generate_traceability.py \
                        --format both \
                        --test-results test_results/jenkins/latest.xml \
                        --test-mapping test_results/requirement_test_mapping.json
                '''
            }
        }

        stage('Publish') {
            steps {
                // Publish HTML reports
                publishHTML([
                    reportDir: '.',
                    reportFiles: 'traceability_matrix.html',
                    reportName: 'Traceability Matrix'
                ])

                // Archive test results
                junit 'test_results/jenkins/latest.xml'
            }
        }
    }
}
```

### Automatic Test Discovery

For automatic test-to-requirement mapping, add markers in test code:

**Python (pytest)**:
```python
import pytest

@pytest.mark.requirement("p00001")
@pytest.mark.requirement("o00001")
def test_separate_database_per_sponsor():
    """Test that each sponsor has separate database instance."""
    # Test implementation
    assert sponsor1_db != sponsor2_db
```

**SQL Tests**:
```sql
-- TESTS REQUIREMENTS: REQ-p00004, REQ-p00013
-- Test: Audit trail immutability

BEGIN;
  -- Attempt to modify audit record (should fail)
  UPDATE record_audit SET data = '{}' WHERE audit_id = 1;
  -- This should raise an error or be silently ignored
ROLLBACK;
```

**Dart/Flutter**:
```dart
// TESTS REQUIREMENTS: REQ-p00006, REQ-d00004
test('offline data entry works without network', () {
  // Test implementation
});
```

A test discovery script can parse these markers and generate `requirement_test_mapping.json` automatically.

## Creating Test Mappings

### Manual Mapping

Edit `requirement_test_mapping.json` directly to link requirements to tests.

### Automated Mapping

Run test discovery:

```bash
# Discover test-requirement mappings from code
python3 tools/requirements/discover_test_mappings.py

# This scans all test files for requirement markers and generates:
# test_results/requirement_test_mapping.json
```

## Compliance and Validation

For FDA 21 CFR Part 11 and other compliance frameworks:

1. **Traceability Required**: Every requirement should have at least one test
2. **Coverage Report**: Traceability matrix shows untested requirements
3. **Test Evidence**: Jenkins archives test results for audit trail
4. **Version Control**: Test results committed with timestamp for history

## Example Workflow

1. **Developer writes code** implementing REQ-p00001
2. **Developer writes tests** marked with `@pytest.mark.requirement("p00001")`
3. **CI/CD runs tests** via Jenkins, generates JUnit XML
4. **Test discovery** updates requirement_test_mapping.json
5. **Traceability generator** reads test results and mapping
6. **HTML report** shows REQ-p00001 with test status ✅ (2 tests, all passed)
7. **QA reviews** traceability matrix, identifies untested requirements

## Current Status

**Status**: Not yet implemented (all requirements show as "not tested")

When tests are added:
1. Create test files with requirement markers
2. Run test discovery to generate mapping
3. Configure Jenkins to output JUnit XML
4. Regenerate traceability matrix with test results

---

**Last Updated**: 2025-10-25
**Integration Status**: Pending (test infrastructure not yet deployed)
