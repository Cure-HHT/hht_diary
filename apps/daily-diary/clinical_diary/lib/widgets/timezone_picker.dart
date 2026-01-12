// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// A timezone entry with display formatting
class TimezoneEntry {
  const TimezoneEntry({
    required this.ianaId,
    required this.abbreviation,
    required this.displayName,
    required this.utcOffsetMinutes,
  });

  /// IANA timezone ID (e.g., "America/Los_Angeles") - used as unique key
  final String ianaId;

  /// Short abbreviation (e.g., "PST", "CET")
  final String abbreviation;

  /// Human-readable name (e.g., "Pacific Time")
  final String displayName;

  /// UTC offset in minutes (for sorting)
  final int utcOffsetMinutes;

  /// Format as "PST - Pacific Time"
  String get shortDisplay => '$abbreviation - $displayName';

  /// Format with UTC offset for list display
  String get formattedDisplay {
    final hours = utcOffsetMinutes.abs() ~/ 60;
    final minutes = utcOffsetMinutes.abs() % 60;
    final sign = utcOffsetMinutes >= 0 ? '+' : '-';
    final offsetStr = minutes > 0
        ? 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}'
        : 'UTC$sign$hours';
    return '$abbreviation ($offsetStr) - $displayName';
  }
}

/// Curated list of common timezones sorted by UTC offset
/// These are static values that don't require timezone package initialization
const List<TimezoneEntry> commonTimezones = [
  // UTC-12 to UTC-10
  TimezoneEntry(
    ianaId: 'Pacific/Honolulu',
    abbreviation: 'HST',
    displayName: 'Hawaii Time',
    utcOffsetMinutes: -600,
  ),
  TimezoneEntry(
    ianaId: 'America/Anchorage',
    abbreviation: 'AKST',
    displayName: 'Alaska Time',
    utcOffsetMinutes: -540,
  ),

  // UTC-8 Pacific
  TimezoneEntry(
    ianaId: 'America/Los_Angeles',
    abbreviation: 'PST',
    displayName: 'Pacific Time (US)',
    utcOffsetMinutes: -480,
  ),
  TimezoneEntry(
    ianaId: 'America/Vancouver',
    abbreviation: 'PST',
    displayName: 'Pacific Time (Canada)',
    utcOffsetMinutes: -480,
  ),
  TimezoneEntry(
    ianaId: 'America/Tijuana',
    abbreviation: 'PST',
    displayName: 'Pacific Time (Mexico)',
    utcOffsetMinutes: -480,
  ),

  // UTC-7 Mountain
  TimezoneEntry(
    ianaId: 'America/Denver',
    abbreviation: 'MST',
    displayName: 'Mountain Time (US)',
    utcOffsetMinutes: -420,
  ),
  TimezoneEntry(
    ianaId: 'America/Phoenix',
    abbreviation: 'MST',
    displayName: 'Arizona Time (No DST)',
    utcOffsetMinutes: -420,
  ),

  // UTC-6 Central
  TimezoneEntry(
    ianaId: 'America/Chicago',
    abbreviation: 'CST',
    displayName: 'Central Time (US)',
    utcOffsetMinutes: -360,
  ),
  TimezoneEntry(
    ianaId: 'America/Mexico_City',
    abbreviation: 'CST',
    displayName: 'Central Time (Mexico)',
    utcOffsetMinutes: -360,
  ),

  // UTC-5 Eastern
  TimezoneEntry(
    ianaId: 'America/New_York',
    abbreviation: 'EST',
    displayName: 'Eastern Time (US)',
    utcOffsetMinutes: -300,
  ),
  TimezoneEntry(
    ianaId: 'America/Toronto',
    abbreviation: 'EST',
    displayName: 'Eastern Time (Canada)',
    utcOffsetMinutes: -300,
  ),
  TimezoneEntry(
    ianaId: 'America/Bogota',
    abbreviation: 'COT',
    displayName: 'Colombia Time',
    utcOffsetMinutes: -300,
  ),
  TimezoneEntry(
    ianaId: 'America/Lima',
    abbreviation: 'PET',
    displayName: 'Peru Time',
    utcOffsetMinutes: -300,
  ),

  // UTC-4
  TimezoneEntry(
    ianaId: 'America/Santiago',
    abbreviation: 'CLT',
    displayName: 'Chile Time',
    utcOffsetMinutes: -240,
  ),
  TimezoneEntry(
    ianaId: 'America/Caracas',
    abbreviation: 'VET',
    displayName: 'Venezuela Time',
    utcOffsetMinutes: -240,
  ),

  // UTC-3
  TimezoneEntry(
    ianaId: 'America/Sao_Paulo',
    abbreviation: 'BRT',
    displayName: 'Brasilia Time',
    utcOffsetMinutes: -180,
  ),
  TimezoneEntry(
    ianaId: 'America/Buenos_Aires',
    abbreviation: 'ART',
    displayName: 'Argentina Time',
    utcOffsetMinutes: -180,
  ),

  // UTC+0
  TimezoneEntry(
    ianaId: 'Etc/UTC',
    abbreviation: 'UTC',
    displayName: 'Coordinated Universal Time',
    utcOffsetMinutes: 0,
  ),
  TimezoneEntry(
    ianaId: 'Europe/London',
    abbreviation: 'GMT',
    displayName: 'British Time',
    utcOffsetMinutes: 0,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Lisbon',
    abbreviation: 'WET',
    displayName: 'Western European Time',
    utcOffsetMinutes: 0,
  ),
  TimezoneEntry(
    ianaId: 'Africa/Casablanca',
    abbreviation: 'WET',
    displayName: 'Morocco Time',
    utcOffsetMinutes: 0,
  ),

  // UTC+1
  TimezoneEntry(
    ianaId: 'Europe/Paris',
    abbreviation: 'CET',
    displayName: 'Central European Time',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Berlin',
    abbreviation: 'CET',
    displayName: 'Central European (Germany)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Rome',
    abbreviation: 'CET',
    displayName: 'Central European (Italy)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Madrid',
    abbreviation: 'CET',
    displayName: 'Central European (Spain)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Amsterdam',
    abbreviation: 'CET',
    displayName: 'Central European (Netherlands)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Brussels',
    abbreviation: 'CET',
    displayName: 'Central European (Belgium)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Vienna',
    abbreviation: 'CET',
    displayName: 'Central European (Austria)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Warsaw',
    abbreviation: 'CET',
    displayName: 'Central European (Poland)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Zurich',
    abbreviation: 'CET',
    displayName: 'Central European (Switzerland)',
    utcOffsetMinutes: 60,
  ),
  TimezoneEntry(
    ianaId: 'Africa/Lagos',
    abbreviation: 'WAT',
    displayName: 'West Africa Time',
    utcOffsetMinutes: 60,
  ),

  // UTC+2
  TimezoneEntry(
    ianaId: 'Europe/Athens',
    abbreviation: 'EET',
    displayName: 'Eastern European Time',
    utcOffsetMinutes: 120,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Helsinki',
    abbreviation: 'EET',
    displayName: 'Eastern European (Finland)',
    utcOffsetMinutes: 120,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Bucharest',
    abbreviation: 'EET',
    displayName: 'Eastern European (Romania)',
    utcOffsetMinutes: 120,
  ),
  TimezoneEntry(
    ianaId: 'Africa/Cairo',
    abbreviation: 'EET',
    displayName: 'Egypt Time',
    utcOffsetMinutes: 120,
  ),
  TimezoneEntry(
    ianaId: 'Africa/Johannesburg',
    abbreviation: 'SAST',
    displayName: 'South Africa Time',
    utcOffsetMinutes: 120,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Jerusalem',
    abbreviation: 'IST',
    displayName: 'Israel Time',
    utcOffsetMinutes: 120,
  ),

  // UTC+3
  TimezoneEntry(
    ianaId: 'Europe/Moscow',
    abbreviation: 'MSK',
    displayName: 'Moscow Time',
    utcOffsetMinutes: 180,
  ),
  TimezoneEntry(
    ianaId: 'Europe/Istanbul',
    abbreviation: 'TRT',
    displayName: 'Turkey Time',
    utcOffsetMinutes: 180,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Riyadh',
    abbreviation: 'AST',
    displayName: 'Arabia Time',
    utcOffsetMinutes: 180,
  ),
  TimezoneEntry(
    ianaId: 'Africa/Nairobi',
    abbreviation: 'EAT',
    displayName: 'East Africa Time',
    utcOffsetMinutes: 180,
  ),

  // UTC+3:30
  TimezoneEntry(
    ianaId: 'Asia/Tehran',
    abbreviation: 'IRST',
    displayName: 'Iran Time',
    utcOffsetMinutes: 210,
  ),

  // UTC+4
  TimezoneEntry(
    ianaId: 'Asia/Dubai',
    abbreviation: 'GST',
    displayName: 'Gulf Time',
    utcOffsetMinutes: 240,
  ),

  // UTC+5
  TimezoneEntry(
    ianaId: 'Asia/Karachi',
    abbreviation: 'PKT',
    displayName: 'Pakistan Time',
    utcOffsetMinutes: 300,
  ),

  // UTC+5:30
  TimezoneEntry(
    ianaId: 'Asia/Kolkata',
    abbreviation: 'IST',
    displayName: 'India Time',
    utcOffsetMinutes: 330,
  ),

  // UTC+6
  TimezoneEntry(
    ianaId: 'Asia/Dhaka',
    abbreviation: 'BST',
    displayName: 'Bangladesh Time',
    utcOffsetMinutes: 360,
  ),

  // UTC+7
  TimezoneEntry(
    ianaId: 'Asia/Bangkok',
    abbreviation: 'ICT',
    displayName: 'Indochina Time',
    utcOffsetMinutes: 420,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Ho_Chi_Minh',
    abbreviation: 'ICT',
    displayName: 'Vietnam Time',
    utcOffsetMinutes: 420,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Jakarta',
    abbreviation: 'WIB',
    displayName: 'Western Indonesia Time',
    utcOffsetMinutes: 420,
  ),

  // UTC+8
  TimezoneEntry(
    ianaId: 'Asia/Shanghai',
    abbreviation: 'CST',
    displayName: 'China Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Hong_Kong',
    abbreviation: 'HKT',
    displayName: 'Hong Kong Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Singapore',
    abbreviation: 'SGT',
    displayName: 'Singapore Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Taipei',
    abbreviation: 'CST',
    displayName: 'Taiwan Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Kuala_Lumpur',
    abbreviation: 'MYT',
    displayName: 'Malaysia Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Manila',
    abbreviation: 'PHT',
    displayName: 'Philippine Time',
    utcOffsetMinutes: 480,
  ),
  TimezoneEntry(
    ianaId: 'Australia/Perth',
    abbreviation: 'AWST',
    displayName: 'Australian Western Time',
    utcOffsetMinutes: 480,
  ),

  // UTC+9
  TimezoneEntry(
    ianaId: 'Asia/Tokyo',
    abbreviation: 'JST',
    displayName: 'Japan Time',
    utcOffsetMinutes: 540,
  ),
  TimezoneEntry(
    ianaId: 'Asia/Seoul',
    abbreviation: 'KST',
    displayName: 'Korea Time',
    utcOffsetMinutes: 540,
  ),

  // UTC+9:30
  TimezoneEntry(
    ianaId: 'Australia/Darwin',
    abbreviation: 'ACST',
    displayName: 'Australian Central (Darwin)',
    utcOffsetMinutes: 570,
  ),
  TimezoneEntry(
    ianaId: 'Australia/Adelaide',
    abbreviation: 'ACST',
    displayName: 'Australian Central (Adelaide)',
    utcOffsetMinutes: 570,
  ),

  // UTC+10
  TimezoneEntry(
    ianaId: 'Australia/Sydney',
    abbreviation: 'AEST',
    displayName: 'Australian Eastern (Sydney)',
    utcOffsetMinutes: 600,
  ),
  TimezoneEntry(
    ianaId: 'Australia/Melbourne',
    abbreviation: 'AEST',
    displayName: 'Australian Eastern (Melbourne)',
    utcOffsetMinutes: 600,
  ),
  TimezoneEntry(
    ianaId: 'Australia/Brisbane',
    abbreviation: 'AEST',
    displayName: 'Australian Eastern (Brisbane)',
    utcOffsetMinutes: 600,
  ),

  // UTC+12
  TimezoneEntry(
    ianaId: 'Pacific/Auckland',
    abbreviation: 'NZST',
    displayName: 'New Zealand Time',
    utcOffsetMinutes: 720,
  ),
  TimezoneEntry(
    ianaId: 'Pacific/Fiji',
    abbreviation: 'FJT',
    displayName: 'Fiji Time',
    utcOffsetMinutes: 720,
  ),
];

/// Show timezone picker as a dialog (similar to time/date pickers)
Future<String?> showTimezonePicker({
  required BuildContext context,
  required String selectedTimezone,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _TimezonePickerDialog(selectedTimezone: selectedTimezone),
  );
}

class _TimezonePickerDialog extends StatefulWidget {
  const _TimezonePickerDialog({required this.selectedTimezone});

  final String selectedTimezone;

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<TimezoneEntry> _filteredTimezones = commonTimezones;

  @override
  void initState() {
    super.initState();
    // Scroll to the selected timezone after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    final index = commonTimezones.indexWhere(
      (tz) => tz.ianaId == widget.selectedTimezone,
    );
    if (index >= 0 && _scrollController.hasClients) {
      // Each ListTile is approximately 56 pixels (dense)
      const itemHeight = 56.0;
      final offset = (index * itemHeight) - 100; // Center it a bit
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterTimezones(String query) {
    if (query.isEmpty) {
      setState(() => _filteredTimezones = commonTimezones);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredTimezones = commonTimezones.where((tz) {
        return tz.ianaId.toLowerCase().contains(lowerQuery) ||
            tz.abbreviation.toLowerCase().contains(lowerQuery) ||
            tz.displayName.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Timezone',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search timezones...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  isDense: true,
                ),
                onChanged: _filterTimezones,
              ),
            ),

            const SizedBox(height: 8),

            // Timezone list
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: _filteredTimezones.length,
                itemBuilder: (context, index) {
                  final tz = _filteredTimezones[index];
                  final isSelected = tz.ianaId == widget.selectedTimezone;

                  return ListTile(
                    dense: true,
                    title: Text(
                      tz.shortDisplay,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      tz.ianaId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () => Navigator.pop(context, tz.ianaId),
                  );
                },
              ),
            ),

            // Cancel button
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Get display name for an IANA timezone ID from our curated list
String getTimezoneDisplayName(String ianaId) {
  final entry = commonTimezones.where((tz) => tz.ianaId == ianaId).firstOrNull;
  if (entry != null) {
    return entry.shortDisplay;
  }
  // Fallback: extract city name from IANA ID
  final parts = ianaId.split('/');
  if (parts.length >= 2) {
    return parts.last.replaceAll('_', ' ');
  }
  return ianaId;
}

/// Get abbreviation for an IANA timezone ID from our curated list
/// Returns compact abbreviation like "PST", "CET", etc.
String getTimezoneAbbreviation(String ianaId) {
  final entry = commonTimezones.where((tz) => tz.ianaId == ianaId).firstOrNull;
  if (entry != null) {
    return entry.abbreviation;
  }
  // Fallback: extract abbreviation from system timezone name if it matches
  // or just return the last part of IANA ID
  if (ianaId.length <= 5 && ianaId == ianaId.toUpperCase()) {
    // Already looks like an abbreviation (e.g., "PST", "EST")
    return ianaId;
  }
  final parts = ianaId.split('/');
  if (parts.length >= 2) {
    // Take first letters of city name as fallback
    return parts.last.substring(0, parts.last.length.clamp(0, 3)).toUpperCase();
  }
  return ianaId;
}

/// CUR-543: Map of common long-form timezone names to abbreviations.
/// These are the names returned by DateTime.now().timeZoneName on various platforms.
const Map<String, String> _longFormTimezoneMap = {
  // US timezones (Windows/macOS long names)
  'eastern standard time': 'EST',
  'eastern daylight time': 'EDT',
  'pacific standard time': 'PST',
  'pacific daylight time': 'PDT',
  'central standard time': 'CST',
  'central daylight time': 'CDT',
  'mountain standard time': 'MST',
  'mountain daylight time': 'MDT',
  'alaska standard time': 'AKST',
  'alaska daylight time': 'AKDT',
  'hawaii standard time': 'HST',
  'hawaii-aleutian standard time': 'HST',

  // European timezones
  'central european standard time': 'CET',
  'central european summer time': 'CEST',
  'greenwich mean time': 'GMT',
  'british summer time': 'BST',
  'western european time': 'WET',
  'western european summer time': 'WEST',
  'eastern european time': 'EET',
  'eastern european standard time': 'EET',
  'eastern european summer time': 'EEST',

  // Other common timezones
  'japan standard time': 'JST',
  'korea standard time': 'KST',
  'china standard time': 'CST',
  'india standard time': 'IST',
  'australian eastern standard time': 'AEST',
  'australian eastern daylight time': 'AEDT',
  'australian central standard time': 'ACST',
  'australian central daylight time': 'ACDT',
  'australian western standard time': 'AWST',
  'new zealand standard time': 'NZST',
  'new zealand daylight time': 'NZDT',
  'coordinated universal time': 'UTC',
  'singapore standard time': 'SGT',
  'hong kong standard time': 'HKT',
};

/// CUR-516: Normalize device timezone name to abbreviation for comparison.
/// Handles cases like "Central European Standard Time" -> "CET"
/// or "Pacific Standard Time" -> "PST"
/// Also handles IANA IDs like "Europe/Paris" -> "CET"
String normalizeDeviceTimezone(String deviceTzName) {
  // Handle empty string
  if (deviceTzName.isEmpty) {
    return deviceTzName;
  }

  // If already short (e.g., "PST", "CET"), return as-is
  if (deviceTzName.length <= 5 && deviceTzName == deviceTzName.toUpperCase()) {
    return deviceTzName;
  }

  // Handle IANA timezone IDs like "Europe/Paris", "America/New_York"
  // These come from TimezoneService.instance.currentTimezone
  if (deviceTzName.contains('/')) {
    return getTimezoneAbbreviation(deviceTzName);
  }

  // CUR-543: First check the long-form lookup table
  final lowerName = deviceTzName.toLowerCase();
  final mapped = _longFormTimezoneMap[lowerName];
  if (mapped != null) {
    return mapped;
  }

  // Try to find a matching entry in our timezone list
  for (final tz in commonTimezones) {
    // Check if display name is contained in the device timezone name
    // e.g., "Central European" in "Central European Standard Time"
    if (lowerName.contains(tz.displayName.toLowerCase())) {
      return tz.abbreviation;
    }
    // Check if the abbreviation is in the device timezone name
    // e.g., "PST" in "Pacific Standard Time" (unlikely but check)
    if (deviceTzName.contains(tz.abbreviation)) {
      return tz.abbreviation;
    }
    // Check if all significant words from display name are in device name
    // e.g., "Central European Time" matches "Central European Standard Time"
    // because "Central" and "European" are both present
    final displayWords = tz.displayName
        .toLowerCase()
        .split(' ')
        .where((w) => w != 'time' && w.length > 2)
        .toList();
    if (displayWords.isNotEmpty && displayWords.every(lowerName.contains)) {
      return tz.abbreviation;
    }
  }

  // Common patterns: extract first letters of each word
  // "Pacific Standard Time" -> "PST"
  // "Central European Standard Time" -> "CEST" (but we want "CET")
  final words = deviceTzName.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) {
    // Take first letter of significant words (skip "Standard", "Daylight")
    final significant = words
        .where((w) => w != 'Standard' && w != 'Daylight' && w != 'Time')
        .map((w) => w[0])
        .join();
    if (significant.isNotEmpty) {
      return significant.toUpperCase();
    }
  }

  // Last resort: return as-is
  return deviceTzName;
}
