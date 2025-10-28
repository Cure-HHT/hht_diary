# Expected Warnings - Docker Development Environment

**Purpose**: Document all expected warnings to catch unexpected issues during builds.

**Last Updated**: 2025-10-28

---

## Flutter Doctor Warnings

### 1. Chrome - develop for the web (Cannot find Chrome executable)

**Warning**:
```
[✗] Chrome - develop for the web (Cannot find Chrome executable at google-chrome)
! Cannot find Chrome. Try setting CHROME_EXECUTABLE to a Chrome executable.
```

**Justification**:
- **Scope**: Mobile-first application targeting Android/iOS
- **Impact**: None - web builds not in project scope
- **Risk Level**: Low
- **Decision**: Acceptable - Chrome not needed for mobile APK builds
- **Requirements**: N/A (web deployment not in initial scope)

**When to Revisit**: If web deployment becomes a requirement

---

### 2. Linux toolchain - develop for Linux desktop

**Warning**:
```
[✗] Linux toolchain - develop for Linux desktop
✗ clang++ is required for Linux development.
✗ CMake is required for Linux development.
✗ ninja is required for Linux development.
✗ pkg-config is required for Linux development.
```

**Justification**:
- **Scope**: Mobile-first application targeting Android/iOS
- **Impact**: None - Linux desktop builds not in project scope
- **Risk Level**: Low
- **Decision**: Acceptable - Linux desktop toolchain not needed for mobile APK builds
- **Requirements**: N/A (desktop deployment not in initial scope)

**When to Revisit**: If Linux desktop deployment becomes a requirement

---

### 3. Android Studio (not installed)

**Warning**:
```
[!] Android Studio (not installed)
• Android Studio not found; download from https://developer.android.com/studio/index.html
```

**Justification**:
- **Scope**: CLI-based development environment
- **Impact**: None - Android SDK command-line tools are sufficient
- **Risk Level**: None
- **Decision**: Acceptable - Android Studio IDE not required for headless builds
- **Requirements**: Android SDK CLI tools (installed and verified)

**Verification**: `sdkmanager --list` shows all required components installed

**When to Revisit**: Never - IDE not needed in Docker environment

---

## Android SDK Warnings

### 4. Observed package id 'cmdline-tools;latest' in inconsistent location

**Warning**:
```
Warning: Observed package id 'cmdline-tools;latest' in inconsistent location
'/opt/android/cmdline-tools/latest-2' (Expected '/opt/android/cmdline-tools/latest')
```

**Justification**:
- **Scope**: Android SDK internal package management
- **Impact**: None - sdkmanager functions correctly despite warning
- **Risk Level**: None
- **Decision**: Acceptable - sdkmanager relocates packages during installation
- **Root Cause**: Android SDK's own package installation process creates versioned directories

**Verification**: All Android builds complete successfully

**When to Revisit**: If Android builds start failing

---

## npm Warnings

### 5. New major version of npm available

**Warning**:
```
npm notice New major version of npm available! 10.8.2 -> 11.6.2
npm notice To update run: npm install -g npm@11.6.2
```

**Justification**:
- **Scope**: Node.js package manager version
- **Impact**: None - npm 10.8.2 is stable and sufficient
- **Risk Level**: Low
- **Decision**: Monitor - will upgrade during scheduled maintenance window
- **FDA Compliance**: Version 10.8.2 is pinned in base image for reproducibility

**When to Revisit**: Quarterly maintenance cycle (evaluate breaking changes in npm 11)

---

## Validation Process

### Pre-Commit Checklist

Before pushing changes that modify Dockerfiles:

1. ✅ Run health checks on all images
2. ✅ Verify Flutter APK build succeeds
3. ✅ Review `flutter doctor -v` output
4. ✅ Compare warnings against this document
5. ✅ Document any NEW warnings with justification
6. ✅ Escalate unexpected warnings for review

### Build Validation Command

Run this to capture all warnings for comparison:

```bash
docker run --rm clinical-diary-dev:latest bash -c "
  flutter doctor -v 2>&1 | tee /tmp/flutter-doctor.log
  echo '=== Android SDK Warnings ==='
  sdkmanager --list 2>&1 | grep -i warning || echo 'None'
"
```

**Expected Output**: Only warnings listed in this document should appear.

---

## Escalation Criteria

**Escalate immediately if**:

1. New warning categories appear (not listed above)
2. Warnings prevent successful APK builds
3. Warnings relate to security vulnerabilities
4. Warnings indicate missing FDA compliance requirements

---

## FDA 21 CFR Part 11 Compliance Notes

All warnings in this document have been reviewed for compliance impact:

- **Reproducibility**: Version pinning addresses all reproducibility concerns
- **Audit Trail**: No warnings affect audit logging capabilities
- **Security**: No warnings introduce security vulnerabilities
- **Validation**: All critical build paths validated and documented

**Last Compliance Review**: 2025-10-28

---

## Appendix: How to Add New Expected Warnings

When a new warning appears:

1. Document the warning verbatim
2. Investigate root cause
3. Assess FDA compliance impact
4. Get approval from team lead
5. Add to this document with justification
6. Update Last Updated date
7. Commit with descriptive message

**Template**:
```markdown
### N. [Warning Category]

**Warning**:
```
[exact warning text]
```

**Justification**:
- **Scope**: [what feature/component]
- **Impact**: [none/low/medium/high]
- **Risk Level**: [none/low/medium/high]
- **Decision**: [acceptable/must-fix/monitor]
- **Requirements**: [related requirements or N/A]

**When to Revisit**: [conditions]
```
