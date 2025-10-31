# Changelog

All notable changes to the Spec Compliance Enforcer plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-30

### Added
- Initial release as independent Claude Code plugin
- AI-powered spec/ directory compliance enforcement
- Git pre-commit hook for automatic validation
- Validation script for spec/ directory structure
- Claude Code sub-agent for compliance analysis
- Environment validation infrastructure (future Doppler support)

### Features
- **AI Agent**: Specialized sub-agent for spec/ compliance
- **Pre-commit Hook**: Automatic validation before commits
- **Validation Script**: Manual validation tool
- **Guidelines Enforcement**: Ensures spec/README.md compliance

### Components
- **agent.md**: Claude Code sub-agent definition
- **hooks/pre-commit-spec-compliance**: Git hook integration
- **scripts/validate-spec-compliance.sh**: Validation logic
- **scripts/lib/env-validation.sh**: Environment validation (template)

### Dependencies
- Bash >=4.0
- Git
- Claude Code (for AI agent features)

### Future
- DOPPLER_READY: Prepared for Doppler secret management integration
- Enhanced validation rules and reporting
