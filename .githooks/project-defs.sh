#!/bin/bash
# =====================================================
# Shared Project Definitions for Git Hooks
# =====================================================
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
#                   identifier is composed downstream — the EVS
#                   `portal_ui_evs`, whose build id is assigned by
#                   callisto's portal-final.Dockerfile
#                   (`<semver>+<short_sha>`). NOTE: semver-only verify
#                   rejects any `+N` in the pubspec — these stay bare.
#
# The project's own dir (lib/, bin/, assets/, web/) is caught by code_dirs.
# Own-dir platform-native build inputs (android/, ios/) are listed
# explicitly in trigger_paths for the apps that ship them. The package's
# own `pubspec.yaml` is ALSO listed as a trigger for packages with
# git-pinned deps (event_sourcing/reaction/reaction_widgets): a `ref:`
# bump is an out-of-tree dependency change that only shows up as a
# pubspec.yaml edit, so it must force a build (+N) bump — otherwise a
# library upgrade would ship under an unchanged version (gate blind spot).

# Implements: DIARY-OPS-change-appropriate-ci/A
PROJECT_DEFS=(
    # Deployable apps
    "clinical_diary|apps/daily-diary/clinical_diary/pubspec.yaml|apps/daily-diary/clinical_diary/lib/ apps/daily-diary/clinical_diary/assets/|apps/daily-diary/clinical_diary/android/ apps/daily-diary/clinical_diary/ios/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ apps/common-flutter/eq/lib/ .github/workflows/android-build.yml .github/workflows/ios-build.yml .github/versions.env|standard"
    # EVS deployables. portal_server_evs is the compiled binary built in core
    # (its +N gates the binary rebuild, see build-sponsor-ci.yml); its own
    # pubspec.yaml is a trigger so event_sourcing/reaction ref bumps force +N.
    # The binary Dockerfile is a trigger too: it controls what the image bakes
    # (server_commit, diary_app), so a change there must force a +N or the gate
    # would skip the rebuild and the change would never ship. portal_ui_evs is
    # semver-only (build id = sponsor short_sha, stamped by callisto
    # portal-final.Dockerfile) — keep it bare, no +N.
    "portal_server_evs|apps/sponsor-portal/portal_server_evs/pubspec.yaml|apps/sponsor-portal/portal_server_evs/lib/ apps/sponsor-portal/portal_server_evs/bin/|apps/sponsor-portal/portal_server_evs/pubspec.yaml apps/sponsor-portal/portal_service/lib/ apps/sponsor-portal/portal_identity/lib/ apps/common-dart/portal_actions/lib/ apps/edc/rave-integration/lib/ apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/ deployment/docker/portal-server-binary.Dockerfile tools/build/ .github/versions.env|standard"
    "portal_ui_evs|apps/sponsor-portal/portal_ui_evs/pubspec.yaml|apps/sponsor-portal/portal_ui_evs/lib/ apps/sponsor-portal/portal_ui_evs/web/ apps/sponsor-portal/portal_ui_evs/assets/|apps/sponsor-portal/portal_ui_evs/pubspec.yaml tools/build/|semver-only"
    # Libraries
    "trial_data_types|apps/common-dart/trial_data_types/pubspec.yaml|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/||standard"
    "eq|apps/common-flutter/eq/pubspec.yaml|apps/common-flutter/eq/lib/|apps/common-dart/trial_data_types/lib/ apps/common-dart/trial_data_types/assets/|standard"
    "rave-integration|apps/edc/rave-integration/pubspec.yaml|apps/edc/rave-integration/lib/||standard"
)
