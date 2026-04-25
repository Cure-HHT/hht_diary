#!/bin/bash
# =====================================================
# Shared Project Definitions for Git Hooks
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00018: Git Hook Implementation (trigger path definitions)
#   REQ-o00043-A: Auto-trigger deployment on merge to main (scoped paths)
#
# Sourced by pre-commit, pre-push, and CI's validate-pr.sh.
#
# Entry format: name|pubspec_path|code_dirs|trigger_paths|version_mode
#
#   code_dirs     — own-project directories whose contents ship as part of
#                   the built artifact. Changes here produce semver+build
#                   bump (standard mode) or semver-only bump (semver-only
#                   mode). Keep narrow: lib/, bin/, assets/, web/ — NOT
#                   test/, tool/, README, CHANGELOG, or platform-native
#                   dirs that don't ship.
#
#   trigger_paths — external paths (dependencies, infra, platform-specific
#                   build inputs) that influence the built artifact without
#                   being its source. In standard mode, changes here
#                   produce a build-only bump. In semver-only mode,
#                   trigger-only changes produce no bump (the build
#                   identifier is set downstream per build, so cascades
#                   have nothing to bump). Dependency paths use lib/ and
#                   assets/ suffixes to avoid false bumps from non-API
#                   changes (test/, tool/, etc.).
#
#   version_mode  — `standard` (everything that builds locally) or
#                   `semver-only`. Standard projects carry `<semver>+N`
#                   in pubspec.yaml; the hook bumps both. Semver-only
#                   projects carry only `<semver>` (no `+N`); the build
#                   identifier is composed downstream — currently only
#                   portal-ui, whose build id is assigned by callisto's
#                   portal-final.Dockerfile (`<semver>+cb-<short_sha>`).
#
# The project's own root is intentionally NOT a trigger path. Own-dir
# source is caught by code_dirs; own-dir platform-native build inputs
# (android/, ios/) are listed explicitly in trigger_paths for the apps
# that ship them.

PROJECT_DEFS=(
    # Deployable apps
    "clinical_diary|apps/daily-diary/clinical_diary/pubspec.yaml|apps/daily-diary/clinical_diary/lib/ apps/daily-diary/clinical_diary/assets/|apps/daily-diary/clinical_diary/android/ apps/daily-diary/clinical_diary/ios/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-dart/append_only_datastore/lib/ apps/daily-diary/diary_functions/lib/ apps/common-flutter/eq/lib/|standard"
    "portal-ui|apps/sponsor-portal/portal-ui/pubspec.yaml|apps/sponsor-portal/portal-ui/lib/ apps/sponsor-portal/portal-ui/assets/ apps/sponsor-portal/portal-ui/web/|apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-flutter/common_widgets/lib/ tools/build/|semver-only"
    "diary_server|apps/daily-diary/diary_server/pubspec.yaml|apps/daily-diary/diary_server/lib/ apps/daily-diary/diary_server/bin/|apps/daily-diary/diary_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/daily-diary/diary-server-container/ tools/build/|standard"
    "portal_server|apps/sponsor-portal/portal_server/pubspec.yaml|apps/sponsor-portal/portal_server/lib/ apps/sponsor-portal/portal_server/bin/|apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/edc/rave-integration/lib/ tools/build/|standard"
    # Libraries
    "trial_data_types|apps/common-dart/trial_data_types/pubspec.yaml|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/||standard"
    "append_only_datastore|apps/common-dart/append_only_datastore/pubspec.yaml|apps/common-dart/append_only_datastore/lib/||standard"
    "diary_functions|apps/daily-diary/diary_functions/pubspec.yaml|apps/daily-diary/diary_functions/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/|standard"
    "portal_functions|apps/sponsor-portal/portal_functions/pubspec.yaml|apps/sponsor-portal/portal_functions/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/|standard"
    "eq|apps/common-flutter/eq/pubspec.yaml|apps/common-flutter/eq/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/|standard"
    "rave-integration|apps/edc/rave-integration/pubspec.yaml|apps/edc/rave-integration/lib/||standard"
)
