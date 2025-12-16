// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

// ignore_for_file: unnecessary_getters_setters

import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Available font options that can be configured by sponsors.
/// These names must match the family names in pubspec.yaml.
enum FontOption {
  /// System default font (Roboto on Android, SF on iOS)
  roboto('Roboto'),

  /// OpenDyslexic font for dyslexia accessibility
  openDyslexic('OpenDyslexic'),

  /// Atkinson Hyperlegible for visual impairment accessibility
  atkinsonHyperlegible('AtkinsonHyperlegible');

  const FontOption(this.fontFamily);

  /// The font family name as used in Flutter theme
  final String fontFamily;

  /// Human-readable display name for the UI
  String get displayName {
    switch (this) {
      case FontOption.roboto:
        return 'Roboto (Default)';
      case FontOption.openDyslexic:
        return 'OpenDyslexic';
      case FontOption.atkinsonHyperlegible:
        return 'Atkinson Hyperlegible';
    }
  }

  /// Parse from server string value
  static FontOption? fromString(String value) {
    switch (value) {
      case 'Roboto':
        return FontOption.roboto;
      case 'OpenDyslexic':
        return FontOption.openDyslexic;
      case 'AtkinsonHyperlegible':
        return FontOption.atkinsonHyperlegible;
      default:
        return null;
    }
  }
}

/// Feature flag default values and constraints.
/// These are sponsor-controlled settings that are loaded at enrollment time.
/// Values are stored in memory and loaded from the server.
class FeatureFlags {
  // === Default values (used when sponsor hasn't configured) ===

  /// Default: false - skip review screen, return directly to home
  static const bool defaultUseReviewScreen = false;

  /// Default: true - animations enabled, user preference toggle visible
  static const bool defaultUseAnimations = true;

  /// REQ-CAL-p00001: Default: false - old entry justification not required
  static const bool defaultRequireOldEntryJustification = false;

  /// REQ-CAL-p00002: Default: false - short duration confirmation disabled
  static const bool defaultEnableShortDurationConfirmation = false;

  /// REQ-CAL-p00003: Default: false - long duration confirmation disabled
  static const bool defaultEnableLongDurationConfirmation = false;

  /// Default threshold for long duration confirmation (in minutes).
  static const int defaultLongDurationThresholdMinutes = 60;

  /// CUR-508: Default: false - use classic multi-page recording screen
  /// When true, uses simplified one-page recording screen
  static const bool defaultUseOnePageRecordingScreen = false;

  /// CUR-528: Default available fonts - all fonts available
  static const List<FontOption> defaultAvailableFonts = FontOption.values;

  // === Constraints ===

  /// Minimum configurable long duration threshold (1 hour)
  static const int minLongDurationThresholdHours = 1;

  /// Maximum configurable long duration threshold (9 hours)
  static const int maxLongDurationThresholdHours = 9;

  // === Known Sponsors ===

  /// List of known sponsor IDs for the dropdown
  static const List<String> knownSponsors = ['curehht', 'callisto'];
}

/// Feature flag service for sponsor-controlled settings.
/// Values are loaded from the server at enrollment time based on sponsor config.
/// Settings are stored in memory and can be modified in dev/qa builds for testing.
class FeatureFlagService {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  static FeatureFlagService get instance => _instance;

  // HTTP client for API calls (can be overridden for testing)
  http.Client? _httpClient;

  /// Set HTTP client for testing
  @visibleForTesting
  set httpClient(http.Client client) => _httpClient = client;

  http.Client get _client => _httpClient ?? http.Client();

  // In-memory storage for feature flags
  bool _useReviewScreen = FeatureFlags.defaultUseReviewScreen;
  bool _useAnimations = FeatureFlags.defaultUseAnimations;
  bool _requireOldEntryJustification =
      FeatureFlags.defaultRequireOldEntryJustification;
  bool _enableShortDurationConfirmation =
      FeatureFlags.defaultEnableShortDurationConfirmation;
  bool _enableLongDurationConfirmation =
      FeatureFlags.defaultEnableLongDurationConfirmation;
  int _longDurationThresholdMinutes =
      FeatureFlags.defaultLongDurationThresholdMinutes;
  // CUR-508: One-page recording screen flag
  bool _useOnePageRecordingScreen =
      FeatureFlags.defaultUseOnePageRecordingScreen;
  // CUR-528: Available fonts for this sponsor
  List<FontOption> _availableFonts = List.from(
    FeatureFlags.defaultAvailableFonts,
  );

  // Current sponsor ID (null if not loaded from server)
  String? _currentSponsorId;

  // Loading state
  bool _isLoading = false;
  String? _lastError;

  /// Current sponsor ID (null if using defaults)
  String? get currentSponsorId => _currentSponsorId;

  /// Whether feature flags are currently being loaded
  bool get isLoading => _isLoading;

  /// Last error message from loading (null if no error)
  String? get lastError => _lastError;

  // === UI Feature Flags ===

  /// When false (default), skip the review screen after setting end time
  /// and return directly to the home screen with a flash animation.
  /// When true, show the review/complete screen before returning.
  bool get useReviewScreen => _useReviewScreen;

  set useReviewScreen(bool value) {
    _useReviewScreen = value;
  }

  /// When true (default), animations are enabled and user preference is respected.
  /// When false, all animations are disabled and the preference toggle is hidden.
  /// This flag controls whether animations CAN be used.
  /// Actual animation display also depends on user preference.
  bool get useAnimations => _useAnimations;

  set useAnimations(bool value) {
    _useAnimations = value;
  }

  // === Validation Feature Flags ===

  /// REQ-CAL-p00001: Old Entry Modification Justification
  /// When true, editing events older than one calendar day requires
  /// selecting a justification reason before saving.
  bool get requireOldEntryJustification => _requireOldEntryJustification;

  set requireOldEntryJustification(bool value) {
    _requireOldEntryJustification = value;
  }

  /// REQ-CAL-p00002: Short Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration <= 1 minute is correct.
  bool get enableShortDurationConfirmation => _enableShortDurationConfirmation;

  set enableShortDurationConfirmation(bool value) {
    _enableShortDurationConfirmation = value;
  }

  /// REQ-CAL-p00003: Long Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration > threshold is correct.
  bool get enableLongDurationConfirmation => _enableLongDurationConfirmation;

  set enableLongDurationConfirmation(bool value) {
    _enableLongDurationConfirmation = value;
  }

  /// Long duration threshold in minutes
  int get longDurationThresholdMinutes => _longDurationThresholdMinutes;

  set longDurationThresholdMinutes(int value) {
    _longDurationThresholdMinutes = value;
  }

  /// CUR-508: One-page recording screen
  /// When true, uses simplified one-page recording screen instead of multi-page.
  /// When false (default), uses classic multi-page recording flow.
  bool get useOnePageRecordingScreen => _useOnePageRecordingScreen;

  set useOnePageRecordingScreen(bool value) {
    _useOnePageRecordingScreen = value;
  }

  /// CUR-528: Available fonts for this sponsor
  /// Controls which font options users can select in Settings.
  /// If only contains Roboto or is empty, font selector should be hidden.
  List<FontOption> get availableFonts => List.unmodifiable(_availableFonts);

  set availableFonts(List<FontOption> value) {
    _availableFonts = List.from(value);
  }

  /// CUR-528: Whether font selector should be shown in settings
  /// Returns false if only Roboto is available or list is empty
  bool get shouldShowFontSelector {
    if (_availableFonts.isEmpty) return false;
    if (_availableFonts.length == 1 &&
        _availableFonts.first == FontOption.roboto) {
      return false;
    }
    return true;
  }

  /// Load feature flags from the server for a given sponsor ID.
  /// Returns true if successful, false otherwise.
  /// Updates [lastError] with error message on failure.
  Future<bool> loadFromServer(String sponsorId) async {
    _isLoading = true;
    _lastError = null;

    try {
      debugPrint('[FeatureFlagService] Loading config for sponsor: $sponsorId');

      final response = await _client.get(
        Uri.parse(AppConfig.sponsorConfigUrl(sponsorId)),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint(
        '[FeatureFlagService] Response status: ${response.statusCode}',
      );
      debugPrint('[FeatureFlagService] Response body: ${response.body}');

      if (response.statusCode != 200) {
        _lastError = 'Server error: ${response.statusCode}';
        debugPrint('[FeatureFlagService] Error: $_lastError');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final flags = data['flags'] as Map<String, dynamic>;

      // Update in-memory values
      _useReviewScreen =
          flags['useReviewScreen'] as bool? ??
          FeatureFlags.defaultUseReviewScreen;
      _useAnimations =
          flags['useAnimations'] as bool? ?? FeatureFlags.defaultUseAnimations;
      _requireOldEntryJustification =
          flags['requireOldEntryJustification'] as bool? ??
          FeatureFlags.defaultRequireOldEntryJustification;
      _enableShortDurationConfirmation =
          flags['enableShortDurationConfirmation'] as bool? ??
          FeatureFlags.defaultEnableShortDurationConfirmation;
      _enableLongDurationConfirmation =
          flags['enableLongDurationConfirmation'] as bool? ??
          FeatureFlags.defaultEnableLongDurationConfirmation;
      _longDurationThresholdMinutes =
          flags['longDurationThresholdMinutes'] as int? ??
          FeatureFlags.defaultLongDurationThresholdMinutes;
      _useOnePageRecordingScreen =
          flags['useOnePageRecordingScreen'] as bool? ??
          FeatureFlags.defaultUseOnePageRecordingScreen;

      // CUR-528: Parse available fonts from server
      final fontsRaw = flags['availableFonts'] as List<dynamic>?;
      if (fontsRaw != null) {
        _availableFonts = fontsRaw
            .map((f) => FontOption.fromString(f as String))
            .whereType<FontOption>()
            .toList();
        // Fallback to defaults if parsing resulted in empty list
        if (_availableFonts.isEmpty) {
          _availableFonts = List.from(FeatureFlags.defaultAvailableFonts);
        }
      } else {
        _availableFonts = List.from(FeatureFlags.defaultAvailableFonts);
      }

      _currentSponsorId = sponsorId;

      debugPrint(
        '[FeatureFlagService] Successfully loaded flags for $sponsorId',
      );
      debugPrint('[FeatureFlagService] useReviewScreen: $_useReviewScreen');
      debugPrint('[FeatureFlagService] useAnimations: $_useAnimations');
      debugPrint(
        '[FeatureFlagService] requireOldEntryJustification: '
        '$_requireOldEntryJustification',
      );
      debugPrint(
        '[FeatureFlagService] enableShortDurationConfirmation: '
        '$_enableShortDurationConfirmation',
      );
      debugPrint(
        '[FeatureFlagService] enableLongDurationConfirmation: '
        '$_enableLongDurationConfirmation',
      );
      debugPrint(
        '[FeatureFlagService] longDurationThresholdMinutes: '
        '$_longDurationThresholdMinutes',
      );
      debugPrint(
        '[FeatureFlagService] useOnePageRecordingScreen: '
        '$_useOnePageRecordingScreen',
      );
      debugPrint(
        '[FeatureFlagService] availableFonts: '
        '${_availableFonts.map((f) => f.fontFamily).join(", ")}',
      );

      return true;
    } on http.ClientException catch (e) {
      _lastError = 'Network error: $e';
      debugPrint('[FeatureFlagService] Network error: $e');
      return false;
    } catch (e, stack) {
      _lastError = 'Error: $e';
      debugPrint('[FeatureFlagService] Error loading flags: $e');
      debugPrint('[FeatureFlagService] Stack: $stack');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Reset all feature flags to their defaults
  void resetToDefaults() {
    _useReviewScreen = FeatureFlags.defaultUseReviewScreen;
    _useAnimations = FeatureFlags.defaultUseAnimations;
    _requireOldEntryJustification =
        FeatureFlags.defaultRequireOldEntryJustification;
    _enableShortDurationConfirmation =
        FeatureFlags.defaultEnableShortDurationConfirmation;
    _enableLongDurationConfirmation =
        FeatureFlags.defaultEnableLongDurationConfirmation;
    _longDurationThresholdMinutes =
        FeatureFlags.defaultLongDurationThresholdMinutes;
    _useOnePageRecordingScreen = FeatureFlags.defaultUseOnePageRecordingScreen;
    _availableFonts = List.from(FeatureFlags.defaultAvailableFonts);
    _currentSponsorId = null;
    _lastError = null;
  }

  /// Initialize service (no-op now, but kept for backward compatibility)
  Future<void> initialize() async {
    // No initialization needed - flags are loaded from server on demand
  }
}
