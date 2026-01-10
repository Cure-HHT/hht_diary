# Clinical Diary MVP Summary

## Original Requirements (User Prompt)

Create a Flutter app for the "CureHHTApp-v4---GenericCo" Figma design with:

- Firebase project (hht-diary-mvp)
- MVP for testing with Cure HHT members
- No sponsors yet (ignore sponsor enrollment)
- Three-word token enrollment (bicycle-bear-ocean style)
- No Firebase Auth - JWT tokens instead for GDPR compliance
- Enroll function that rejects if words already used
- Nosebleed recording screen from Figma design
- Offline-first with Firestore sync
- Append-only data pattern (no updates or deletes)
- Must work on web, iOS, Android, macOS, Windows, Linux

## What Was Built

### Flutter App Structure

```
apps/daily-diary/clinical_diary/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   ├── app_config.dart          # Firebase endpoints
│   │   └── word_lists.dart          # Three-word token lists
│   ├── models/
│   │   ├── nosebleed_record.dart    # Record model with severity
│   │   └── user_enrollment.dart     # Enrollment data model
│   ├── services/
│   │   ├── enrollment_service.dart  # JWT enrollment service
│   │   └── nosebleed_service.dart   # Append-only data service
│   ├── screens/
│   │   ├── enrollment_screen.dart   # Three-word picker UI
│   │   ├── home_screen.dart         # Recent events & record button
│   │   └── recording_screen.dart    # Recording flow wizard
│   ├── widgets/
│   │   ├── event_list_item.dart     # Event display card
│   │   ├── severity_picker.dart     # 6-option severity grid
│   │   ├── time_picker_dial.dart    # Time picker with ±buttons
│   │   └── yesterday_banner.dart    # Yesterday confirmation
│   └── theme/
│       └── app_theme.dart           # Material 3 theme
├── functions/
│   └── src/
│       └── index.ts                 # Cloud Functions (enrollment, sync)
└── docs/
    └── MVP_SUMMARY.md               # This file
```

### Key Features

1. **Three-Word Token Enrollment**
   - Three spinner wheels for word selection
   - Random initial selection
   - Token format: `word1-word2-word3`
   - Unique tokens enforced by backend

2. **JWT Authentication**
   - No Firebase Auth (GDPR compliance)
   - JWT issued on enrollment
   - Stored securely with flutter_secure_storage
   - 365-day expiration for MVP simplicity

3. **Nosebleed Recording Flow**
   - Step 1: Select start time (dial with ±1/5/15 min buttons)
   - Step 2: Select severity (6 levels from Spotting to Gushing)
   - Step 3: Select end time
   - Summary bar shows current selections
   - Optional notes field

4. **Offline-First Architecture**
   - Local storage with SharedPreferences
   - Background Firestore sync when online
   - Append-only pattern (immutable records)
   - Sync status tracking per record

5. **Home Screen**
   - Recent events grouped by day
   - Yesterday confirmation banner
   - Large "Record Nosebleed" button
   - Mark yesterday as "No nosebleeds" or "Don't remember"

### Intensity Levels

1. Spotting - Minor spotting on tissue
2. Dripping - Occasional drops
3. Dripping Quickly - Frequent drops
4. Steady Stream - Continuous flow
5. Pouring - Heavy flow
6. Gushing - Severe, uncontrollable

### Cloud Functions (europe-west1 for GDPR)

- `enroll` - POST /enroll - Register with three-word token
- `health` - GET /health - Health check
- `sync` - POST /sync - Sync records to Firestore
- `getRecords` - GET /records - Retrieve user records

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.13.0
  cloud_firestore: ^5.6.6
  signals: ^6.0.2
  shared_preferences: ^2.5.3
  flutter_secure_storage: ^9.2.4
  uuid: ^4.5.1
  http: ^1.3.0
  intl: ^0.20.2
```

## Deployment

### Deploy Cloud Functions

```bash
cd apps/daily-diary/clinical_diary/functions
npm run deploy
```

### Run Flutter App

```bash
cd apps/daily-diary/clinical_diary
flutter run -d chrome   # Web
flutter run -d macos    # macOS
flutter run -d ios      # iOS
flutter run -d android  # Android
```

## Lint Errors Fixed on Deploy

The following lint errors in `functions/src/index.ts` were fixed:

1. **Line 29** - Line too long (91 chars > 80 max)
   - Split `JWT_SECRET` assignment across lines

2. **Lines 110, 114** - Missing JSDoc for `verifyToken`
   - Added `@param` and `@return` documentation

3. **Line 175** - Line too long (88 chars)
   - Split `userRecordsRef` assignment across lines

## Firebase Project

- Project ID: `hht-diary-mvp`
- Region: `europe-west1` (GDPR compliance)
- Firestore: Native mode
- Functions: Node.js 18

## Data Model

### User Document (`/users/{token}`)
```json
{
  "token": "bear-blue-beach",
  "deviceUuid": "uuid-v4",
  "createdAt": "Timestamp",
  "lastActiveAt": "Timestamp"
}
```

### Record Document (`/users/{token}/records/{id}`)
```json
{
  "id": "uuid-v4",
  "date": "Timestamp",
  "startTime": "Timestamp",
  "endTime": "Timestamp",
  "severity": "dripping",
  "notes": "Optional notes",
  "isNoNosebleedsEvent": false,
  "isUnknownEvent": false,
  "isIncomplete": false,
  "deviceUuid": "uuid-v4",
  "createdAt": "Timestamp",
  "syncedAt": "Timestamp"
}
```

## Requirement Traceability

- REQ-d00004: Local-First Data Entry Implementation
- REQ-d00005: Sponsor Configuration Detection Implementation
- REQ-d00013: Application Instance UUID Generation
- REQ-p00013: GDPR compliance - EU-only regions
