// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/preferences_service.dart';

/// Model representing the complete exported app state.
///
/// This captures all local data for backup/restore purposes:
/// - Device UUID (self-generated identifier)
/// - Feature flags (sponsor config and settings)
/// - User preferences (theme, language, font, etc.)
/// - User timezone information
/// - Nosebleed records (full audit trail)
class AppStateExport {
  const AppStateExport({
    required this.exportVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.deviceUuid,
    required this.featureFlags,
    required this.userPreferences,
    required this.timezone,
    required this.nosebleedRecords,
  });

  /// Create from JSON
  factory AppStateExport.fromJson(Map<String, dynamic> json) {
    return AppStateExport(
      exportVersion: json['exportVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      appVersion: json['appVersion'] as String,
      deviceUuid: json['deviceUuid'] as String,
      featureFlags: FeatureFlagsExport.fromJson(
        json['featureFlags'] as Map<String, dynamic>,
      ),
      userPreferences: UserPreferencesExport.fromJson(
        json['userPreferences'] as Map<String, dynamic>,
      ),
      timezone: TimezoneExport.fromJson(
        json['timezone'] as Map<String, dynamic>,
      ),
      nosebleedRecords: (json['nosebleedRecords'] as List<dynamic>)
          .map((e) => NosebleedRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Version of the export format (for future migrations)
  final int exportVersion;

  /// When the export was created
  final DateTime exportedAt;

  /// App version at time of export
  final String appVersion;

  /// Device's self-generated UUID
  final String deviceUuid;

  /// Current feature flag settings
  final FeatureFlagsExport featureFlags;

  /// User preferences
  final UserPreferencesExport userPreferences;

  /// User's timezone information
  final TimezoneExport timezone;

  /// All nosebleed records (raw event log for full audit trail)
  final List<NosebleedRecord> nosebleedRecords;

  /// Current export format version
  static const int currentExportVersion = 1;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'exportVersion': exportVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'appVersion': appVersion,
    'deviceUuid': deviceUuid,
    'featureFlags': featureFlags.toJson(),
    'userPreferences': userPreferences.toJson(),
    'timezone': timezone.toJson(),
    'nosebleedRecords': nosebleedRecords.map((r) => r.toJson()).toList(),
  };
}

/// Exported feature flags state
class FeatureFlagsExport {
  const FeatureFlagsExport({
    required this.useReviewScreen,
    required this.useAnimations,
    required this.requireOldEntryJustification,
    required this.enableShortDurationConfirmation,
    required this.enableLongDurationConfirmation,
    required this.longDurationThresholdMinutes,
    required this.useOnePageRecordingScreen,
    required this.availableFonts,
    this.sponsorId,
  });

  /// Create from JSON
  factory FeatureFlagsExport.fromJson(Map<String, dynamic> json) {
    return FeatureFlagsExport(
      sponsorId: json['sponsorId'] as String?,
      useReviewScreen: json['useReviewScreen'] as bool,
      useAnimations: json['useAnimations'] as bool,
      requireOldEntryJustification:
          json['requireOldEntryJustification'] as bool,
      enableShortDurationConfirmation:
          json['enableShortDurationConfirmation'] as bool,
      enableLongDurationConfirmation:
          json['enableLongDurationConfirmation'] as bool,
      longDurationThresholdMinutes: json['longDurationThresholdMinutes'] as int,
      useOnePageRecordingScreen: json['useOnePageRecordingScreen'] as bool,
      availableFonts: (json['availableFonts'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Create from FeatureFlagService
  factory FeatureFlagsExport.fromService(FeatureFlagService service) {
    return FeatureFlagsExport(
      sponsorId: service.currentSponsorId,
      useReviewScreen: service.useReviewScreen,
      useAnimations: service.useAnimations,
      requireOldEntryJustification: service.requireOldEntryJustification,
      enableShortDurationConfirmation: service.enableShortDurationConfirmation,
      enableLongDurationConfirmation: service.enableLongDurationConfirmation,
      longDurationThresholdMinutes: service.longDurationThresholdMinutes,
      useOnePageRecordingScreen: service.useOnePageRecordingScreen,
      availableFonts: service.availableFonts.map((f) => f.fontFamily).toList(),
    );
  }

  final String? sponsorId;
  final bool useReviewScreen;
  final bool useAnimations;
  final bool requireOldEntryJustification;
  final bool enableShortDurationConfirmation;
  final bool enableLongDurationConfirmation;
  final int longDurationThresholdMinutes;
  final bool useOnePageRecordingScreen;
  final List<String> availableFonts;

  Map<String, dynamic> toJson() => {
    'sponsorId': sponsorId,
    'useReviewScreen': useReviewScreen,
    'useAnimations': useAnimations,
    'requireOldEntryJustification': requireOldEntryJustification,
    'enableShortDurationConfirmation': enableShortDurationConfirmation,
    'enableLongDurationConfirmation': enableLongDurationConfirmation,
    'longDurationThresholdMinutes': longDurationThresholdMinutes,
    'useOnePageRecordingScreen': useOnePageRecordingScreen,
    'availableFonts': availableFonts,
  };

  /// Apply these flags to the service
  void applyToService(FeatureFlagService service) {
    service
      ..useReviewScreen = useReviewScreen
      ..useAnimations = useAnimations
      ..requireOldEntryJustification = requireOldEntryJustification
      ..enableShortDurationConfirmation = enableShortDurationConfirmation
      ..enableLongDurationConfirmation = enableLongDurationConfirmation
      ..longDurationThresholdMinutes = longDurationThresholdMinutes
      ..useOnePageRecordingScreen = useOnePageRecordingScreen
      ..availableFonts = availableFonts
          .map(FontOption.fromString)
          .whereType<FontOption>()
          .toList();
  }
}

/// Exported user preferences
class UserPreferencesExport {
  const UserPreferencesExport({
    required this.isDarkMode,
    required this.largerTextAndControls,
    required this.useAnimation,
    required this.compactView,
    required this.languageCode,
    required this.selectedFont,
  });

  /// Create from JSON
  factory UserPreferencesExport.fromJson(Map<String, dynamic> json) {
    return UserPreferencesExport(
      isDarkMode: json['isDarkMode'] as bool,
      largerTextAndControls: json['largerTextAndControls'] as bool,
      useAnimation: json['useAnimation'] as bool,
      compactView: json['compactView'] as bool,
      languageCode: json['languageCode'] as String,
      selectedFont: json['selectedFont'] as String,
    );
  }

  /// Create from UserPreferences
  factory UserPreferencesExport.fromPreferences(UserPreferences prefs) {
    return UserPreferencesExport(
      isDarkMode: prefs.isDarkMode,
      largerTextAndControls: prefs.largerTextAndControls,
      useAnimation: prefs.useAnimation,
      compactView: prefs.compactView,
      languageCode: prefs.languageCode,
      selectedFont: prefs.selectedFont,
    );
  }

  final bool isDarkMode;
  final bool largerTextAndControls;
  final bool useAnimation;
  final bool compactView;
  final String languageCode;
  final String selectedFont;

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'largerTextAndControls': largerTextAndControls,
    'useAnimation': useAnimation,
    'compactView': compactView,
    'languageCode': languageCode,
    'selectedFont': selectedFont,
  };

  /// Convert to UserPreferences
  UserPreferences toUserPreferences() {
    return UserPreferences(
      isDarkMode: isDarkMode,
      largerTextAndControls: largerTextAndControls,
      useAnimation: useAnimation,
      compactView: compactView,
      languageCode: languageCode,
      selectedFont: selectedFont,
    );
  }
}

/// Exported timezone information
class TimezoneExport {
  const TimezoneExport({
    required this.name,
    required this.offsetHours,
    required this.offsetMinutes,
  });

  /// Create from JSON
  factory TimezoneExport.fromJson(Map<String, dynamic> json) {
    return TimezoneExport(
      name: json['name'] as String,
      offsetHours: json['offsetHours'] as int,
      offsetMinutes: json['offsetMinutes'] as int,
    );
  }

  /// Create from current system timezone
  factory TimezoneExport.fromSystem() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    return TimezoneExport(
      name: now.timeZoneName,
      offsetHours: offset.inHours,
      offsetMinutes: offset.inMinutes.remainder(60).abs(),
    );
  }

  /// Timezone name (e.g., "EST", "PST", "UTC")
  final String name;

  /// Hours offset from UTC (can be negative)
  final int offsetHours;

  /// Additional minutes offset (0-59)
  final int offsetMinutes;

  /// Get formatted offset string (e.g., "+05:30", "-08:00")
  String get formattedOffset {
    final sign = offsetHours >= 0 ? '+' : '-';
    final hours = offsetHours.abs().toString().padLeft(2, '0');
    final minutes = offsetMinutes.toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'offsetHours': offsetHours,
    'offsetMinutes': offsetMinutes,
  };
}
