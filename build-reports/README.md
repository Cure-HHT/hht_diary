# Build Reports

This directory contains auto-generated build and validation reports for the Clinical Trial Diary Platform. All files in this directory are produced by automated CI/CD pipelines and should not be manually edited.

## Directory Structure

```
build-reports/
├── templates/          # Template files showing expected format for test results
│   ├── README.md       # Documentation for template usage
│   ├── jenkins/        # JUnit XML format templates
│   └── requirement_test_mapping.template.json
├── combined/           # Aggregated reports across all sponsors
│   ├── traceability/   # Requirement-to-code traceability reports
│   ├── test-results/   # Combined test execution results
│   └── validation/     # Cross-sponsor validation reports
├── callisto/           # Callisto sponsor-specific reports
│   ├── traceability/   # Callisto requirement traceability
│   ├── test-results/   # Callisto test execution results
│   └── validation/     # Callisto validation reports
└── titan/              # Titan sponsor-specific reports
    ├── traceability/   # Titan requirement traceability
    ├── test-results/   # Titan test execution results
    └── validation/     # Titan validation reports
```

## Report Categories

### Templates
The `templates/` subdirectory contains reference templates showing the expected format for test results and requirement-test mappings. These are NOT actual test results, but serve as:
- Documentation of expected file formats (JUnit XML, requirement-test mappings)
- Starting point for implementing test infrastructure
- Reference for CI/CD pipeline configuration

See `templates/README.md` for detailed documentation on template usage and test integration.

### Traceability Reports
- Requirement-to-code mapping (REQ-xxxxx to source files)
- Test coverage by requirement
- Compliance validation matrices
- Generated from git history, source annotations, and requirement index

### Test Results
- Unit test execution results
- Integration test results
- End-to-end test results
- Test coverage reports (line, branch, function coverage)

### Validation Reports
- Spec compliance validation (spec/ directory structure and content)
- Git hook validation (requirement traceability in commits)
- FDA 21 CFR Part 11 compliance checks
- ALCOA+ principles validation

## CI/CD Integration

Reports are generated automatically during:
- Pull request validation (smoke tests, validation checks)
- Main branch builds (full test suite, comprehensive traceability)
- Release builds (complete validation bundle, archival package)

Generated artifacts are:
1. Uploaded to GitHub Actions as workflow artifacts (90-day retention)
2. Archived to AWS S3 for long-term storage (7-year retention for FDA compliance)
3. Referenced in release notes and compliance documentation

## FDA Compliance and Retention

Per FDA 21 CFR Part 11 requirements, all build and validation reports are:
- Retained for a minimum of 7 years
- Stored with tamper-evident integrity (SHA-256 checksums)
- Include audit trails linking to source code commits
- Part of the validated system documentation package

## Manual Access

To access historical reports:
- **Recent builds**: GitHub Actions workflow artifacts (last 90 days)
- **Historical builds**: AWS S3 archive (contact DevOps for access)
- **Local generation**: Run validation scripts in `tools/requirements/` directory

## Notes

- All files under `build-reports/` (except this README and .gitkeep files) are excluded from version control
- Local report generation is supported for development and debugging purposes
- Report formats: JSON (machine-readable), HTML (human-readable), Markdown (documentation)
