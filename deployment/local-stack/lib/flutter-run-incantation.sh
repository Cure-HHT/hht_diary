#!/usr/bin/env bash
# Prints the flutter run incantation for clinical_diary pointed at the
# local stack. Sourced by ./local-stack and the android helper.

print_flutter_run_incantation() {
  local core="$1"
  local android_host="10.0.2.2"  # host-as-seen-from-AVD

  # The EVS portal serves the diary API on :8080 (nginx). DIARY_API_BASE
  # overrides the client's default apiBase. The runtime environment itself has a
  # SINGLE source of truth: the bundled pointer assets/config/env.json (resolved
  # by EnvProfile.load). There is no APP_FLAVOR dart-define and no `local`
  # Android flavor — stamp the pointer to `local` instead.
  cat <<HINT

To point clinical_diary (Flutter app) at this stack's EVS portal:

  # Easiest — the stack stamps env=local and launches it for you:
  ./deployment/local-stack/local-stack diary           # Chrome (web)
  ./deployment/local-stack/local-stack diary-desktop   # Linux desktop

  # Manual: stamp the single env source of truth (assets/config/env.json) to
  # `local`, then run. The helper restores the pointer on exit.
  cd ${core}/apps/daily-diary/clinical_diary
  source tool/_write_env_pointer.sh local

  # Web / desktop (accesses localhost directly):
  doppler run --config dev -- flutter run -d chrome \\
      --dart-define=DIARY_API_BASE=http://localhost:8080

  # Android emulator (accesses host via 10.0.2.2; --flavor dev is the packaging
  # flavor — there is no \`local\` Android flavor):
  doppler run --config dev -- flutter run --flavor dev \\
      --dart-define=DIARY_API_BASE=http://${android_host}:8080 \\
      --dart-define=FIREBASE_AUTH_EMULATOR_HOST=${android_host}:9099

HINT
}
