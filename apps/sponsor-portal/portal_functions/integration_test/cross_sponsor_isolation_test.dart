// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Verifies: REQ-d00005 — a portal user enrolled under sponsor A
//                       cannot see sites/patients/users belonging
//                       to sponsor B.
//
// CONTEXT: Each sponsor runs in its own database (single-sponsor-per-DB
// deployment model — see CLAUDE.md §"Sponsor Isolation"). This test
// suite still exercises the *application-layer* boundary because the
// portal_functions process can run with multiple sponsor configurations
// during local development; a regression here would silently mix data
// when a developer runs the dev stack with a multi-sponsor seed.
//
// STATUS: scaffold. All cases are skip:-marked. The TODOs below name the
// exact handlers + fixture seeding that need to be wired up. The
// existing helper at integration_test/helpers/emulator_setup.dart only
// exposes per-user emulator-admin helpers (lookupByEmail, etc.) — no
// multi-sponsor fixture builder yet. A "seed two sponsors then test"
// helper is the prerequisite for this suite to run.

@TestOn('vm')
library;

import 'package:test/test.dart';

void main() {
  group('cross-sponsor isolation (REQ-d00005)', () {
    test(
      'sponsor A admin sees only sponsor A sites',
      () {
        // Wire to listSitesHandler with an authed Request carrying
        // adminId for sponsor A and assert response.body contains only
        // sites with sponsor_id == 'A'.
        //
        // Reference pattern: integration_test/sites_sync_test.dart
      },
      skip: 'scaffold — wire to listSitesHandler',
    );

    test(
      'sponsor B admin sees only sponsor B sites',
      () {
        // Same as above with sponsor B credentials.
      },
      skip: 'scaffold — wire to listSitesHandler',
    );

    test(
      "sponsor A admin cannot fetch sponsor B's patient by id",
      () {
        // Insert patient P_B with sponsor_id=B; call patient handler with
        // sponsor A admin context targeting P_B; expect 404 (not 403 — even
        // 403 leaks existence).
        //
        // Reference pattern: integration_test/patients_sync_test.dart
      },
      skip: 'scaffold — wire to patient handlers',
    );

    test(
      'patient listing returns zero for the other sponsor',
      () {
        // With a multi-sponsor seed, each side must see exactly its own count.
      },
      skip: 'scaffold — wire to patient handlers',
    );

    test(
      'email search does not return users from the other sponsor',
      () {
        // Seed shared@example.com for both sponsors; call user search with
        // sponsor A context; expect exactly one row, sponsor_id == 'A'.
        //
        // Reference pattern: integration_test/portal_user_edit_test.dart
      },
      skip: 'scaffold — wire to user search handlers',
    );

    test(
      'sponsor_role_mapping queries are scoped to active sponsor',
      () {
        // Seed role mappings for both sponsors; fetch helper with sponsor A;
        // expect zero rows for sponsor B.
        //
        // Reference pattern: integration_test/sponsor_test.dart
      },
      skip: 'scaffold — wire to sponsor role mapping helper',
    );
  });
}
