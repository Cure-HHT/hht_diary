#!/usr/bin/env bash
# Prints the flutter run incantation for clinical_diary pointed at the
# local stack. Sourced by ./local-stack and the android helper.

print_flutter_run_incantation() {
  local core="$1"
  local android_host="10.0.2.2"  # host-as-seen-from-AVD

  # The EVS portal serves the diary API on :8080 (nginx). The client's `local`
  # flavor defaults apiBase to :8084, so we override it via DIARY_API_BASE.
  cat <<HINT

To point clinical_diary (Flutter app) at this stack's EVS portal:

  cd ${core}/apps/daily-diary/clinical_diary

  # Web / desktop (accesses localhost directly):
  doppler run --config dev -- flutter run -d chrome \\
      --dart-define=APP_FLAVOR=local \\
      --dart-define=DIARY_API_BASE=http://localhost:8080

  # Android emulator (accesses host via 10.0.2.2):
  doppler run --config dev -- flutter run \\
      --flavor local \\
      --dart-define=APP_FLAVOR=local \\
      --dart-define=DIARY_API_BASE=http://${android_host}:8080 \\
      --dart-define=FIREBASE_AUTH_EMULATOR_HOST=${android_host}:9099

HINT
}
