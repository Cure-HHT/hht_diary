# ANSPAR Linear Integration - Linear API Integration Plugin

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/anspar-linear-integration/ for implementation
> **Implements**: Main project REQ-d00027 (Development Environment and Tooling Setup)

---

## Executive Summary

ANSPAR Linear Integration provides comprehensive Linear API integration for requirement-ticket traceability, automated ticket creation from requirements, and project management automation with intelligent caching and environment auto-discovery.

---

### REQ-d00130: Batch Ticket Creation from Requirements

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Periodic

The plugin SHALL automate ticket creation from formal requirements in spec/ directory, parsing requirement blocks and creating Linear tickets with appropriate metadata, labels, and priority assignments, with robust API failure handling.

Implementation SHALL include:
- Requirement parsing from spec/*.md files
- Ticket creation via Linear GraphQL API
- Smart labeling based on requirement keywords
- Priority assignment: PRD=P1, Ops=P2, Dev=P3
- Duplicate detection using requirement-ticket cache
- Dry-run mode for preview before creation
- Batch processing with rate limiting (100ms delays)
- API failure handling: Retry with exponential backoff (3 attempts max)
- Partial success: Report which tickets created, which failed
- Resume capability: Re-run creates only missing tickets (idempotent)

**Rationale**: Automated ticket creation eliminates manual effort. Requirement parsing ensures consistency. Priority assignment follows criticality hierarchy. Caching prevents duplicate tickets. Failure handling ensures small teams don't manually track partial completions.

**Acceptance Criteria**:
- create-requirement-tickets.js parses spec/ directory
- Detects REQ-{type}{number} blocks in markdown
- Creates tickets with: title, description, priority, labels
- ai:new label applied to all created tickets
- Dry-run shows what would be created without API calls
- Caches requirement→ticket mappings
- API failures trigger exponential backoff retry (1s, 2s, 4s)
- Partial failures report: X created, Y failed with reasons
- Re-running script skips already-created tickets

---

### REQ-d00131: Intelligent Caching System

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL implement configurable auto-refresh caching for requirement-ticket mappings, reducing API calls while ensuring data freshness, with manual refresh capability and stale-while-revalidate strategy.

Caching system SHALL include:
- Cache file: scripts/config/requirement-ticket-cache.json
- Default cache TTL: 24 hours (configurable via LINEAR_CACHE_HOURS env var)
- Cache invalidation: Automatic on spec/ file modification
- Cache strategy: Stale-while-revalidate (use stale during refresh)
- Manual refresh via --refresh-cache flag
- Stale cache fallback if API unavailable
- Cache file gitignored (not committed)

**Rationale**: Caching reduces API calls and improves performance. Configurable TTL allows small teams to adjust based on workflow (aggressive 48h caching or frequent 4h refresh). Stale-while-revalidate maintains responsiveness. Automatic invalidation on spec/ changes ensures consistency.

**Acceptance Criteria**:
- Cache stored in scripts/config/requirement-ticket-cache.json
- Cache includes: timestamp, mappings, metadata
- Age check on every read
- TTL defaults to 24 hours, respects LINEAR_CACHE_HOURS env var
- Cache invalidates automatically when spec/ files modified
- Stale-while-revalidate: Use existing cache during background refresh
- --refresh-cache forces immediate refresh
- Stale cache used if API fails

---

### REQ-d00132: Environment Variable Auto-Discovery

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL auto-discover Linear workspace configuration including team ID resolution from API token, reducing manual configuration and enabling quick setup with minimal user input.

Auto-discovery SHALL include:
- LINEAR_API_TOKEN detection from environment
- Automatic team ID resolution via GraphQL query
- Team ID caching in .linear-config.json
- Environment validation with clear error messages
- Support for LINEAR_TEAM_ID override (optional)
- setup-env.sh helper script for initialization

**Rationale**: Auto-discovery reduces configuration burden. Team ID resolution eliminates manual lookup. Cached config speeds subsequent runs.

**Acceptance Criteria**:
- env-validation.js checks for LINEAR_API_TOKEN
- team-resolver.js queries Linear API for team ID
- Team ID cached in .linear-config.json
- Clear error if LINEAR_API_TOKEN missing
- LINEAR_TEAM_ID environment variable overrides auto-discovery
- setup-env.sh guides user through setup

---

### REQ-d00133: Subsystem Checklist Generation

**Level**: Dev | **Implements**: d00100 | **Status**: Optional | **Maintenance**: Periodic

The plugin MAY analyze ticket requirements and generate subsystem checklists showing which systems require updates (Supabase, Google Workspace, GitHub, Mobile App, Web Portal, etc.), aiding implementation planning.

Checklist generation SHALL include:
- Requirement keyword analysis
- Subsystem mapping: database→Supabase, auth→Supabase+Google, deployment→GitHub
- Checklist added to ticket description
- Security/access requirements auto-apply to all cloud services
- Markdown checklist format with checkboxes
- Dry-run mode for preview

**Rationale**: Checklists ensure all affected systems addressed. Keyword analysis automates subsystem identification. Security requirements consistently applied. For small teams: Nice-to-have feature that adds value but is not critical for core workflow. Implement if time permits.

**Acceptance Criteria**:
- add-subsystem-checklists.js analyzes ticket requirements
- Detects keywords: database, auth, deployment, security, etc.
- Generates markdown checklist with relevant subsystems
- Appends checklist to ticket description
- Security keywords trigger all cloud service checks
- Dry-run shows checklists without updating tickets

---

### REQ-d00134: Duplicate Detection and Analysis

**Level**: Dev | **Implements**: d00100 | **Status**: Optional | **Maintenance**: Periodic

The plugin MAY detect duplicate requirement-ticket mappings and provide advanced analysis of ticket relationships, preventing duplicate work and identifying potential consolidation opportunities.

Duplicate detection SHALL include:
- check-duplicates.js: finds requirement IDs in multiple tickets
- check-duplicates-advanced.js: analyzes similar titles and descriptions
- Reports showing: requirement ID, ticket IDs, ticket titles
- Warnings for potential duplicates
- Consolidation recommendations

**Rationale**: Duplicate detection prevents wasted effort. Analysis identifies consolidation opportunities. Clear reporting aids cleanup. For small teams: Nice-to-have feature that adds value but is not critical for core workflow. Focus on core requirement-ticket linking first.

**Acceptance Criteria**:
- check-duplicates.js parses all ticket descriptions
- Detects REQ-{type}{number} references
- Reports requirements referenced by multiple tickets
- check-duplicates-advanced.js compares ticket similarity
- Output includes ticket URLs for review

---

### REQ-d00135: Claude Code Integration

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Periodic

The plugin SHALL provide Claude Code agents, skills, and commands for Linear interaction within Claude Code sessions, enabling AI-assisted ticket management and requirement traceability.

Claude Code integration SHALL include:
- Agent: linear-agent.md for ticket operations
- Skills: 9 skills (fetch-tickets, create-ticket, search-tickets, etc.)
- Commands: 3 commands (/linear-fetch, /linear-search, /linear-checklist)
- SessionStart hook for environment validation
- CLAUDE_PLUGIN_ROOT path resolution
- Comprehensive agent documentation

**Rationale**: Claude Code integration enables AI-assisted workflow. Skills provide reusable operations. Commands offer quick access. SessionStart validation catches config issues early.

**Acceptance Criteria**:
- linear-agent.md documents all available operations
- 9 skills defined in skills/ directory
- 3 commands defined in commands/ directory
- All skills use ${CLAUDE_PLUGIN_ROOT} for paths
- SessionStart hook runs test-config.js
- Agent examples demonstrate common workflows

---

## References

- **Implementation**: ../plugins/anspar-linear-integration/
- **Main Project Requirement**: ../../spec/dev-requirements-management.md (REQ-d00027)
- **Marketplace Spec**: dev-marketplace.md
- **Linear API**: https://developers.linear.app/docs/graphql/working-with-the-graphql-api

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Linear Integration Plugin Maintainers
