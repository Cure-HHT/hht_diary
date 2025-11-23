/// Configuration for the append-only datastore.
///
/// This class holds all configuration needed to initialize the datastore,
/// including database paths, encryption settings, and sync endpoints.
class DatastoreConfig {
  /// Path to the SQLite database file.
  /// If null, uses default application documents directory.
  final String? databasePath;

  /// Name of the database file.
  final String databaseName;

  /// Enable SQLCipher encryption.
  /// WARNING: Must be false for Phase 1 MVP.
  final bool enableEncryption;

  /// Encryption key for SQLCipher.
  /// Only used if [enableEncryption] is true.
  final String? encryptionKey;

  /// User ID for audit trail.
  /// Must be set before appending events.
  final String? userId;

  /// Device ID for conflict resolution.
  /// Automatically generated if not provided.
  final String deviceId;

  /// Base URL for sync server API.
  /// Example: 'https://api.example.com/v1'
  final String? syncServerUrl;

  /// Enable OpenTelemetry tracing.
  final bool enableTelemetry;

  /// OpenTelemetry endpoint.
  /// Only used if [enableTelemetry] is true.
  final String? telemetryEndpoint;

  const DatastoreConfig({
    this.databasePath,
    this.databaseName = 'clinical_events.db',
    this.enableEncryption = false,
    this.encryptionKey,
    this.userId,
    required this.deviceId,
    this.syncServerUrl,
    this.enableTelemetry = false,
    this.telemetryEndpoint,
  }) : assert(
          !enableEncryption || encryptionKey != null,
          'encryptionKey must be provided when encryption is enabled',
        );

  /// Create a development configuration with sensible defaults.
  factory DatastoreConfig.development({
    required String deviceId,
    String? userId,
  }) {
    return DatastoreConfig(
      deviceId: deviceId,
      userId: userId,
      databaseName: 'clinical_events_dev.db',
      enableTelemetry: true,
    );
  }

  /// Create a production configuration.
  factory DatastoreConfig.production({
    required String deviceId,
    required String userId,
    required String syncServerUrl,
    String? encryptionKey,
  }) {
    return DatastoreConfig(
      deviceId: deviceId,
      userId: userId,
      syncServerUrl: syncServerUrl,
      enableEncryption: encryptionKey != null,
      encryptionKey: encryptionKey,
      enableTelemetry: true,
    );
  }

  /// Copy with new values.
  DatastoreConfig copyWith({
    String? databasePath,
    String? databaseName,
    bool? enableEncryption,
    String? encryptionKey,
    String? userId,
    String? deviceId,
    String? syncServerUrl,
    bool? enableTelemetry,
    String? telemetryEndpoint,
  }) {
    return DatastoreConfig(
      databasePath: databasePath ?? this.databasePath,
      databaseName: databaseName ?? this.databaseName,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      syncServerUrl: syncServerUrl ?? this.syncServerUrl,
      enableTelemetry: enableTelemetry ?? this.enableTelemetry,
      telemetryEndpoint: telemetryEndpoint ?? this.telemetryEndpoint,
    );
  }
}
