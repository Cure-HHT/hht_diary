## Phase 4: Implementation Verification

Automated tools to find, analyze, and verify implementations when requirements change.

### Quick Start

```bash
# 1. Find all implementations of a requirement:
python3 scripts/scan-implementations.py REQ-d00027

# 2. Analyze if implementations still comply (requires ANTHROPIC_API_KEY):
python3 scripts/analyze-compliance.py d00027 --auto-scan

# 3. Generate verification report:
python3 scripts/generate-report.py --from-tracking --output report.md
```

### Tools

**scan-implementations.py** - Find code implementing requirements
- Searches explicit declarations: `# Implements: REQ-xxx`
- Searches file headers (first 50 lines)
- Searches git commit history
- JSON and text output

**analyze-compliance.py** - AI-powered compliance analysis
- Analyzes if code still satisfies changed requirements
- Risk assessment (LOW/MEDIUM/HIGH)
- Actionable recommendations
- Requires: `ANTHROPIC_API_KEY` environment variable

**generate-report.py** - Create verification reports
- Markdown, HTML, and JSON formats
- Executive summary with risk breakdown
- Action items by priority
- Can generate from tracking file or analysis results

### Workflow

```bash
# After requirement changes are detected:

# 1. Scan for implementations
python3 scripts/scan-implementations.py d00027 --include-commits

# 2. Analyze compliance (with AI)
export ANTHROPIC_API_KEY="your-key"
python3 scripts/analyze-compliance.py d00027 --auto-scan --format json > analysis.json

# 3. Generate report
python3 scripts/generate-report.py --input analysis.json --output verification-report.md

# 4. Review and update code based on report

# 5. Mark as verified
python3 scripts/mark-verified.py d00027
```

### Integration

All Phase 4 tools integrate with Phase 3 tracking:
- Post-commit hook detects changes
- Tracking file maintains outdated requirements
- Verification tools process tracked changes
- mark-verified.py completes the cycle

### Requirements

- **Python**: >=3.8
- **Git**: For implementation scanning
- **anthropic**: For AI-powered analysis (optional)
  ```bash
  pip install anthropic
  ```
- **ANTHROPIC_API_KEY**: For compliance analysis

### Test Suite

```bash
cd tests/
python3 test_scan_implementations.py      # Test implementation scanner
python3 test_analyze_compliance.py        # Test compliance analyzer
```

All tests pass with/without API key (graceful degradation).
