# Changelog

All notable changes to the Traceability Matrix Generator plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-01-03

### Changed
- **BREAKING**: Migrated from `generate_traceability.py` to `elspais` CLI
- Now uses `elspais trace` command for matrix generation
- Updated pre-commit hook to check for elspais installation
- Updated documentation to reference elspais CLI

### Added
- Configuration via `.elspais.toml` for patterns and rules

### Dependencies
- Python >=3.9
- elspais (install with `pip install elspais`)
- Bash >=4.0
- Git

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
- **Implementation**: `elspais trace` (pip install elspais)
- **Maintained by**: Core tooling (shared with CI/CD)

### Dependencies
- Python >=3.9
- elspais
- Bash >=4.0
- Git

### Future
- Interactive HTML matrices with filtering
- Coverage analysis and gap detection
- Visual dependency graphs
- Export to compliance formats (CSV, JSON)
