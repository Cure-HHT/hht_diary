# ADR-007: Multi-Sponsor Build Reports Architecture

**Date**: 2025-11-12
**Deciders**: Development Team, DevOps Team
**Compliance Impact**: High (FDA 21 CFR Part 11 traceability)

## Status

Accepted

---

## Context

The Clinical Diary platform requires comprehensive build and validation reports for:

1. **FDA Compliance**: FDA 21 CFR Part 11 requires complete traceability from requirements through testing to deployment
2. **Multi-Sponsor Architecture**: Each sponsor needs isolated reporting while maintaining shared core infrastructure
3. **Requirement Traceability**: Every code change must link to requirements (REQ-xxxxx) with validation evidence
4. **Long-Term Retention**: Reports must be archived for 7 years minimum for regulatory audits
5. **CI/CD Integration**: Automated generation during build and deployment pipelines
6. **Audit Trails**: Tamper-evident records of validation activities

**Key Challenges**:
- How do we structure reports to support both per-sponsor isolation and cross-sponsor analysis?
- Where should reports be stored (version control, artifacts, or both)?
- How do we ensure reports are tamper-evident and archived properly?
- What reports are generated vs stored in git?

**Current State**:
Before this decision, the project had ad-hoc report generation scattered across tools without a clear organizational structure or retention policy.

---

## Decision

We will use a **centralized build-reports/ directory with per-sponsor isolation** for all build and validation reports:

### Architecture

**Directory Structure**:
```
build-reports/
├── README.md              # Documentation (version controlled)
├── .gitkeep              # Ensure directory exists (version controlled)
├── templates/            # Template files for test infrastructure (version controlled)
│   ├── README.md         # Template documentation
│   ├── jenkins/          # JUnit XML format templates
│   └── requirement_test_mapping.template.json
├── combined/             # Cross-sponsor aggregated reports (generated)
│   ├── traceability/
│   ├── test-results/
│   └── validation/
├── callisto/             # Callisto sponsor reports (generated)
│   ├── traceability/
│   ├── test-results/
│   └── validation/
└── titan/                # Titan sponsor reports (generated)
    ├── traceability/
    ├── test-results/
    └── validation/
```

**Version Control Strategy**:
- **Tracked in git**: Directory structure, README files, .gitkeep files, templates/
- **NOT tracked in git**: Generated reports (`*.md`, `*.json`, `*.html` in sponsor subdirectories)
- **Reason**: Generated reports are artifacts, not source code; they would create massive commit noise

**Generation and Storage**:
1. **Local Development**: Reports generated to build-reports/ for debugging, gitignored
2. **GitHub Actions**: Reports uploaded as workflow artifacts (90-day retention)
3. **Long-Term Archive**: Reports archived to AWS S3 (7-year retention for FDA compliance)

### Report Categories

**Traceability Reports**:
- Requirement-to-code mapping (REQ-xxxxx to source files)
- Test coverage by requirement
- Compliance validation matrices
- Generated from git history and source annotations

**Test Results**:
- Unit test execution results
- Integration test results
- End-to-end test results
- Test coverage reports (line, branch, function)

**Validation Reports**:
- Spec compliance validation (spec/ directory structure)
- Git hook validation (requirement traceability in commits)
- FDA 21 CFR Part 11 compliance checks
- ALCOA+ principles validation

### Per-Sponsor Isolation

Each sponsor gets isolated report directories:
- `build-reports/{sponsor-name}/` contains only that sponsor's reports
- No cross-sponsor data leakage in reports
- Combined reports aggregate across sponsors for core platform analysis

### CI/CD Integration

Reports are generated during:
- **Pull Request Validation**: Smoke tests, validation checks
- **Main Branch Builds**: Full test suite, comprehensive traceability
- **Release Builds**: Complete validation bundle, archival package

### S3 Archival Structure

Long-term archival follows this path structure:
```
s3://clinical-diary-build-reports/
├── core/
│   └── {git-tag}/
│       └── {timestamp}/
│           ├── combined/
│           ├── callisto/
│           └── titan/
└── sponsors/
    ├── callisto/
    │   └── {git-tag}/
    └── titan/
        └── {git-tag}/
```

---

## Consequences

### Positive

✅ **Clear Organization**: Centralized location for all build reports, easy to find
✅ **Sponsor Isolation**: Each sponsor's reports completely separated
✅ **FDA Compliance**: 7-year retention in S3 meets regulatory requirements
✅ **Git Cleanliness**: Generated reports don't clutter git history
✅ **CI/CD Friendly**: Easy integration with GitHub Actions artifact upload
✅ **Flexible Access**: Recent reports in GitHub, historical in S3
✅ **Tamper Evidence**: S3 object versioning + SHA-256 checksums
✅ **Cross-Sponsor Analysis**: Combined reports enable core platform validation
✅ **Template Reuse**: Templates/ provides reference for test infrastructure

### Negative

⚠️ **Dual Storage**: Reports stored in both GitHub Actions and S3 (mitigated: different retention periods)
⚠️ **S3 Cost**: Long-term storage costs money (mitigated: Glacier storage class after 90 days)
⚠️ **Access Control**: Need to manage S3 access permissions (mitigated: IAM policies)
⚠️ **Backup Complexity**: S3 needs its own backup strategy (mitigated: S3 cross-region replication)

### Neutral

◯ **Local Report Generation**: Developers can generate reports locally for debugging
- Useful for development but must remember these are gitignored
- Documentation clearly states reports are generated artifacts

◯ **Report Format Evolution**: Report formats may change over time
- Versioning in report metadata tracks format changes
- Backward compatibility maintained for historical analysis

---

## Alternatives Considered

### Alternative 1: Store Reports in Git

**Approach**: Commit all generated reports to version control

**Pros**:
- Single source of truth
- No external storage dependency
- Easy access for all developers

**Cons**:
- ❌ Massive git repository bloat (reports include verbose test results)
- ❌ Noisy commit history (reports change frequently)
- ❌ Difficult to find actual code changes amid report updates
- ❌ Large binary files (HTML/PDF reports) don't compress well in git

**Verdict**: Rejected - fundamentally wrong approach for generated artifacts

### Alternative 2: Reports Only in CI Artifacts

**Approach**: Generate reports only in CI/CD, never store locally

**Pros**:
- No git pollution
- Centralized generation

**Cons**:
- ❌ Can't generate reports locally for debugging
- ❌ 90-day GitHub artifact retention too short for FDA compliance
- ❌ No long-term archive without additional solution

**Verdict**: Rejected - doesn't meet FDA retention requirements

### Alternative 3: Separate Reports Repository

**Approach**: Create `clinical-diary-reports` repository for all reports

**Pros**:
- Complete separation from code
- Version controlled reports

**Cons**:
- ❌ Still has git bloat problem
- ❌ Adds repository management overhead
- ❌ Harder to correlate reports with specific code versions
- ❌ Extra access control management

**Verdict**: Rejected - adds complexity without solving core problems

### Alternative 4: Database for Report Storage

**Approach**: Store reports in PostgreSQL or MongoDB

**Pros**:
- Structured queries on report data
- Efficient storage of structured data

**Cons**:
- ❌ Adds infrastructure dependency (database server)
- ❌ Reports are mostly documents (Markdown, HTML), not relational data
- ❌ Harder to archive and backup
- ❌ Less human-readable than files

**Verdict**: Rejected - overkill for document storage

### Alternative 5: No Centralized Reports Directory

**Approach**: Each tool generates reports in its own location

**Pros**:
- Tools can use their natural output locations
- No coordination needed

**Cons**:
- ❌ No single source of truth
- ❌ Difficult to find reports
- ❌ Hard to implement consistent archival
- ❌ Can't validate report completeness

**Verdict**: Rejected - chaos, not architecture

---

## Implementation Notes

### Phase 1: Directory Structure (Completed)
- Created build-reports/ directory
- Added README.md documentation
- Set up .gitignore rules
- Created sponsor subdirectories

### Phase 2: Template Infrastructure (Completed)
- Created templates/ subdirectory
- Added JUnit XML templates for test integration
- Documented template usage
- Requirement-test mapping template

### Phase 3: CI/CD Integration (In Progress)
- GitHub Actions workflow to generate reports
- Artifact upload configuration
- S3 archival automation
- Report format standardization

### Phase 4: S3 Archival (Planned)
- S3 bucket configuration
- Lifecycle policies (90 days Standard, then Glacier)
- Cross-region replication
- Access control policies

### Phase 5: Report Generation Tools (Planned)
- Traceability matrix generation script
- Test coverage aggregation
- Validation report generation
- HTML report rendering

---

## Validation Strategy

**For FDA Compliance**:

1. **Tamper Evidence**
   - Each report includes SHA-256 checksum
   - S3 object versioning enabled
   - Audit trail of who uploaded what when

2. **Retention Policy**
   - Minimum 7 years in S3
   - Automated lifecycle management
   - No manual deletions allowed

3. **Access Control**
   - S3 bucket policies enforce read-only access
   - IAM roles for CI/CD upload
   - Audit logging via CloudTrail

4. **Completeness Validation**
   - CI/CD validates all expected reports generated
   - Missing reports block merge/deployment
   - Report manifest includes checksums

5. **Traceability**
   - Reports linked to git commits via tags
   - Build metadata includes commit SHA, timestamp, builder identity
   - Requirements traceability enforced via git hooks

---

## Migration Path

**From Previous Scattered Reports**:

1. Archive any existing reports in their current locations
2. Create build-reports/ structure
3. Update CI/CD pipelines to generate to new location
4. Configure S3 bucket and archival
5. Deprecate old report locations
6. Document new access procedures

---

## Success Metrics

- ✅ All reports findable in build-reports/ or S3
- ✅ FDA audit ready: 7-year retention verified
- ✅ CI/CD generates reports on every build
- ✅ Reports include complete traceability data
- ✅ No git bloat from report files
- ✅ Developers can generate reports locally when needed
- ✅ S3 costs under budget (<$50/month estimated)

---

## References

- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application
- AWS S3 Documentation: https://docs.aws.amazon.com/s3/
- GitHub Actions Artifacts: https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts

---

**Related Requirements**:
- REQ-o00015: Build Report Generation and Archival
- REQ-o00016: Multi-Sponsor Report Isolation
- REQ-o00017: FDA-Compliant Report Retention
- REQ-d00040: Traceability Matrix Generation
- REQ-d00041: Test Coverage Reporting

**Related Documentation**:
- build-reports/README.md: Report structure and usage
- spec/ops-deployment.md: Build and deployment procedures
- spec/dev-compliance-practices.md: Compliance validation procedures

---

**Decision Date**: 2025-11-12
**Review Date**: 2026-02-12 (quarterly)
**Supersedes**: Ad-hoc report generation in various locations
