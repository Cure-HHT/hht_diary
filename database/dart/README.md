# Flutter/Dart Data Models

This directory contains the Dart data models for the Clinical Trial Diary application.

## Files

- **models.dart**: Complete data model definitions matching the database JSONB schema
- **diary_repository.dart**: Database operations using Event Sourcing pattern
- **event_deletion_handler.dart**: Deletion logic with user prompting
- **deletion_models.dart**: Supporting types for deletion operations
- **ui_example.dart**: Example Flutter widgets showing UI integration
- **diary.tsx**: Original TypeScript reference (kept for comparison)

## Usage

### Adding to Your Flutter Project

```dart
// Copy models.dart to your Flutter project:
// lib/models/diary_models.dart

import 'package:your_app/models/diary_models.dart';
```

### Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  uuid: ^4.0.0              # For UUID generation
  supabase_flutter: ^2.0.0  # For database operations
```

## Examples

### Creating a Nosebleed Event

```dart
// Standard nosebleed event
final nosebleed = EpistaxisRecord.createNosebleed(
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(minutes: 15)),
  intensity: EpistaxisIntensity.drippingQuickly,
  userNotes: 'Occurred during exercise',
);

// Create EventRecord wrapper
final event = EventRecord(
  id: nosebleed.id,
  versionedType: 'epistaxis-v1.0',
  eventData: nosebleed,
);

// Convert to JSON for database storage
final json = event.toJson();
```

### Creating a "No Nosebleeds" Event

```dart
final noNosebleeds = EpistaxisRecord.createNoNosebleeds(
  date: DateTime.now(),
  userNotes: 'Felt fine all day',
);

final event = createEventRecord(noNosebleeds);
```

### Creating an Incomplete Entry

```dart
// User starts recording but doesn't finish
final incomplete = EpistaxisRecord.createNosebleed(
  startTime: DateTime.now(),
  isIncomplete: true,
);

// Later, user completes the entry
final completed = incomplete.copyWith(
  endTime: DateTime.now().add(Duration(minutes: 20)),
  intensity: EpistaxisIntensity.drippingSlowly,
  isIncomplete: false,
);
```

### Creating a Survey

```dart
final survey = SurveyRecord.create(
  survey: [
    SurveyQuestion(
      questionId: 'q1_frequency',
      questionText: 'How many nosebleeds in the past week?',
      response: 3,
    ),
    SurveyQuestion(
      questionId: 'q2_impact',
      questionText: 'Impact on daily activities?',
      response: 'moderate',
    ),
    SurveyQuestion(
      questionId: 'q3_optional',
      questionText: 'Any additional symptoms?',
      skipped: true,
    ),
  ],
  score: SurveyScore(
    total: 42,
    subscales: {
      'frequency': 15,
      'impact': 18,
      'treatment': 9,
    },
    rubricVersion: 'v1.2',
  ),
);

final event = createEventRecord(survey);
```

### Storing in Supabase

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> saveEvent(EventRecord event, String userId, String siteId) async {
  final supabase = Supabase.instance.client;

  // Insert into record_audit table
  await supabase.from('record_audit').insert({
    'event_uuid': event.id,
    'patient_id': userId,
    'site_id': siteId,
    'operation': 'USER_CREATE',
    'data': event.toJson(),
    'created_by': userId,
    'role': 'USER',
    'client_timestamp': DateTime.now().toIso8601String(),
    'change_reason': 'Initial entry',
  });
}
```

### Loading from Database

```dart
Future<EventRecord> loadEvent(String eventUuid) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('record_state')
      .select('current_data')
      .eq('event_uuid', eventUuid)
      .single();

  return EventRecord.fromJson(response['current_data']);
}
```

## Validation

The models include client-side validation:

```dart
try {
  // This will throw an error - mutual exclusivity violation
  final invalid = EpistaxisRecord(
    id: EventRecord.generateUuid(),
    startTime: DateTime.now(),
    isNoNosebleedsEvent: true,
    isUnknownNosebleedsEvent: true,  // ❌ Cannot both be true
    lastModified: DateTime.now(),
  );
} catch (e) {
  print('Validation error: $e');
}

try {
  // This will throw an error - intensity not allowed for special events
  final invalid = EpistaxisRecord(
    id: EventRecord.generateUuid(),
    startTime: DateTime.now(),
    isNoNosebleedsEvent: true,
    intensity: EpistaxisIntensity.drippingQuickly,  // ❌ Not allowed
    lastModified: DateTime.now(),
  );
} catch (e) {
  print('Validation error: $e');
}
```

## Schema Versions

Current versions:
- **epistaxis-v1.0**: Nosebleed events
- **survey-v1.0**: Survey responses

When schema versions change:
1. Update `versionedType` string in EventRecord
2. Add new validator in database (see `database/schema.sql`)
3. Application must handle multiple versions during reads
4. New writes should use latest version

## Compliance Notes

### ALCOA+ Principles

- **Attributable**: UUID links to user via database audit trail
- **Legible**: Meaningful enum strings (not numbers)
- **Contemporaneous**: `lastModified` tracks when data entered
- **Original**: Complete data structure preserved
- **Accurate**: Client-side and database validation

### Enum Values

Always use meaningful strings:

```dart
// ✅ Correct
intensity: EpistaxisIntensity.drippingQuickly  // Stores as "dripping_quickly"

// ❌ Wrong (from old design)
intensity: 2  // Numbers are not allowed
```

### Timestamps

Always use ISO 8601 with timezone:

```dart
// ✅ Correct
final timestamp = DateTime.now().toIso8601String();
// "2025-10-15T14:30:00.000-05:00"

// ❌ Wrong
final timestamp = "10/15/2025 2:30 PM";
```

## References

- **Database Schema**: `spec/JSONB_SCHEMA.md`
- **Validation Functions**: `database/schema.sql`
- **Compliance**: `spec/compliance-practices.md`

## Testing

Example unit tests:

```dart
import 'package:test/test.dart';
import 'package:your_app/models/diary_models.dart';

void main() {
  group('EpistaxisRecord', () {
    test('creates valid nosebleed event', () {
      final event = EpistaxisRecord.createNosebleed(
        startTime: DateTime(2025, 10, 15, 14, 30),
        intensity: EpistaxisIntensity.drippingQuickly,
      );

      expect(event.startTime, isNotNull);
      expect(event.intensity, EpistaxisIntensity.drippingQuickly);
      expect(event.isNoNosebleedsEvent, false);
    });

    test('validates mutual exclusivity', () {
      expect(
        () => EpistaxisRecord(
          id: EventRecord.generateUuid(),
          startTime: DateTime.now(),
          isNoNosebleedsEvent: true,
          isUnknownNosebleedsEvent: true,
          lastModified: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('converts to/from JSON', () {
      final original = EpistaxisRecord.createNosebleed(
        startTime: DateTime(2025, 10, 15, 14, 30),
        intensity: EpistaxisIntensity.drippingQuickly,
      );

      final json = original.toJson();
      final restored = EpistaxisRecord.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.intensity, original.intensity);
    });
  });

  group('SurveyRecord', () {
    test('creates valid survey', () {
      final survey = SurveyRecord.create(
        survey: [
          SurveyQuestion(
            questionId: 'q1',
            questionText: 'Test question?',
            response: 'answer',
          ),
        ],
      );

      expect(survey.survey, hasLength(1));
      expect(survey.completedAt, isNotNull);
    });

    test('validates non-empty survey', () {
      expect(
        () => SurveyRecord(
          id: EventRecord.generateUuid(),
          completedAt: DateTime.now(),
          survey: [],  // ❌ Empty
          lastModified: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });
}
```

## Deleting Events

### Deletion Logic with User Prompting

When deleting the last event on a given day, the system prompts the user to clarify intent:

1. **Confirm "no nosebleeds occurred"** - Converts event to `isNoNosebleedsEvent: true`
   - Recommended for protocol compliance
   - Shows diary adherence
   - Preserves the date in timeline

2. **Just delete** - Soft deletes the event
   - For erroneous entries
   - Day will show as having no events

### Using EventDeletionHandler

```dart
import 'package:your_app/services/diary_repository.dart';
import 'package:your_app/services/event_deletion_handler.dart';

// Initialize
final repository = DiaryRepository(supabase);
final deletionHandler = EventDeletionHandler(repository);

// Delete with prompting
final result = await deletionHandler.deleteEvent(
  eventUuid: event.id,
  eventDate: epistaxisRecord.startTime,
  promptUser: (prompt) async {
    // Show dialog to user
    return await showDialog<DeletionChoice>(
      context: context,
      builder: (context) => DeletionPromptDialog(prompt: prompt),
    ) ?? DeletionChoice.justDelete;
  },
);

// Handle result
if (result.wasConverted) {
  print('Event converted to "no nosebleeds" confirmation');
} else {
  print('Event soft deleted');
}
```

### Repository Pattern (Event Sourcing)

All modifications go through the audit trail:

```dart
final repository = DiaryRepository(supabase);

// Create event
await repository.createEvent(
  event: eventRecord,
  changeReason: 'Initial diary entry',
);

// Update event
await repository.updateEvent(
  eventUuid: event.id,
  eventData: updatedEpistaxisRecord,
  changeReason: 'Corrected intensity level',
);

// Soft delete event
await repository.deleteEvent(
  eventUuid: event.id,
  changeReason: 'User deleted event',
);

// Query events
final eventsToday = await repository.getEventsForDate(DateTime.now());
final auditHistory = await repository.getAuditHistory(event.id);
```

### UI Integration

See `ui_example.dart` for complete examples including:
- `DiaryEventCard` - Event card with delete button
- `DeletionPromptDialog` - User choice dialog
- `DiaryCalendarView` - Calendar with event list

## Migration from TypeScript

If migrating from the TypeScript mock-up (`diary.tsx`):

| TypeScript | Dart |
| --- | --- |
| `string` | `String` |
| `Date` | `DateTime` |
| `boolean` | `bool` |
| `?` (optional) | `?` (nullable) |
| `type` | `class` |
| `enum` with strings | `enum` with values |
| `JSON.stringify()` | `.toJson()` |
| `JSON.parse()` | `.fromJson()` |

Key differences:
- Dart enums are strongly typed (use `.value` to get string)
- Dart DateTime automatically handles ISO 8601
- Dart has built-in validation in constructors
