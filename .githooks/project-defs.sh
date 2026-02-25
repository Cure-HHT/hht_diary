#!/bin/bash
# =====================================================
# Shared Project Definitions for Git Hooks
# =====================================================
#
# Sourced by both pre-commit and pre-push hooks.
#
# Each entry: name|pubspec_path|trigger_paths (space-separated)
# Trigger paths include transitive dependencies so that a change
# in a dependency triggers tests and bumps in dependents.
# e.g., a change in trial_data_types tests and bumps clinical_diary.

PROJECT_DEFS=(
    # Deployable apps
    "clinical_diary|apps/daily-diary/clinical_diary/pubspec.yaml|apps/daily-diary/clinical_diary/ apps/common-dart/trial_data_types/ apps/common-dart/append_only_datastore/ apps/daily-diary/diary_functions/ apps/common-flutter/eq/"
    "portal-ui|apps/sponsor-portal/portal-ui/pubspec.yaml|apps/sponsor-portal/portal-ui/ apps/sponsor-portal/portal_functions/ apps/common-dart/trial_data_types/"
    "diary_server|apps/daily-diary/diary_server/pubspec.yaml|apps/daily-diary/diary_server/ apps/daily-diary/diary_functions/ apps/common-dart/trial_data_types/ database/"
    "portal_server|apps/sponsor-portal/portal_server/pubspec.yaml|apps/sponsor-portal/portal_server/ apps/sponsor-portal/portal_functions/ apps/common-dart/trial_data_types/ database/"
    # Libraries
    "trial_data_types|apps/common-dart/trial_data_types/pubspec.yaml|apps/common-dart/trial_data_types/"
    "append_only_datastore|apps/common-dart/append_only_datastore/pubspec.yaml|apps/common-dart/append_only_datastore/"
    "diary_functions|apps/daily-diary/diary_functions/pubspec.yaml|apps/daily-diary/diary_functions/ apps/common-dart/trial_data_types/"
    "portal_functions|apps/sponsor-portal/portal_functions/pubspec.yaml|apps/sponsor-portal/portal_functions/ apps/common-dart/trial_data_types/"
    "eq|apps/common-flutter/eq/pubspec.yaml|apps/common-flutter/eq/ apps/common-dart/trial_data_types/"
    "rave-integration|apps/edc/rave-integration/pubspec.yaml|apps/edc/rave-integration/"
)
