#!/bin/bash
# =====================================================
# Shared Project Definitions for Git Hooks
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00018: Git Hook Implementation (trigger path definitions)
#   REQ-o00043-A: Auto-trigger deployment on merge to main (scoped paths)
#
# Sourced by both pre-commit and pre-push hooks.
#
# Each entry: name|pubspec_path|trigger_paths (space-separated)
# Trigger paths include transitive dependencies so that a change
# in a dependency triggers tests and bumps in dependents.
# e.g., a change in trial_data_types/lib/ tests and bumps clinical_diary.
#
# IMPORTANT: Dependency trigger paths use lib/ and assets/ suffixes to
# avoid false version bumps from non-API changes (test/, tool/, etc.).
# Only the project's own directory uses the full path (has_code_changes
# handles own-dir filtering separately).

PROJECT_DEFS=(
    # Deployable apps
    "clinical_diary|apps/daily-diary/clinical_diary/pubspec.yaml|apps/daily-diary/clinical_diary/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-dart/append_only_datastore/lib/ apps/daily-diary/diary_functions/lib/ apps/common-flutter/eq/lib/"
    "portal-ui|apps/sponsor-portal/portal-ui/pubspec.yaml|apps/sponsor-portal/portal-ui/ apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/sponsor-portal/portal-container/ .github/workflows/build-portal-server.yml tools/build/"
    "diary_server|apps/daily-diary/diary_server/pubspec.yaml|apps/daily-diary/diary_server/ apps/daily-diary/diary_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/daily-diary/diary-server-container/ .github/workflows/build-diary-server.yml tools/build/"
    "portal_server|apps/sponsor-portal/portal_server/pubspec.yaml|apps/sponsor-portal/portal_server/ apps/sponsor-portal/portal_functions/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ database/ apps/sponsor-portal/portal-container/ apps/edc/rave-integration/lib/ .github/workflows/build-portal-server.yml tools/build/"
    # Libraries
    "trial_data_types|apps/common-dart/trial_data_types/pubspec.yaml|apps/common-dart/trial_data_types/"
    "append_only_datastore|apps/common-dart/append_only_datastore/pubspec.yaml|apps/common-dart/append_only_datastore/"
    "diary_functions|apps/daily-diary/diary_functions/pubspec.yaml|apps/daily-diary/diary_functions/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "portal_functions|apps/sponsor-portal/portal_functions/pubspec.yaml|apps/sponsor-portal/portal_functions/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "eq|apps/common-flutter/eq/pubspec.yaml|apps/common-flutter/eq/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/"
    "rave-integration|apps/edc/rave-integration/pubspec.yaml|apps/edc/rave-integration/"
)
