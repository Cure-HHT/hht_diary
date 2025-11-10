# Changelog

All notable changes to the Traceability Matrix Generator plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-30

### Added
- Initial release as independent Claude Code plugin
- Git pre-commit hook for automatic matrix generation
- Auto-regenerates traceability matrices on spec/ changes
- Integration with Python generation script (tools/requirements/generate_traceability.py)
- Markdown and HTML output formats

### Features
- **Pre-commit Hook**: Automatic regeneration on spec/ changes
- **Matrix Generation**: Creates comprehensive traceability matrices
- **Format Support**: Markdown and HTML output
- **Requirement Linking**: Shows parent-child relationships
- **Implementation Tracking**: Links requirements to code files

### References
- **Implementation**: `tools/requirements/generate_traceability.py`
- **Maintained by**: Core tooling (shared with CI/CD)

### Dependencies
- Python >=3.8
- Bash >=4.0
- Git

### Future
- Interactive HTML matrices with filtering
- Coverage analysis and gap detection
- Visual dependency graphs
- Export to compliance formats (CSV, JSON)
