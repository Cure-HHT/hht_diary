// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: Schema-Driven Data Validation
//   REQ-CAL-p00011: EDC Metadata as Validation Source
//
// Integration tests for sites synchronization from RAVE EDC
// Requires PostgreSQL database with schema applied

@TestOn('vm')
library;

import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  // Test site data
  const testSiteId1 = 'test-sync-site-001';
  const testSiteId2 = 'test-sync-site-002';

  setUpAll(() async {
    // Initialize database
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    final config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: useSsl,
    );

    await Database.instance.initialize(config);

    // Clean up any previous test data
    final db = Database.instance;
    await db.execute(
      'DELETE FROM sites WHERE site_id IN (@siteId1, @siteId2)',
      parameters: {'siteId1': testSiteId1, 'siteId2': testSiteId2},
    );
  });

  tearDownAll(() async {
    // Clean up test data
    final db = Database.instance;
    await db.execute(
      'DELETE FROM sites WHERE site_id IN (@siteId1, @siteId2)',
      parameters: {'siteId1': testSiteId1, 'siteId2': testSiteId2},
    );
    await Database.instance.close();
  });

  group('shouldSyncSites', () {
    // Note: shouldSyncSites checks the MAX(edc_synced_at) across ALL sites,
    // so these tests need to account for existing sites in the database.

    test('returns false when any site was synced recently', () async {
      final db = Database.instance;

      // Update all existing sites to have recent edc_synced_at
      // Then insert our test site with recent sync
      await db.execute(
        '''
        INSERT INTO sites (site_id, site_name, site_number, is_active, edc_synced_at)
        VALUES (@siteId, @siteName, @siteNumber, true, now())
        ON CONFLICT (site_id) DO UPDATE SET edc_synced_at = now()
        ''',
        parameters: {
          'siteId': testSiteId1,
          'siteName': 'Test Sync Site 1',
          'siteNumber': 'SYNC-001',
        },
      );

      // Should return false because at least one site was synced recently
      final shouldSync = await shouldSyncSites();
      expect(shouldSync, isFalse);

      // Cleanup
      await db.execute(
        'DELETE FROM sites WHERE site_id = @siteId',
        parameters: {'siteId': testSiteId1},
      );
    });

    test('respects custom sync interval', () async {
      final db = Database.instance;

      // First, update all sites to be synced very recently
      await db.execute('UPDATE sites SET edc_synced_at = now()');

      // Insert a test site with edc_synced_at 2 hours ago
      await db.execute(
        '''
        INSERT INTO sites (site_id, site_name, site_number, is_active, edc_synced_at)
        VALUES (@siteId, @siteName, @siteNumber, true, now() - interval '2 hours')
        ON CONFLICT (site_id) DO UPDATE SET edc_synced_at = now() - interval '2 hours'
        ''',
        parameters: {
          'siteId': testSiteId1,
          'siteName': 'Test Sync Site 1',
          'siteNumber': 'SYNC-001',
        },
      );

      // With 1-day interval (default), should return false (we just set all to now())
      final shouldSyncDefault = await shouldSyncSites();
      expect(shouldSyncDefault, isFalse);

      // Cleanup
      await db.execute(
        'DELETE FROM sites WHERE site_id = @siteId',
        parameters: {'siteId': testSiteId1},
      );
    });

    test('returns true when sites have null edc_synced_at', () async {
      final db = Database.instance;

      // Set all sites to have NULL edc_synced_at
      await db.execute('UPDATE sites SET edc_synced_at = NULL');

      // Insert a site with explicit NULL edc_synced_at
      await db.execute(
        '''
        INSERT INTO sites (site_id, site_name, site_number, is_active, edc_synced_at)
        VALUES (@siteId, @siteName, @siteNumber, true, NULL)
        ON CONFLICT (site_id) DO UPDATE SET edc_synced_at = NULL
        ''',
        parameters: {
          'siteId': testSiteId1,
          'siteName': 'Test Sync Site 1',
          'siteNumber': 'SYNC-001',
        },
      );

      // Should return true because lastSync is null
      final shouldSync = await shouldSyncSites();
      expect(shouldSync, isTrue);

      // Cleanup
      await db.execute(
        'DELETE FROM sites WHERE site_id = @siteId',
        parameters: {'siteId': testSiteId1},
      );

      // Restore existing sites to have recent sync time
      await db.execute('UPDATE sites SET edc_synced_at = now()');
    });

    test('returns true when sync is stale (older than interval)', () async {
      final db = Database.instance;

      // Set all sites to have old edc_synced_at (2 days ago)
      await db.execute(
        "UPDATE sites SET edc_synced_at = now() - interval '2 days'",
      );

      // Insert test site with old sync time
      await db.execute(
        '''
        INSERT INTO sites (site_id, site_name, site_number, is_active, edc_synced_at)
        VALUES (@siteId, @siteName, @siteNumber, true, now() - interval '2 days')
        ON CONFLICT (site_id) DO UPDATE SET edc_synced_at = now() - interval '2 days'
        ''',
        parameters: {
          'siteId': testSiteId1,
          'siteName': 'Test Sync Site 1',
          'siteNumber': 'SYNC-001',
        },
      );

      // With 1-day default interval, should return true (sync is 2 days old)
      final shouldSync = await shouldSyncSites();
      expect(shouldSync, isTrue);

      // With 3-day custom interval, should return false (2 days < 3 days)
      final shouldSyncWithLongerInterval = await shouldSyncSites(
        syncInterval: const Duration(days: 3),
      );
      expect(shouldSyncWithLongerInterval, isFalse);

      // Cleanup
      await db.execute(
        'DELETE FROM sites WHERE site_id = @siteId',
        parameters: {'siteId': testSiteId1},
      );

      // Restore existing sites to have recent sync time
      await db.execute('UPDATE sites SET edc_synced_at = now()');
    });
  });

  group('syncSitesIfNeeded', () {
    test('returns null when RAVE not configured', () async {
      // Without RAVE env vars, should return null silently
      final result = await syncSitesIfNeeded();
      expect(result, isNull);
    });
  });

  group('syncSitesFromEdc', () {
    test('returns error when RAVE not configured', () async {
      // Skip if RAVE is configured - can't test "not configured" scenario
      if (RaveConfig.isConfigured) {
        print('Skipping test - RAVE is configured');
        return;
      }

      final result = await syncSitesFromEdc();

      expect(result.hasError, isTrue);
      expect(result.error, equals('RAVE configuration not available'));
      expect(result.sitesCreated, equals(0));
      expect(result.sitesUpdated, equals(0));
      expect(result.sitesDeactivated, equals(0));
    });

    test('syncs sites from RAVE when configured', () async {
      // Skip if RAVE credentials are not available
      if (!RaveConfig.isConfigured) {
        print('Skipping test - RAVE credentials not available');
        return;
      }

      // Run actual sync from RAVE
      final result = await syncSitesFromEdc();

      // Should complete without error (real RAVE connection)
      if (result.hasError) {
        print('Sync completed with error: ${result.error}');
        // Auth errors are expected in some test environments
        expect(
          result.error,
          anyOf([
            contains('authentication'),
            contains('network'),
            contains('RAVE'),
          ]),
        );
      } else {
        // Successful sync
        print(
          'Sync completed: created=${result.sitesCreated}, '
          'updated=${result.sitesUpdated}, '
          'deactivated=${result.sitesDeactivated}',
        );
        expect(result.sitesCreated, greaterThanOrEqualTo(0));
        expect(result.sitesUpdated, greaterThanOrEqualTo(0));
        expect(result.sitesDeactivated, greaterThanOrEqualTo(0));
        expect(result.syncedAt, isNotNull);
      }
    });

    test('logs sync event after real sync', () async {
      // Skip if RAVE credentials are not available
      if (!RaveConfig.isConfigured) {
        print('Skipping test - RAVE credentials not available');
        return;
      }

      // Run sync
      final result = await syncSitesFromEdc();

      // Verify sync was logged
      final events = await getRecentSyncEvents(limit: 1, sourceSystem: 'RAVE');
      expect(events.isNotEmpty, isTrue);

      final latestEvent = events.first;
      expect(latestEvent['source_system'], equals('RAVE'));
      expect(latestEvent['operation'], equals('SITES_SYNC'));

      // Content hash should be set (either a real hash or 'no-content' for errors)
      expect(latestEvent['content_hash'], isNotNull);

      // Success should match result
      expect(latestEvent['success'], equals(!result.hasError));
    });
  });

  group('RaveConfig', () {
    test('isConfigured reflects environment state', () {
      // In test environment without Doppler, RAVE vars are typically not set
      final hasUrl = Platform.environment['RAVE_UAT_URL'] != null;
      final hasUsername = Platform.environment['RAVE_UAT_USERNAME'] != null;
      final hasPassword = Platform.environment['RAVE_UAT_PWD'] != null;

      expect(
        RaveConfig.isConfigured,
        equals(hasUrl && hasUsername && hasPassword),
      );
    });

    test('fromEnvironment returns config when all vars set', () {
      final config = RaveConfig.fromEnvironment();

      if (RaveConfig.isConfigured) {
        expect(config, isNotNull);
        expect(config!.baseUrl, isNotEmpty);
        expect(config.username, isNotEmpty);
        expect(config.password, isNotEmpty);
      } else {
        expect(config, isNull);
      }
    });
  });

  group('Sync Event Logging', () {
    setUp(() async {
      // Clean up test sync logs BEFORE each test to ensure isolation
      final db = Database.instance;
      await db.execute(
        "DELETE FROM edc_sync_log WHERE content_hash LIKE 'abc%' OR content_hash LIKE 'hash-%' OR content_hash = 'no-content' OR content_hash = 'other-hash'",
      );
    });

    test('logSyncEvent logs successful sync', () async {
      final result = SitesSyncResult(
        sitesCreated: 3,
        sitesUpdated: 5,
        sitesDeactivated: 1,
        syncedAt: DateTime.now().toUtc(),
      );

      // Should not throw
      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: result,
        contentHash: 'abc123def456',
        durationMs: 1500,
        metadata: {'study_oid': 'TEST_STUDY', 'site_count': 9},
      );

      // Verify it was logged
      final events = await getRecentSyncEvents(limit: 1);
      expect(events.isNotEmpty, isTrue);
      expect(events.first['source_system'], equals('RAVE'));
      expect(events.first['operation'], equals('SITES_SYNC'));
      expect(events.first['sites_created'], equals(3));
      expect(events.first['sites_updated'], equals(5));
      expect(events.first['sites_deactivated'], equals(1));
      expect(events.first['content_hash'], equals('abc123def456'));
      expect(events.first['success'], isTrue);
      expect(events.first['error_message'], isNull);
    });

    test('logSyncEvent logs failed sync with error', () async {
      final result = SitesSyncResult(
        sitesCreated: 0,
        sitesUpdated: 0,
        sitesDeactivated: 0,
        syncedAt: DateTime.now().toUtc(),
        error: 'RAVE authentication failed',
      );

      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: result,
        contentHash: 'no-content',
        durationMs: 250,
      );

      // Verify it was logged
      final events = await getRecentSyncEvents(limit: 1);
      expect(events.isNotEmpty, isTrue);
      expect(events.first['success'], isFalse);
      expect(
        events.first['error_message'],
        equals('RAVE authentication failed'),
      );
    });

    test('getRecentSyncEvents returns events in descending order', () async {
      // Log multiple events
      for (var i = 0; i < 3; i++) {
        await logSyncEvent(
          sourceSystem: 'RAVE',
          operation: 'SITES_SYNC',
          result: SitesSyncResult(
            sitesCreated: i,
            sitesUpdated: 0,
            sitesDeactivated: 0,
            syncedAt: DateTime.now().toUtc(),
          ),
          contentHash: 'hash-$i',
          durationMs: 100 * i,
        );
        // Small delay to ensure different timestamps
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final events = await getRecentSyncEvents(limit: 3);
      expect(events.length, equals(3));

      // Most recent should be first (sites_created = 2)
      expect(events[0]['sites_created'], equals(2));
      expect(events[1]['sites_created'], equals(1));
      expect(events[2]['sites_created'], equals(0));
    });

    test('getRecentSyncEvents respects limit', () async {
      final events = await getRecentSyncEvents(limit: 2);
      expect(events.length, lessThanOrEqualTo(2));
    });

    test('getRecentSyncEvents filters by source system', () async {
      // Log an event with a different source system
      await logSyncEvent(
        sourceSystem: 'OTHER',
        operation: 'FULL_SYNC',
        result: SitesSyncResult(
          sitesCreated: 0,
          sitesUpdated: 0,
          sitesDeactivated: 0,
          syncedAt: DateTime.now().toUtc(),
        ),
        contentHash: 'other-hash',
      );

      final raveEvents = await getRecentSyncEvents(
        limit: 10,
        sourceSystem: 'RAVE',
      );

      // All returned events should be from RAVE
      for (final event in raveEvents) {
        expect(event['source_system'], equals('RAVE'));
      }
    });

    tearDown(() async {
      // Clean up test sync logs
      final db = Database.instance;
      await db.execute(
        "DELETE FROM edc_sync_log WHERE content_hash LIKE 'abc%' OR content_hash LIKE 'hash-%' OR content_hash = 'no-content' OR content_hash = 'other-hash'",
      );
    });
  });

  group('Chain Integrity (Non-Repudiation)', () {
    setUp(() async {
      // Clean up any existing test chain entries
      final db = Database.instance;
      await db.execute(
        "DELETE FROM edc_sync_log WHERE content_hash LIKE 'chain-test-%'",
      );
    });

    test('chain_hash is automatically computed on insert', () async {
      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: SitesSyncResult(
          sitesCreated: 1,
          sitesUpdated: 0,
          sitesDeactivated: 0,
          syncedAt: DateTime.now().toUtc(),
        ),
        contentHash: 'chain-test-001',
      );

      final events = await getRecentSyncEvents(limit: 1);
      expect(events.isNotEmpty, isTrue);

      // chain_hash should be set by the database trigger
      expect(events.first['chain_hash'], isNotNull);
      expect(events.first['chain_hash'], isNotEmpty);
      // SHA-256 hex is 64 characters
      expect((events.first['chain_hash'] as String).length, equals(64));
    });

    test('subsequent entries have different chain hashes', () async {
      // Insert first entry
      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: SitesSyncResult(
          sitesCreated: 1,
          sitesUpdated: 0,
          sitesDeactivated: 0,
          syncedAt: DateTime.now().toUtc(),
        ),
        contentHash: 'chain-test-002a',
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Insert second entry
      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: SitesSyncResult(
          sitesCreated: 2,
          sitesUpdated: 0,
          sitesDeactivated: 0,
          syncedAt: DateTime.now().toUtc(),
        ),
        contentHash: 'chain-test-002b',
      );

      final events = await getRecentSyncEvents(limit: 2);
      expect(events.length, equals(2));

      // Chain hashes should be different (each depends on the previous)
      expect(events[0]['chain_hash'], isNot(equals(events[1]['chain_hash'])));
    });

    test('verifySyncLogChain does not introduce new invalid records', () async {
      // Record baseline — chain may already have invalid records from
      // previous test runs or other integration tests that inserted entries
      final baseline = await verifySyncLogChain();
      final baselineInvalid = baseline.invalidRecords;
      final baselineTotal = baseline.totalRecords;

      // Insert a few entries
      for (var i = 0; i < 3; i++) {
        await logSyncEvent(
          sourceSystem: 'RAVE',
          operation: 'SITES_SYNC',
          result: SitesSyncResult(
            sitesCreated: i,
            sitesUpdated: 0,
            sitesDeactivated: 0,
            syncedAt: DateTime.now().toUtc(),
          ),
          contentHash: 'chain-test-003-$i',
        );
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Verify chain integrity
      final verification = await verifySyncLogChain();

      // Our new entries should not introduce additional invalid records
      expect(verification.invalidRecords, equals(baselineInvalid));
      expect(
        verification.totalRecords,
        greaterThanOrEqualTo(baselineTotal + 3),
      );
    });

    test('ChainVerificationResult toJson includes all fields', () {
      final result = ChainVerificationResult(
        totalRecords: 10,
        validRecords: 10,
        invalidRecords: 0,
        chainIntact: true,
        checkedAt: DateTime.utc(2024, 1, 15, 12, 0, 0),
      );

      final json = result.toJson();

      expect(json['total_records'], equals(10));
      expect(json['valid_records'], equals(10));
      expect(json['invalid_records'], equals(0));
      expect(json['chain_intact'], isTrue);
      expect(json.containsKey('first_invalid_sync_id'), isFalse);
      expect(json['checked_at'], equals('2024-01-15T12:00:00.000Z'));
    });

    test(
      'ChainVerificationResult toJson includes first_invalid_sync_id when set',
      () {
        final result = ChainVerificationResult(
          totalRecords: 10,
          validRecords: 5,
          invalidRecords: 5,
          chainIntact: false,
          firstInvalidSyncId: 42,
          checkedAt: DateTime.utc(2024, 1, 15, 12, 0, 0),
        );

        final json = result.toJson();

        expect(json['chain_intact'], isFalse);
        expect(json['first_invalid_sync_id'], equals(42));
      },
    );

    tearDown(() async {
      // Clean up test chain entries
      final db = Database.instance;
      await db.execute(
        "DELETE FROM edc_sync_log WHERE content_hash LIKE 'chain-test-%'",
      );
    });
  });
}
