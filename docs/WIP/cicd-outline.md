# CI/CD Issues Outline

## Critical Issues - Error Suppression & Silent Failures

1. **alert-workflow-changes.yml:47,49** - `|| true` masks all git/grep failures, not just "no matches"
2. **archive-artifacts.yml:35** - `continue-on-error: true` hides all download failures
3. **archive-artifacts.yml:98-99** - Circular checksum verification (downloads checksum from S3, verifies against itself)
4. **archive-audit-trail.yml:40** - Database export has NO error handling, creates empty file on failure
5. **archive-audit-trail.yml:86-88** - Integrity check doesn't verify function return value
6. **archive-deployment-logs.yml:45-49** - Silent log truncation without metadata preservation
7. **build-publish-images.yml:166,182,258,321,384** - Hard-coded "latest" tag violates FDA reproducibility
8. **build-publish-images.yml:585-589** - Build summary always shows success regardless of actual status
9. **build-test.yml:23** - `|| echo` masks ALL pip failures, not just missing requirements.txt
10. **build-test.yml:89** - `2>/dev/null` suppresses all grep errors including permission denied
11. **build-test.yml:84-100** - Broken link checker never fails build despite finding issues
12. **claim-requirement-number.yml:62-95** - Race condition allows duplicate REQ# assignments
13. **codespaces-prebuild.yml:136-138** - Summary always shows success checkmarks regardless of build results
14. **codespaces-prebuild.yml:56,86,116** - `push: always` pushes broken images even on build failure
15. **database-migration.yml:44,56,68,80,92-93** - psql continues on errors by default
16. **deploy-development.yml:73** - `supabase db reset` DESTROYS ALL DATA instead of rollback
17. **deploy-production.yml:56-72** - Fake pre-deployment checks always pass
18. **deploy-production.yml:171-189** - 15-minute "health check" does nothing, just sleeps
19. **deploy-staging.yml:89** - Uses undefined $DATABASE_URL in rollback
20. **maintenance-check.yml:54,70** - Unhandled arithmetic error when files lack git history
21. **pr-validation.yml:168,177** - Double error suppression with `2>/dev/null || true`
22. **pr-validation.yml:187-197** - Non-enforced traceability allows untraced code (FDA violation)
23. **qa-automation.yml:295,309** - `|| true` hides test failures in JSON output
24. **qa-automation.yml:299,313,330** - `continue-on-error: true` allows all tests to fail silently
25. **qa-automation.yml:407-409** - Only checks one test suite, ignores Flutter and Playwright failures
26. **requirement-verification.yml:55-62** - Pipeline error won't propagate from subshell
27. **rollback.yml:91-93** - Missing rollback script is WARNING not ERROR
28. **rollback.yml:99,115** - Success messages display even after failures
29. **validate-bot-commits.yml:31-32,52** - Git commands have no error handling
30. **verify-archive-integrity.yml:33-36** - Exits successfully when no artifacts found (masks AWS failures)

## Platform & Configuration Issues

31. **deploy-development.yml:42-43** - `brew install` on ubuntu-latest (will ALWAYS fail)
32. **deploy-production.yml:109** - `brew install` on ubuntu-latest (will ALWAYS fail)
33. **deploy-staging.yml:53** - `brew install` on ubuntu-latest (will ALWAYS fail)
34. **rollback.yml:66** - `brew install` on ubuntu-latest (will ALWAYS fail)
35. **build-publish-images.yml:94-110,175-193** - Duplicate builds in PR mode (wastes resources)
36. **archive-artifacts.yml:104-112** - Creates local log file that's never uploaded (useless)
37. **archive-artifacts.yml:114-119** - Fake notification just echoes to stdout
38. **archive-audit-trail.yml:156** - TODO comment for critical failure notification
39. **deploy-production.yml:134-137** - TODO for 7-year retention (FDA requirement unimplemented)
40. **verify-archive-integrity.yml:124** - TODO for ops team alert (critical failures unnoticed)

## Hard-Coded Values

41. **archive-artifacts.yml:75** - Hard-coded AWS region us-west-1
42. **archive-artifacts.yml:78,82,95,98** - Hard-coded S3 bucket name (4 occurrences)
43. **archive-audit-trail.yml:112** - Hard-coded AWS region us-west-1
44. **archive-audit-trail.yml:115,119,122** - Hard-coded S3 bucket paths
45. **archive-deployment-logs.yml:108** - Hard-coded AWS region us-west-1
46. **archive-deployment-logs.yml:113,117** - Hard-coded S3 bucket name
47. **build-publish-images.yml:34** - Hard-coded image prefix "clinical-diary"
48. **build-test.yml:18,54** - Hard-coded Python/Node versions
49. **claim-requirement-number.yml:78,93,105,108** - Hard-coded spec/INDEX.md path
50. **codespaces-prebuild.yml:55,85,115** - Hard-coded devcontainer paths
51. **database-migration.yml:36-42,48-54,60-66,72-78,84-90** - Environment vars repeated 5 times
52. **deploy-development.yml:32,38,88,113** - Hard-coded versions and paths
53. **deploy-production.yml:98,104,186** - Hard-coded Node/Flutter versions, sleep duration
54. **deploy-staging.yml:42,48** - Hard-coded Node/Flutter versions
55. **maintenance-check.yml:36-46** - Hard-coded file lists in workflow
56. **pr-validation.yml:291-294** - Hard-coded gitleaks version
57. **qa-automation.yml:257,357,367** - Hard-coded timeouts and retention days
58. **requirement-verification.yml:25,80,113** - Hard-coded Python version, retention, paths
59. **rollback.yml:62** - Hard-coded Node.js 20.x setup URL
60. **verify-archive-integrity.yml:23,42,109,28,56,57,113** - Hard-coded region and bucket

## Convoluted Logic & Unnecessary Complexity

61. **alert-workflow-changes.yml:46-50** - Different change detection for PR vs push
62. **archive-audit-trail.yml:99** - Decompresses entire file just to count lines
63. **archive-deployment-logs.yml:68-75** - Fragile environment determination via wildcards
64. **archive-deployment-logs.yml:61-90** - Manual JSON construction instead of jq
65. **build-publish-images.yml:198** - build-qa incorrectly depends on build-dev
66. **build-publish-images.yml:91-92,172-173,438-466** - Duplicate SBOM generation
67. **build-test.yml:59** - Uses `cd` instead of working-directory
68. **claim-requirement-number.yml:78** - Brittle string comparison for git status
69. **codespaces-prebuild.yml:30-118** - Three duplicate jobs instead of matrix strategy
70. **database-migration.yml:103** - Fragile migration number extraction with grep
71. **deploy-production.yml:46-50** - Inconsistent change detection logic
72. **maintenance-check.yml:178** - Fragile ENV pattern matching
73. **pr-validation.yml:108** - Overly permissive spec file matching pattern
74. **qa-automation.yml:138** - Fragile git diff with potentially empty ${{ github.event.before }}
75. **rollback.yml:47** - Partial version matching allows wrong rollback targets
76. **validate-bot-commits.yml:65** - String comparison works by accident with newlines
77. **verify-archive-integrity.yml:28-29,49** - Parsing AWS CLI output instead of using API

## Missing Error Handling & Validation

78. **archive-audit-trail.yml:40** - DATABASE_URL not validated before use
79. **archive-audit-trail.yml:74** - No error handling for gzip failure
80. **archive-deployment-logs.yml:42-49** - No validation that run_id exists
81. **build-publish-images.yml:136,227-228,291,354** - No verification docker load succeeded
82. **build-publish-images.yml:47-48,118,201,273,336** - No digest validation
83. **claim-requirement-number.yml:94,101-109,114** - Missing output validation
84. **database-migration.yml:33** - Package installation without error handling
85. **deploy-development.yml:54-60** - No test result artifact generation
86. **deploy-development.yml:68** - Missing --non-interactive flag for supabase link
87. **deploy-production.yml:142** - No verification supabase link succeeded
88. **deploy-production.yml:146** - Dry run errors ignored
89. **deploy-staging.yml:64-68** - Multiple test commands without set -e
90. **maintenance-check.yml:206-270** - GitHub API calls have no try/catch
91. **pr-validation.yml:53,68,75,82** - No Python script validation
92. **qa-automation.yml:275-284** - Doppler auth failures ignored
93. **requirement-verification.yml:43-44** - No validation variables are numeric
94. **rollback.yml:73,80,105** - Silent secret loading failures
95. **rollback.yml:86** - cd failure not detected
96. **validate-bot-commits.yml:26** - fetch-depth: 2 insufficient for force push
97. **verify-archive-integrity.yml:60** - Checksum filename mismatch causes all verifications to fail

## Missing Critical Features

98. **archive-audit-trail.yml:21-24** - PostgreSQL client installation has no verification
99. **build-publish-images.yml** - No vulnerability scanning before publish
100. **build-test.yml** - No timeout protection, no caching strategy
101. **claim-requirement-number.yml** - No concurrency control
102. **database-migration.yml** - Rollback scripts never tested for functionality
103. **deploy-development.yml:91-100** - Deployment log written but never persisted
104. **deploy-production.yml:119-133** - Database backup never uploaded to S3
105. **deploy-staging.yml:70-76** - Backup created but never used in rollback
106. **maintenance-check.yml** - Report never uploaded as artifact
107. **pr-validation.yml** - No retry logic for network operations
108. **qa-automation.yml:411-441** - Security scanning completely disabled
109. **requirement-verification.yml** - No cleanup of implementations.json before appending
110. **rollback.yml** - No concurrency control, no timeout protection
111. **rollback.yml:139-153** - No actual team notification mechanism
112. **verify-archive-integrity.yml** - No concurrent execution protection

## Security & Compliance Violations

113. **pr-validation.yml:187-197** - Allows PRs with untraced code (FDA 21 CFR Part 11 violation)
114. **deploy-production.yml:134-137** - 7-year retention unimplemented (FDA requirement)
115. **archive-audit-trail.yml:68-70** - Empty audit exports only warn (FDA violation)
116. **build-publish-images.yml:532,540,548,556,564** - Weak certificate identity verification
117. **rollback.yml:126** - Audit trail has placeholder instead of actual version
118. **deploy-production.yml:206** - job.duration doesn't exist (invalid audit field)
119. **validate-bot-commits.yml:38** - Bot detection bypass via "Bot:" prefix
120. **verify-archive-integrity.yml:91-102** - Invalid JSON report with undefined variables