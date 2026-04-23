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
# Entry format: name|pubspec_path|code_dirs|trigger_paths
#
#   code_dirs     — own-project directories whose contents ship as part of
#                   the built artifact. Changes here produce semver+build
#                   bump. Keep narrow: lib/, bin/, assets/, web/ — NOT
#                   test/, tool/, README, CHANGELOG, or platform-native
#                   dirs that don't ship.
#
#   trigger_paths — external paths (dependencies, infra, platform-specific
#                   build inputs) that influence the built artifact without
#                   being its source. Changes here produce a build-only
#                   bump. Dependency paths use lib/ and assets/ suffixes
#                   to avoid false bumps from non-API changes (test/,
#                   tool/, etc.).
#
# The project's own root is intentionally NOT a trigger path. Own-dir
# source is caught by code_dirs; own-dir platform-native build inputs
# (android/, ios/) are listed explicitly in trigger_paths for the apps
# that ship them.

PROJECT_DEFS=(
    # Deployable apps
    "clinical_diary|apps/daily-diary/clinical_diary/pubspec.yaml|apps/daily-diary/clinical_diary/lib/ apps/daily-diary/clinical_diary/assets/|apps/daily-diary/clinical_diary/android/ apps/daily-diary/clinical_diary/ios/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-dart/append_only_datastore/lib/ apps/daily-diary/diary_functions/lib/ apps/common-flutter/eq/lib/"
    "portal-ui|apps/sponsor-portal/portal-ui/pubspec.yaml|apps/sponsor-portal/portal-ui/lib/ apps/sponsor-portal/portal-ui/assets/ apps/sponsor-portal/portal-ui/web/|apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-flutter/common_widgets/lib/ tools/build/"
    "diary_server|apps/daily-diary/diary_server/pubspec.yaml|apps/daily-diary/diary_server/lib/ apps/daily-diary/diary_server/bin/|apps/daily-diary/diary_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/daily-diary/diary-server-container/ tools/build/"
    "portal_server|apps/sponsor-portal/portal_server/pubspec.yaml|apps/sponsor-portal/portal_server/lib/ apps/sponsor-portal/portal_server/bin/|apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/edc/rave-integration/lib/ tools/build/"
    # Libraries
    "trial_data_types|apps/common-dart/trial_data_types/pubspec.yaml|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/|"
    "append_only_datastore|apps/common-dart/append_only_datastore/pubspec.yaml|apps/common-dart/append_only_datastore/lib/|"
    "diary_functions|apps/daily-diary/diary_functions/pubspec.yaml|apps/daily-diary/diary_functions/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "portal_functions|apps/sponsor-portal/portal_functions/pubspec.yaml|apps/sponsor-portal/portal_functions/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "eq|apps/common-flutter/eq/pubspec.yaml|apps/common-flutter/eq/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "rave-integration|apps/edc/rave-integration/pubspec.yaml|apps/edc/rave-integration/lib/|"
)
