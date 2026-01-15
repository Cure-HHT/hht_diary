// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: Schema-Driven Data Validation
//   REQ-CAL-p00011: EDC Metadata as Validation Source
//
// Sites synchronization from RAVE EDC
// Fetches sites from Medidata RAVE and syncs to local database

import 'dart:io';

import 'package:rave_integration/rave_integration.dart';

import 'database.dart';

/// Default sync interval - sites are refreshed if older than this duration.
const defaultSyncInterval = Duration(days: 1);

/// Configuration for RAVE EDC connection.
///
/// Reads from environment variables (provided via Doppler).
/// Required variables: RAVE_UAT_URL, RAVE_UAT_USERNAME, RAVE_UAT_PWD
/// Optional: RAVE_STUDY_OID (defaults to first available study)
class RaveConfig {
  final String baseUrl;
  final String username;
  final String password;
  final String? studyOid;

  RaveConfig._({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.studyOid,
  });

  /// Creates config from environment variables.
  ///
  /// Returns null if required variables are missing.
  static RaveConfig? fromEnvironment() {
    final baseUrl = Platform.environment['RAVE_UAT_URL'];
    final username = Platform.environment['RAVE_UAT_USERNAME'];
    final password = Platform.environment['RAVE_UAT_PWD'];
    final studyOid = Platform.environment['RAVE_STUDY_OID'];

    if (baseUrl == null || username == null || password == null) {
      return null;
    }

    return RaveConfig._(
      baseUrl: baseUrl,
      username: username,
      password: password,
      studyOid: studyOid,
    );
  }

  /// Whether RAVE integration is configured.
  static bool get isConfigured =>
      Platform.environment['RAVE_UAT_URL'] != null &&
      Platform.environment['RAVE_UAT_USERNAME'] != null &&
      Platform.environment['RAVE_UAT_PWD'] != null;
}

/// Result of a sites sync operation.
class SitesSyncResult {
  final int sitesUpdated;
  final int sitesCreated;
  final int sitesDeactivated;
  final DateTime syncedAt;
  final String? error;

  const SitesSyncResult({
    required this.sitesUpdated,
    required this.sitesCreated,
    required this.sitesDeactivated,
    required this.syncedAt,
    this.error,
  });

  bool get hasError => error != null;

  Map<String, dynamic> toJson() => {
    'sites_updated': sitesUpdated,
    'sites_created': sitesCreated,
    'sites_deactivated': sitesDeactivated,
    'synced_at': syncedAt.toIso8601String(),
    if (error != null) 'error': error,
  };
}

/// Checks if sites need to be synced from EDC.
///
/// Returns true if:
/// - No sites exist in the database
/// - Most recent sync is older than [syncInterval]
Future<bool> shouldSyncSites({
  Duration syncInterval = defaultSyncInterval,
}) async {
  final db = Database.instance;

  // Check if any sites exist and when they were last synced
  final result = await db.execute('''
    SELECT
      COUNT(*) as count,
      MAX(edc_synced_at) as last_sync
    FROM sites
  ''');

  if (result.isEmpty) {
    return true;
  }

  final count = result.first[0] as int;
  final lastSync = result.first[1] as DateTime?;

  // No sites - definitely sync
  if (count == 0) {
    return true;
  }

  // No sync timestamp - sync to establish baseline
  if (lastSync == null) {
    return true;
  }

  // Check if sync is stale
  final now = DateTime.now().toUtc();
  final age = now.difference(lastSync);
  return age > syncInterval;
}

/// Synchronizes sites from RAVE EDC to the local database.
///
/// This function:
/// 1. Connects to RAVE and fetches all sites for the configured study
/// 2. Upserts each site to the database
/// 3. Marks sites not in RAVE response as inactive
///
/// Returns a [SitesSyncResult] with counts of changes made.
Future<SitesSyncResult> syncSitesFromEdc() async {
  final config = RaveConfig.fromEnvironment();
  if (config == null) {
    return SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE configuration not available',
    );
  }

  final client = RaveClient(
    baseUrl: config.baseUrl,
    username: config.username,
    password: config.password,
  );

  try {
    // Fetch sites from RAVE
    final raveSites = await client.getSites(studyOid: config.studyOid);

    if (raveSites.isEmpty) {
      return SitesSyncResult(
        sitesUpdated: 0,
        sitesCreated: 0,
        sitesDeactivated: 0,
        syncedAt: DateTime.now().toUtc(),
        error: 'No sites returned from RAVE - check permissions',
      );
    }

    final db = Database.instance;
    final syncedAt = DateTime.now().toUtc();

    var created = 0;
    var updated = 0;

    // Get existing site IDs for deactivation tracking
    final existingResult = await db.execute(
      'SELECT site_id FROM sites WHERE is_active = true',
    );
    final existingSiteIds = existingResult.map((r) => r[0] as String).toSet();
    final syncedSiteIds = <String>{};

    // Upsert each site from RAVE
    for (final site in raveSites) {
      final siteId = site.oid;
      final siteName = site.name;
      final siteNumber = site.studySiteNumber ?? site.oid;
      final isActive = site.isActive;

      syncedSiteIds.add(siteId);

      // Use upsert to handle both create and update
      final upsertResult = await db.execute(
        '''
        INSERT INTO sites (
          site_id, site_name, site_number, is_active,
          edc_oid, edc_synced_at, created_at, updated_at
        )
        VALUES (
          @siteId, @siteName, @siteNumber, @isActive,
          @edcOid, @syncedAt, now(), now()
        )
        ON CONFLICT (site_id) DO UPDATE SET
          site_name = EXCLUDED.site_name,
          site_number = EXCLUDED.site_number,
          is_active = EXCLUDED.is_active,
          edc_oid = EXCLUDED.edc_oid,
          edc_synced_at = EXCLUDED.edc_synced_at,
          updated_at = now()
        RETURNING (xmax = 0) as is_insert
        ''',
        parameters: {
          'siteId': siteId,
          'siteName': siteName,
          'siteNumber': siteNumber,
          'isActive': isActive,
          'edcOid': site.oid,
          'syncedAt': syncedAt,
        },
      );

      if (upsertResult.isNotEmpty) {
        final isInsert = upsertResult.first[0] as bool;
        if (isInsert) {
          created++;
        } else {
          updated++;
        }
      }
    }

    // Deactivate sites that were not in the RAVE response
    final sitesToDeactivate = existingSiteIds.difference(syncedSiteIds);
    var deactivated = 0;

    if (sitesToDeactivate.isNotEmpty) {
      final deactivateResult = await db.execute(
        '''
        UPDATE sites
        SET is_active = false, updated_at = now(), edc_synced_at = @syncedAt
        WHERE site_id = ANY(@siteIds)
        AND is_active = true
        RETURNING site_id
        ''',
        parameters: {
          'siteIds': sitesToDeactivate.toList(),
          'syncedAt': syncedAt,
        },
      );
      deactivated = deactivateResult.length;
    }

    return SitesSyncResult(
      sitesUpdated: updated,
      sitesCreated: created,
      sitesDeactivated: deactivated,
      syncedAt: syncedAt,
    );
  } on RaveAuthenticationException {
    return SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE authentication failed - check credentials',
    );
  } on RaveNetworkException catch (e) {
    return SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE network error: ${e.message}',
    );
  } on RaveException catch (e) {
    return SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE error: ${e.message}',
    );
  } finally {
    client.close();
  }
}

/// Syncs sites if needed, based on sync interval.
///
/// This is the main entry point for the sites handler.
/// It checks if a sync is needed and performs it if so.
Future<SitesSyncResult?> syncSitesIfNeeded({
  Duration syncInterval = defaultSyncInterval,
}) async {
  if (!RaveConfig.isConfigured) {
    // RAVE not configured - skip sync silently
    return null;
  }

  final needsSync = await shouldSyncSites(syncInterval: syncInterval);
  if (!needsSync) {
    return null;
  }

  return syncSitesFromEdc();
}
