#!/usr/bin/env bats
# Tests for ./local-stack subcommand dispatch (no side effects).
bats_require_minimum_version 1.5.0

setup() {
  CLI="$BATS_TEST_DIRNAME/../local-stack"
  # Disable commands that would touch docker/network during dispatch tests.
  export LOCAL_STACK_DRY_RUN=1
}

@test "no args prints usage on stderr and exits 1" {
  run --separate-stderr "$CLI"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"Usage:"* ]]
}

@test "--help prints usage on stdout and exits 0" {
  run --separate-stderr "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ -z "$stderr" ]
}

@test "portal dispatches to portal handler" {
  run "$CLI" portal
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_portal: dry-run"* ]]
}

@test "full-system dispatches to full-system handler" {
  run "$CLI" full-system
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_full_system: dry-run"* ]]
}

@test "down dispatches to down handler" {
  run "$CLI" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_down: dry-run keep_db=0"* ]]
}

@test "down --keep-db sets keep_db flag" {
  run "$CLI" down --keep-db
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_down: dry-run keep_db=1"* ]]
}

@test "down with unknown flag exits non-zero" {
  run --separate-stderr "$CLI" down --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"unknown flag for 'down'"* ]]
}

@test "email dispatches to email handler" {
  run "$CLI" email
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_email: dry-run"* ]]
}

@test "logs dispatches to logs handler and forwards service name" {
  run "$CLI" logs portal-final
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_logs: dry-run"* ]]
  [[ "$output" == *"portal-final"* ]]
}

@test "status dispatches to status handler" {
  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_status: dry-run"* ]]
}

@test "reset-emulator dispatches to reset-emulator handler" {
  run "$CLI" reset-emulator
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_reset_emulator: dry-run"* ]]
}

@test "rebind dispatches to rebind handler" {
  run "$CLI" rebind
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_rebind: dry-run"* ]]
}

@test "--ephemeral before a subcommand still dispatches and exports the flag" {
  run "$CLI" --ephemeral portal
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_portal: dry-run"* ]]
}

@test "--ephemeral with no subcommand prints usage and exits 1" {
  run --separate-stderr "$CLI" --ephemeral
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Usage:"* ]]
}

@test "diary dispatches to diary handler" {
  run "$CLI" diary
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary: dry-run"* ]]
}

@test "diary-desktop dispatches to diary-desktop handler" {
  run "$CLI" diary-desktop
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary_desktop: dry-run clean=0"* ]]
}

@test "diary-desktop --clean sets clean flag" {
  run "$CLI" diary-desktop --clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary_desktop: dry-run clean=1"* ]]
}

@test "diary-reset dispatches to diary-reset handler" {
  run "$CLI" diary-reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary_reset: dry-run kill_app=1 keep_keyring=0"* ]]
}

@test "diary-reset --no-kill clears kill flag" {
  run "$CLI" diary-reset --no-kill
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary_reset: dry-run kill_app=0 keep_keyring=0"* ]]
}

@test "diary-reset --keep-keyring sets keep_keyring flag" {
  run "$CLI" diary-reset --keep-keyring
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_diary_reset: dry-run kill_app=1 keep_keyring=1"* ]]
}

@test "diary-reset rejects unknown flags" {
  run "$CLI" diary-reset --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown flag"* ]]
}

@test "debug state hits GET /debug/state" {
  run "$CLI" debug state
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_debug: dry-run GET http://127.0.0.1:9876/debug/state"* ]]
}

@test "debug destinations hits GET /debug/destinations" {
  run "$CLI" debug destinations
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_debug: dry-run GET http://127.0.0.1:9876/debug/destinations"* ]]
}

@test "debug events without limit omits query string" {
  run "$CLI" debug events
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://127.0.0.1:9876/debug/events"* ]]
  [[ "$output" != *"events?"* ]]
}

@test "debug events with limit appends ?limit=" {
  run "$CLI" debug events 50
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://127.0.0.1:9876/debug/events?limit=50"* ]]
}

@test "debug aggregate without aggId fails" {
  run --separate-stderr "$CLI" debug aggregate
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"debug aggregate: missing <aggId>"* ]]
}

@test "debug aggregate with aggId hits GET /debug/aggregate/<id>" {
  run "$CLI" debug aggregate AGG-42
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://127.0.0.1:9876/debug/aggregate/AGG-42"* ]]
}

@test "debug schedule without destId fails" {
  run --separate-stderr "$CLI" debug schedule
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"debug schedule: missing <destId>"* ]]
}

@test "debug fifo with limit appends ?limit=" {
  run "$CLI" debug fifo dest-1 25
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://127.0.0.1:9876/debug/fifo/dest-1?limit=25"* ]]
}

@test "debug cursor with destId hits GET /debug/cursor/<id>" {
  run "$CLI" debug cursor dest-1
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://127.0.0.1:9876/debug/cursor/dest-1"* ]]
}

@test "debug sync uses POST /debug/sync" {
  run "$CLI" debug sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_debug: dry-run POST http://127.0.0.1:9876/debug/sync"* ]]
}

@test "debug task-sync uses POST /debug/task-sync" {
  run "$CLI" debug task-sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_debug: dry-run POST http://127.0.0.1:9876/debug/task-sync"* ]]
}

@test "debug tombstone without two args fails" {
  run --separate-stderr "$CLI" debug tombstone only-one
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"debug tombstone: missing <destId> <rowId>"* ]]
}

@test "debug tombstone uses POST /debug/tombstone-and-refill/<dest>/<row>" {
  run "$CLI" debug tombstone dest-1 row-7
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd_debug: dry-run POST http://127.0.0.1:9876/debug/tombstone-and-refill/dest-1/row-7"* ]]
}

@test "debug with no operation fails" {
  run --separate-stderr "$CLI" debug
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"debug: missing operation"* ]]
}

@test "debug with unknown operation fails" {
  run --separate-stderr "$CLI" debug bogus-op
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"unknown operation 'bogus-op'"* ]]
}

@test "DEBUG_BRIDGE_HOST and DEBUG_BRIDGE_PORT override defaults" {
  DEBUG_BRIDGE_HOST=10.0.2.2 DEBUG_BRIDGE_PORT=4242 run "$CLI" debug state
  [ "$status" -eq 0 ]
  [[ "$output" == *"GET http://10.0.2.2:4242/debug/state"* ]]
}

@test "unknown subcommand exits 1" {
  run --separate-stderr "$CLI" nonsense
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"unknown subcommand: nonsense"* ]]
}
