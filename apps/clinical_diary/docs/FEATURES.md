# Clinical Diary App - Complete Feature List

**Development Period**: November 21, 2024 - December 10, 2024 (13 working days)
**Version**: 0.7.64
**Platform**: Flutter (iOS, Android, Web)

---

## Executive Summary

This document catalogs the features and capabilities of the Clinical Diary
application MVP - an FDA 21 CFR Part 11 compliant mobile application for
clinical trial participants to track nosebleed events
(HHT/Hereditary Hemorrhagic Telangiectasia).

### By The Numbers

| Metric | Value |
| ------ | ----- |
| Total Dart Files | 94 |
| Lines of Code | 33,307+ |
| Total Commits (since Nov 21) | 625+ |
| Commits to clinical_diary | 53+ |
| Custom Widgets | 19 |
| Screens | 9 |
| Services | 5 |
| Localization Languages | 4 |
| Build Flavors | 5 |
| Build Scripts | 13 |
| GitHub Actions Workflows | 26 |
| Custom Image Assets | 13 |
| **Flutter Unit Tests** | **610+** |
| **Flutter Integration Tests** | **65** |
| **Append-Only Datastore Tests** | **90** |
| **TypeScript Function Tests** | **143** |
| **Total Automated Tests** | **908+** |
| Unit Test Files | 37 |
| Integration Test Files | 6 |
| Datastore Test Files | 6 |

### Daily Productivity (13 working days)

| Metric | Per Day Average |
| ------ | --------------- |
| Lines of Code | **2,562** (1 line every 10 seconds.) |
| Commits | **48** |
| Automated Tests Written | **70** |
| Dart Files Created | **7.2** |
| Releases | **4.9** |

That's nearly 5 releases every single working day - demonstrating true
continuous integration/continuous delivery.

### Quality Metrics (Git Commit Analysis)

| Metric | Value |
| ------ | ----- |
| Total PRs | 53 |
| Feature PRs | 17 (32%) |
| Bug Fix PRs | 16 (30%) |
| Other (Tests/Refactor/Docs) | 20 (38%) |
| **Bug-to-Feature Ratio** | **1:1.1** |

#### Bug Severity Breakdown

| Severity | Count | Percentage |
| -------- | ----- | ---------- |
| Critical (Data Loss/Security) | **0** | 0% |
| High (Data Integrity) | 2 | 12.5% |
| Medium (Validation/UI) | 10 | 62.5% |
| Low (Cosmetic/UX) | 4 | 25% |

#### All Bugs Fixed (16 Total)

| Ticket | Description | Severity |
| ------ | ----------- | -------- |
| CUR-512 | Fix UTC time display on home page | Low |
| CUR-409 | Improved recording screen (multiple fixes) | Medium |
| CUR-409 | Date time bugs in record | Medium |
| CUR-485 | Fix lint errors | Low |
| CUR-464 | Fix TimePickerDial adjustment buttons not updating parent | Medium |
| CUR-447 | Fix past date time validation | Medium |
| CUR-447 | Fix cross-day time validation and improve UI | Medium |
| CUR-447 | Fix cross-day time validation in diary entry form | Medium |
| CUR-447/449 | Fix past date time selection and cross-day overlap | Medium |
| CUR-465 | Fix delete button not working | Medium |
| CUR-416 | Fix severity to intensity (terminology) | Low |
| CUR-442/451 | Fix partial record saving in both forms | High |
| CUR-447 | Fix past date time selection in original form | Medium |
| CUR-427 | Fix end time validation - prevent future times | Medium |
| CUR-407 | Fix calendar date validation | Medium |
| CUR-409/410 | Clinical Diary UI bug fixes | High |

**Note**: With **zero critical bugs** and most issues being validation edge
cases caught during development.

---

## 1. Core Application Features

### 1.1 Nosebleed Event Recording

#### Primary Recording Screen (`recording_screen.dart`)

- **Multi-step wizard flow**: Start Time -> Intensity -> End Time -> Complete
- **Context-aware initialization**: Three creation modes:
  1. New entry for today (starts at current time)
  2. Calendar-selected date (preserves selected date with current time)
  3. Edit existing record (loads all previous values)
- **Auto-save functionality**: Incomplete records saved automatically on back
  navigation
- **Time validation**: Prevents future time selection with visual feedback
- **Cross-midnight support**: Events spanning multiple calendar days handled
  correctly
- **Overlap detection**: Visual warnings when events overlap with other records

#### Time Selection Features (`time_picker_dial.dart`)

- **Custom dial-style time picker** with:
  - Large, accessible time display (72px font)
  - Tappable time to open system time picker
  - Tappable date header to open calendar picker
  - Quick adjustment buttons: -15, -5, -1, +1, +5, +15 minutes
  - Error flash animation on invalid time adjustments
  - Future time prevention with max time clamping
- **Timezone support**:
  - IANA timezone selection via searchable dropdown
  - POSIX to IANA normalization (EST5EDT -> America/New_York)
  - Timezone display below time
  - Timezone change callbacks for parent components
- **12/24-hour format**: Automatic locale-based detection
- **Real-time parent notification**: `onTimeChanged` callback for live updates

#### Intensity Selection (`intensity_picker.dart`)

- **6-level intensity scale** with custom medical-grade illustrations:
  - Spotting
  - Dripping
  - Dripping Quickly
  - Steady Stream
  - Pouring
  - Gushing
- **Visual grid layout**: 2x3 responsive grid with:
  - Custom-bordered intensity images
  - Selected state highlighting with primary color border
  - Responsive icon sizing based on container constraints
  - Dynamic font sizing: 9-13px based on available space
  - Two-line text labels for multi-word intensities
- **Accessibility-conscious sizing**: Maintains minimum 50x50px touch targets

### 1.2 Responsive Design (No-Scroll Architecture)

The app is designed to fit completely on screen without scrolling, even on
the smallest supported device (iPhone SE - 320pt width, 568pt height).

#### Design Philosophy

- **No scrolling required**: All primary screens fit within viewport
- **iPhone SE compatible**: Tested and optimized for 320x568pt screens
- **Constraint-based layouts**: Uses `LayoutBuilder` to adapt to available space
- **Dynamic sizing**: Icons, fonts, and spacing scale based on screen dimensions

#### Technical Implementation

**Screen-Level Architecture**:

- `Expanded` widgets fill available vertical space without overflow
- `NeverScrollableScrollPhysics` on grids prevents accidental scrolling
- Fixed header/footer heights with flexible content areas

**Intensity Picker Responsiveness** (`intensity_picker.dart`):

```text
Available Height Calculation:
  availableHeight = constraints.maxHeight - headerHeight - gridSpacing
  boxHeight = (availableHeight / 3).clamp(50.0, 100.0)
  iconSize = (boxHeight * 0.45).clamp(24.0, 44.0)
  fontSize = (boxHeight * 0.15).clamp(9.0, 13.0)
```

- Header titles use `TextScaler.noScaling` to prevent overflow on large text
- Grid aspect ratio dynamically calculated from container width
- Icon/text sizes proportionally scale to fit 2x3 grid

**Time Picker Responsiveness** (`time_picker_dial.dart`):

- Compact button layout with reduced padding for small screens
- Time display scales based on available width
- Quick-adjust buttons maintain minimum touch targets

**Web Platform** (`responsive_web_frame.dart`):

- Constrains content to 540px max width (simulates phone viewport)
- Centers content on large screens
- Passes through unchanged on mobile platforms

#### CUR-488 Small Screen Optimizations

- Reduced padding: 8px -> 4px on intensity picker
- Reduced grid spacing: 6px -> 4px between intensity options
- Title text scaling disabled to prevent overflow
- Compact view preference for home screen

### 1.3 Calendar & History Management

#### Calendar Screen (`calendar_screen.dart`)

- **Full-featured table calendar** using `table_calendar` package
- **Color-coded day status**:
  - Red: Nosebleed events recorded
  - Green: No nosebleeds confirmed
  - Orange: Unknown/don't recall
  - Black: Incomplete events (missing data)
  - Gray: Not recorded
  - Blue border: Today
- **Status range loading**: Loads +/-1 month for smooth scrolling
- **Future date prevention**: Disabled days for future dates (CUR-407)
- **Page change handling**: Auto-reload statuses on month navigation
- **Legend display**: Color-coded legend explaining all status types
- **Navigation flow**: Day tap -> Day Selection Screen or Date Records Screen

#### Day Selection Screen (`day_selection_screen.dart`)

- Three-option interface for unrecorded days:
  1. "Add nosebleed event" (red/primary button)
  2. "No nosebleed events" (green outline button)
  3. "I don't recall / unknown" (neutral outline button)

#### Date Records Screen (`date_records_screen.dart`)

- **Event list for specific date** with:
  - Formatted date header (EEEE, MMMM d, y)
  - Event count subtitle
  - "Add new event" button
  - Scrollable event list with edit capability
- **Overlap detection**: Warning icons on conflicting events

### 1.4 Home Screen

#### Features Implemented

- **Real-time UTC/local time display** (CUR-512 fix)
- **Recent events list** with color-coded status
- **Incomplete events highlighting** with edit icons
- **"Record Nosebleed" primary action button**
- **Calendar navigation** button
- **Settings access** via menu
- **Compact view toggle** (CUR-464)
- **Yesterday reminder banner** when no records exist

### 1.5 Event List Item Widget (`event_list_item.dart`)

- **Three card types**:
  1. **No Nosebleeds Card**: Green background, check icon
  2. **Unknown Card**: Yellow background, help icon
  3. **Nosebleed Event Card**: One-line format with:
     - Fixed-width time column (80px for 12h, 45px for 24h format)
     - Mini intensity icon (28x28px with border)
     - Duration display (90px width for "Incomplete" text)
     - Multi-day indicator ("+1 day" for overnight events)
     - Incomplete indicator (edit icon)
     - Overlap warning (amber warning icon)
     - Navigation chevron
- **Incomplete record styling**: Orange tint background
- **Enhanced shadows**: 2px elevation with 15% black

---

## 2. White-Labeling & Multi-Sponsor Architecture

The platform is designed from the ground up to support multiple clinical
trial sponsors with complete isolation and customization.

### 2.1 Feature Flag System (`feature_flags.dart`)

Server-controlled configuration loaded at enrollment time, allowing each
sponsor to customize app behavior without code changes.

#### Available Feature Flags

| Flag | Default | Description |
| ---- | ------- | ----------- |
| `useReviewScreen` | false | Show review screen before save |
| `useAnimations` | true | Enable/disable all UI animations |
| `requireOldEntryJustification` | false | REQ-CAL-p00001: Require reason |
| `enableShortDurationConfirmation` | false | REQ-CAL-p00002: Confirm short |
| `enableLongDurationConfirmation` | false | REQ-CAL-p00003: Confirm long |
| `longDurationThresholdMinutes` | 60 | Configurable threshold (1-9 hrs) |

#### Sponsor Configuration Flow

1. User enrolls with sponsor-specific code (e.g., `CUREHHT#`)
2. App calls `/sponsorConfig?sponsorId={id}` endpoint
3. Server returns sponsor-specific feature flag values
4. Flags stored in memory, applied immediately
5. Dev/QA builds allow manual flag override for testing

### 2.2 Sponsor Isolation Architecture

Each sponsor operates **completely independently**:

| Aspect | Isolation Method |
| ------ | ---------------- |
| **Database** | Separate Supabase project per sponsor |
| **Portal** | Unique URL per sponsor |
| **Users** | Independent user accounts per sponsor |
| **Audit Trail** | Separate event logs per sponsor |
| **Configuration** | Isolated config files (gitignored secrets) |
| **Data Access** | No cross-sponsor access possible |
| **Infrastructure** | Separate AWS S3 buckets per sponsor |

### 2.3 Sponsor Directory Structure

```text
sponsor/
├── callisto/                    # Example sponsor
│   ├── mobile-module/
│   │   ├── assets/              # Custom branding (logo.svg)
│   │   └── lib/                 # Sponsor-specific Dart code
│   ├── portal/
│   │   └── database/            # Sponsor-specific schema
│   ├── infrastructure/
│   │   ├── supabase/config/     # Supabase configuration
│   │   └── terraform/           # AWS infrastructure
│   └── sponsor-config.yml       # Master configuration
│
└── template/                    # Template for new sponsors
    └── [same structure]
```

### 2.4 Sponsor Configuration (`sponsor-config.yml`)

```yaml
sponsor:
  name: "callisto"
  code: "CAL"
  display_name: "Callisto Clinical Trial"

mobile_module:
  enabled: true
  features:
    - custom_forms
    - medication_tracking
    - symptom_diary

portal:
  enabled: true
  database:
    schema_file: "portal/database/schema.sql"
  deployment:
    supabase_project_id: "callisto-portal-prod"
    region: "eu-west-1"

infrastructure:
  aws:
    region: "eu-west-1"
    s3_buckets:
      artifacts: "hht-diary-artifacts-callisto-eu-west-1"
      backups: "hht-diary-backups-callisto-eu-west-1"
```

### 2.5 White-Label Customization Points

| Component | Customizable | Method |
| --------- | ------------ | ------ |
| **App Icon** | Per flavor | `assets/icons/{flavor}/app_icon.png` |
| **Splash Screen** | Per flavor | Flutter native splash config |
| **Logo** | Per sponsor | `sponsor/{name}/assets/logo.svg` |
| **Primary Color** | Per sponsor | `portal.yaml` branding config |
| **Feature Toggles** | Per sponsor | Server-side feature flags |
| **Validation Rules** | Per sponsor | Feature flag thresholds |
| **Portal URL** | Per sponsor | Deployment configuration |
| **Database** | Per sponsor | Separate Supabase project |

### 2.6 Known Sponsors

| Sponsor | Code | Status |
| ------- | ---- | ------ |
| CureHHT | `curehht` | Production |
| Callisto | `callisto` | Development |

### 2.7 Build System Integration

- Single mobile app contains all sponsor configurations
- Dynamic sponsor selection via enrollment code
- Updates benefit all sponsors simultaneously
- Sponsor-specific build reports generated per release
- 7-year report retention per FDA 21 CFR Part 11

---

## 3. Data Management

### 3.1 Nosebleed Service (`nosebleed_service.dart`)

#### Core Capabilities

- **Append-only event sourcing** for FDA 21 CFR Part 11 compliance
- **Cryptographic hash chain** for tamper detection via `append_only_datastore`
- **Device UUID generation and persistence** (REQ-d00013)
- **Record ID generation** using UUID v4

#### Data Operations

- `addRecord()`: Create new nosebleed event with:
  - Start time (ISO 8601 with timezone offset)
  - End time (optional)
  - Intensity (optional)
  - Notes (optional)
  - No-nosebleed flag
  - Unknown flag
  - Incomplete auto-detection
- `updateRecord()`: Append-only update (creates new record with `parentRecordId`)
- `deleteRecord()`: Soft delete with reason (creates deletion marker)
- `markNoNosebleeds()`: Mark day as nosebleed-free
- `markUnknown()`: Mark day as unknown/don't recall
- `completeRecord()`: Complete an incomplete record

#### Query Methods

- `getAllLocalRecords()`: Raw event log (all versions)
- `getLocalMaterializedRecords()`: Latest version of each record (CQRS pattern)
- `getRecordsForStartDate()`: Records for specific date
- `getRecentRecords()`: Last 24 hours
- `getIncompleteRecords()`: Records needing completion
- `getDayStatus()`: Single date status for calendar
- `getDayStatusRange()`: Batch status for calendar month
- `hasRecordsForYesterday()`: Check for yesterday reminder

#### Sync Features

- `syncAllRecords()`: Batch upload to cloud via HTTP
- `syncAllRecordsWithResult()`: With detailed result object
- `fetchRecordsFromCloud()`: Download and merge cloud records
- `getUnsyncedCount()`: Pending sync count
- Non-blocking individual record sync on save

#### Data Integrity

- `verifyDataIntegrity()`: Hash chain verification
- `clearLocalData()`: Dev/test environment reset with reinitialization

### 3.2 Nosebleed Record Model (`nosebleed_record.dart`)

#### Intensity Enum (`NosebleedIntensity`)

```dart
enum NosebleedIntensity {
  spotting,
  dripping,
  drippingQuickly,
  steadyStream,
  pouring,
  gushing
}
```

- `displayName` getter for UI
- `fromString()` factory for parsing

#### Record Properties

- `id`: UUID
- `startTime`: Required DateTime
- `endTime`: Optional DateTime
- `intensity`: Optional NosebleedIntensity
- `notes`: Optional String
- `isNoNosebleedsEvent`: Boolean flag
- `isUnknownEvent`: Boolean flag
- `isIncomplete`: Auto-calculated based on missing data
- `isDeleted`: Soft delete flag
- `deleteReason`: Required when deleted
- `parentRecordId`: For append-only updates
- `deviceUuid`: Originating device
- `createdAt`: Record creation timestamp
- `syncedAt`: Cloud sync timestamp

#### Computed Properties

- `isRealNosebleedEvent`: Not a "no nosebleed" or "unknown" marker
- `isComplete`: Has all required data
- `durationMinutes`: Calculated from start/end times

#### Serialization

- `fromJson()`: Parse with timezone preservation via `DateTimeFormatter`
- `toJson()`: Serialize with ISO 8601 timezone offset

### 3.3 DateTime Formatter Utility (`date_time_formatter.dart`)

- **Timezone-preserving serialization**: `format()` outputs ISO 8601 with offset
- **Timezone-aware parsing**: `parse()` converts to local time correctly
- **Clinical accuracy**: Preserves user's timezone at time of entry

### 3.4 Append-Only Datastore (External Package)

- **Event sourcing architecture**: Immutable event log
- **SQLite storage** via sembast
- **Cryptographic hash chain**: Each event includes hash of previous
- **Integrity verification**: Full chain validation
- **CRUD operations**: Append-only (no updates/deletes)
- **Sync tracking**: Synced/unsynced event status

---

## 4. Authentication & Enrollment

### 4.1 Auth Service (`auth_service.dart`)

#### Account Management

- `register()`: Create new account with:
  - Username validation (6+ chars, alphanumeric + underscore, no @)
  - Password validation (8+ chars)
  - SHA-256 password hashing before transmission
  - JWT token storage
- `login()`: Authenticate existing user
- `logout()`: Clear session
- `changePassword()`: Update credentials with current password verification

#### Secure Storage

- Uses `flutter_secure_storage` for:
  - App UUID (unique per installation)
  - Username
  - Password (for auto-fill, not transmitted)
  - Login state
  - JWT token

#### Validation Methods

- `validateUsername()`: Returns null if valid, error message otherwise
- `validatePassword()`: Returns null if valid, error message otherwise
- `hasStoredCredentials()`: Check for existing account

### 4.2 Enrollment Service (`enrollment_service.dart`)

#### Code-Based Enrollment

- `enroll()`: 8-character code enrollment (CUREHHT#) with:
  - Code normalization (uppercase, trim)
  - HTTP POST to cloud function
  - Error handling for:
    - 409: Code already used
    - 400: Invalid code
    - Other: Server error
  - Secure storage of enrollment data

#### Enrollment Data (`user_enrollment.dart`)

- `userId`: Server-assigned user ID
- `jwtToken`: Authentication token
- `enrolledAt`: Enrollment timestamp

#### Dual-Auth Support

- `getJwtToken()`: Checks enrollment first, falls back to auth_jwt
- `getUserId()`: Checks enrollment first, falls back to auth_username

### 4.3 Login Screen (`login_screen.dart`)

#### Tabbed Interface (CUR-464)

- **Login Tab**: Username + password fields
- **Register Tab**: Username + password + confirm password fields

#### UI Components

- **Privacy Notice Card**: Explains username privacy (no email)
- **Security Warning Card**: Credential storage reminder
- **Error Display**: Red container with icon
- **Form Validation**:
  - Real-time validation on change
  - Submit validation
  - Password visibility toggles
- **Loading State**: Spinner in submit button

---

## 5. Preferences & Settings

### 5.1 Preferences Service (`preferences_service.dart`)

#### User Preferences Model

```dart
class UserPreferences {
  final bool isDarkMode;          // Theme
  final bool dyslexiaFriendlyFont; // OpenDyslexic font
  final bool largerTextAndControls; // Accessibility scaling
  final bool useAnimation;         // Animation toggle
  final bool compactView;          // Compact home screen
  final String languageCode;       // 'en', 'es', 'fr', 'de'
}
```

#### Persistence

- Individual setters for each preference
- Full preferences getter/setter
- SharedPreferences storage

### 5.2 Settings Screen (`settings_screen.dart`)

#### Color Scheme Section

- **Light Mode**: Enabled, selectable
- **Dark Mode**: Disabled "Coming soon" (alpha release)

#### Accessibility Section

- **Dyslexia-Friendly Font**: Uses OpenDyslexic
  - External link to opendyslexic.org
- **Larger Text & Controls**: Text scaling (CUR-488)
  - Parent callback for immediate effect
- **Use Animation**: Conditional on feature flag
- **Compact View**: Reduced padding home screen (CUR-464)

#### Language Section

- English (en)
- Español (es)
- Français (fr)
- Deutsch (de)
- Selectable radio-style buttons

#### Dev Tools Section (dev/qa only)

- Feature Flags navigation

---

## 6. Feature Flags System

### 6.1 Feature Flag Configuration (`feature_flags.dart`)

#### Available Flags

- `useReviewScreen`: Show review before save
- `useAnimations`: Enable UI animations
- `requireOldEntryJustification`: REQ-CAL-p00001 compliance
- `enableShortDurationConfirmation`: REQ-CAL-p00002 compliance
- `enableLongDurationConfirmation`: REQ-CAL-p00003 compliance
- `longDurationThresholdMinutes`: Configurable threshold (60-1440 min)

#### Sponsor Configuration

- Known sponsors list
- Server-based configuration loading
- Per-sponsor flag overrides

### 6.2 Feature Flags Screen (`feature_flags_screen.dart`)

- **Warning Banner**: Dev/test only notice
- **Sponsor Selection**: Dropdown + Load from server
- **UI Features Toggle**:
  - Review screen
  - Animations
- **Validation Features Toggle**:
  - Old entry justification
  - Short duration confirmation
  - Long duration confirmation
  - Long duration threshold slider (1-24 hours)
- **Reset to Defaults**: Confirmation dialog

---

## 7. Internationalization (i18n)

### 7.1 Localization Support

#### Languages

- **English (en)**: Primary
- **Spanish (es)**: Full translation
- **French (fr)**: Full translation
- **German (de)**: Full translation

#### Translation Categories

- Navigation labels
- Form field labels
- Button text
- Error messages
- Dialog content
- Calendar labels
- Intensity names
- Feature flag descriptions
- Privacy notices
- Accessibility descriptions

### 7.2 AppLocalizations (`app_localizations.dart`)

- Generated from ARB files
- `AppLocalizations.of(context)` accessor
- `translate(key)` dynamic lookup
- `intensityName(name)` intensity translations
- Parameterized strings (e.g., `minimumCharacters(count)`)

---

## 8. Custom Widgets

### 8.1 UI Components

| Widget | Purpose |
| ------ | ------- |
| `TimePickerDial` | Custom time selection with dial interface |
| `IntensityPicker` | 6-option intensity grid |
| `EventListItem` | Nosebleed event card with status |
| `DateHeader` | Tappable date display with calendar |
| `EnvironmentBanner` | DEV/TEST ribbon overlay |
| `LogoMenu` | App menu with logo |
| `YesterdayBanner` | Missing yesterday reminder |
| `ResponsiveWebFrame` | Phone-sized web viewport |
| `FlashHighlight` | Attention-grabbing animation |

### 8.2 Dialog Components

| Widget | Purpose |
| ------ | ------- |
| `DeleteConfirmationDialog` | Record deletion with reason |
| `DurationConfirmationDialog` | Short/long duration validation |
| `OldEntryJustificationDialog` | Past entry modification reason |
| `EnrollmentSuccessDialog` | Enrollment completion |
| `OverlapWarning` | Conflicting event alert |

### 8.3 Input Components

| Widget | Purpose |
| ------ | ------- |
| `CompactDatePicker` | Inline date selection |
| `InlineTimePicker` | Inline time selection |
| `NotesInput` | Multi-line text input |
| `IntensityRow` | Horizontal intensity selector |
| `CalendarOverlay` | Modal calendar view |

---

## 9. Build System & Flavors

### 9.1 Flutter Flavors (`flavors.dart`)

#### Environments

| Flavor | Purpose | Banner | Dev Tools |
| ------ | ------- | ------ | --------- |
| `dev` | Development | Yes | Yes |
| `qa` | QA Testing | Yes | Yes |
| `uat` | User Acceptance | Yes | No |
| `prod` | Production | No | No |

#### Flavor Configuration

- `apiBase`: Firebase hosting URL per environment
- `showBanner`: Environment ribbon visibility
- `showDevTools`: Dev menu items visibility

### 9.2 Build Scripts (`tool/`)

| Script | Purpose |
| ------ | ------- |
| `build_android_dev.sh` | Android dev APK |
| `build_android_qa.sh` | Android QA APK |
| `build_android_prod.sh` | Android production APK |
| `build_ios_dev.sh` | iOS dev IPA |
| `build_ios_qa.sh` | iOS QA IPA |
| `build_ios_prod.sh` | iOS production IPA |
| `build_web_dev.sh` | Web dev build |
| `build_web_qa.sh` | Web QA build |
| `build_web_prod.sh` | Web production build |
| `deploy_to_firebase.sh` | Firebase hosting deploy |
| `coverage.sh` | Test coverage report |
| `test.sh` | Run tests |
| `setup-firebase-permissions.sh` | Firebase setup |

### 9.3 Flavor-Specific Assets

```text
assets/
├── icons/
│   ├── app_icon.png         # Default
│   ├── dev/app_icon.png     # Dev (different color)
│   ├── qa/app_icon.png      # QA
│   ├── uat/app_icon.png     # UAT
│   └── prod/app_icon.png    # Production
└── images/
    ├── cure-hht-grey.png
    ├── helix-1024.png
    ├── intensity_spotting.png
    ├── intensity_dripping.png
    ├── intensity_dripping_quickly.png
    ├── intensity_steady_stream.png
    ├── intensity_pouring.png
    └── intensity_gushing.png
```

### 9.4 Platform-Specific Builds

#### Android (`android/app/src/`)

- `main/` - Common code
- `dev/` - Dev flavor
- `qa/` - QA flavor
- `uat/` - UAT flavor
- `prod/` - Production flavor
- `debug/` - Debug builds
- `profile/` - Profile builds

#### iOS

- Scheme per flavor
- Info.plist per environment
- Bundle ID suffixes

---

## 10. CI/CD & Automation

### 10.1 GitHub Actions Workflows

#### App-Specific Workflows (Detailed)

##### `clinical_diary-ci.yml` - Main CI Pipeline

**Triggers**:

- Pull requests to `main` or `develop` branches
- Only when `apps/clinical_diary/**` files change
- Manual dispatch available

**Jobs**:

1. **Analyze Flutter** (`analyze`)
   - Runs on: `ubuntu-latest`
   - Flutter version: `3.38.3` (stable, cached)
   - Steps:
     - `dart format --output=none --set-exit-if-changed .` -
       Enforces consistent formatting
     - `flutter analyze --fatal-infos` -
       Static analysis with strict rules (fails on info-level issues)

2. **Test Clinical Diary** (`test-clinical-diary`)
   - Runs on: `ubuntu-latest`
   - Dependencies installed:
     - Linux desktop: GTK+3, X11, pkg-config, cmake, ninja-build
     - Secure storage: libsecret-1-dev, gnome-keyring, dbus-x11
     - Display server: xvfb (for headless GUI tests)
   - Node.js 20 + Java 17 (for Firebase emulator)
   - Firebase CLI installed globally
   - Test execution:
     - Runs `tool/coverage.sh -f -t` (full coverage with integration tests)
     - Uses `dbus-run-session` with unlocked gnome-keyring for
       `flutter_secure_storage` tests
     - Firebase emulator for cloud function integration tests

3. **Deploy Web to Firebase** (`deploy-web`)
   - Runs on: `ubuntu-latest`
   - **Only runs**: On push to `main` (not PRs)
   - Requires: `analyze` and `test-clinical-diary` to pass
   - Authentication: Workload Identity Federation (keyless)
   - Build command: `flutter build web --release --dart-define=APP_FLAVOR=dev`
   - Deploy: `firebase deploy --only hosting`

---

##### `clinical_diary-coverage.yml` - Test Coverage Reporting

**Triggers**:

- Push to `main` branch only
- Only when `apps/clinical_diary/**` files change
- Manual dispatch available

**Job**: Coverage Report (`coverage`)

- Runs on: `ubuntu-latest`
- Flutter version: `3.38.3` (stable)
- Steps:
  1. Install dependencies via `flutter pub get`
  2. Install `lcov` for coverage report generation
  3. Run `tool/coverage.sh` - generates `coverage/lcov.info`
  4. Upload to **Codecov** with:
     - Flag: `clinical_diary`
     - Name: `clinical-diary-coverage`
     - Non-blocking on upload failure

**Coverage Script** (`tool/coverage.sh`):

- Runs unit tests with `--coverage` flag
- Runs integration tests with Firebase emulator (when `-t` flag)
- Generates LCOV report
- Enforces coverage thresholds
- Excludes generated files (`.g.dart`, `.freezed.dart`)

---

#### Supporting

| Workflow | Purpose |
| -------- | ------- |
| `append_only_datastore-ci.yml` | Datastore package CI |
| `append_only_datastore-coverage.yml` | Datastore coverage |

---

### 10.2 Git Hooks (`.githooks/`)

Local enforcement of code quality before commits and pushes reach CI/CD.

**Installation**: `git config core.hooksPath .githooks`

---

#### `pre-commit` - Code Quality Gate

**Triggers**: Every `git commit`

**Checks Performed**:

1. **Branch Health Check**
   - Blocks commits on merged/stale branches
   - Uses `branch-health-check.sh` for status detection

2. **Branch Protection**
   - Blocks direct commits to `main`/`master`
   - Enforces feature branch workflow
   - Provides instructions for creating feature branches

3. **Ticket-Branch Consistency** (warning only)
   - Detects mismatch between active Linear ticket and branch name
   - Extracts `CUR-XXX` from branch name
   - Warns if committing to wrong ticket's branch

4. **Dart Code Quality** (for `apps/**/*.dart` files)
   - **dart format**: Auto-formats and re-stages files
   - **dart analyze --fatal-infos**: Blocks on any analysis issues
   - Walks up directory tree to find `pubspec.yaml`
   - Runs per-project, supports multiple Dart projects

5. **TypeScript Code Quality** (for `apps/**/*.ts` files)
   - Runs `npm run lint` (ESLint) on affected projects
   - Auto-installs dependencies if `node_modules` missing
   - Only runs if `package.json` has `lint` script

6. **Dockerfile Linting**
   - Runs `hadolint` on changed Dockerfiles
   - Skips if hadolint not installed (with warning)

7. **Markdown Linting**
   - Runs `markdownlint` with `.markdownlint.json` config
   - Skips `untracked-notes/` directory
   - Skips if markdownlint not installed (with warning)

8. **Plugin Hooks**
   - Auto-discovers and executes hooks from
     `tools/anspar-cc-plugins/plugins/*/hooks/pre-commit`
   - Includes REQ traceability validation

---

#### `commit-msg` - Commit Message Validation

**Triggers**: After commit message is written

**Checks Performed**:

- Auto-discovers plugin commit-msg hooks
- **REQ Traceability**: Validates `Implements: REQ-xxx` or `Fixes: REQ-xxx`
  in message
- Blocks commits without requirement references

---

#### `pre-push` - Push Validation Gate

**Triggers**: Every `git push`

**PR-Aware Blocking**:

- **PR-intended branches** (`feature/*`, `fix/*`, `release/*`):
  BLOCKS on failure
- **Other branches**: WARNS but allows push
- Detects open PRs via `gh pr view`

**Checks Performed**:

1. **Requirement Validation**
   - Runs `validate_requirements.py`
   - Validates REQ format and links

2. **INDEX.md Validation**
   - Runs `validate_index.py`
   - Ensures spec/INDEX.md is accurate

3. **Markdown Linting**
   - Re-checks all changed `.md` files
   - Uses same config as pre-commit

4. **Secret Detection (Gitleaks)**
   - Scans commits being pushed for secrets
   - **Required**: Fails if gitleaks not installed
   - Redacts secrets in output

5. **Dart Format Check**
   - Verifies ALL Dart files in `apps/` are formatted
   - Runs `dart format --output=none --set-exit-if-changed`
   - Per-app validation

6. **Test Suites**
   - Runs `./tool/test.sh` for affected app directories
   - Only runs if app has changes AND has `tool/test.sh`

7. **Auto Version Bump**
   - If `apps/clinical_diary/` changed, bumps patch version
   - Runs `dart pub bump patch`
   - Amends commit with version change

8. **Plugin Hooks**
   - Auto-discovers `pre-push` hooks from plugins

---

### 10.3 Coverage Script (`tool/coverage.sh`)

Comprehensive test coverage tool for Flutter and TypeScript.

**Usage**:

```bash
./tool/coverage.sh [OPTIONS]

Options:
  -f,  --flutter              Run all Flutter coverage (unit + integration)
  -fu, --flutter-unit         Run Flutter unit tests coverage only
  -fi, --flutter-integration  Run Flutter integration tests on desktop
  -t,  --typescript           Run TypeScript (Functions) coverage only
  --concurrency N             Set Flutter test concurrency (default: 10)
  --no-threshold              Skip coverage threshold checks
```

**Coverage Thresholds**:

| Stack | Minimum |
| ----- | ------- |
| Flutter (Dart) | 74% |
| TypeScript (Functions) | 95% |

**Features**:

1. **Flutter Unit Tests**
   - Runs `flutter test --coverage`
   - Configurable concurrency
   - Filters out generated files (`*.g.dart`, `*.freezed.dart`)

2. **Flutter Integration Tests**
   - Runs on desktop (macOS/Linux/Windows)
   - Uses `xvfb-run` for headless Linux CI
   - Runs each test file separately (avoids macOS lifecycle issues)
   - Merges coverage from all integration tests

3. **TypeScript Functions Tests**
   - Runs `npm run test:coverage` in `functions/`
   - Generates Jest HTML report

4. **Coverage Reports**
   - Combined LCOV: `coverage/lcov.info`
   - Flutter combined: `coverage/lcov-flutter.info`
   - TypeScript: `coverage/lcov-functions.info`
   - HTML reports via `genhtml`

5. **Threshold Enforcement**
   - Fails with exit code 1 if below threshold
   - Can skip with `--no-threshold`

---

## 11. Theming & Design System

### 11.1 App Theme (`app_theme.dart`)

#### Brand Colors

- **Primary Teal**: `#0D9488` (teal-600)
- **Primary Teal Dark**: `#0F766E` (teal-700)
- **Primary Teal Light**: `#14B8A6` (teal-500)

#### Semantic Colors

- **Intensity Low**: `#E0F2FE` (sky-100)
- **Intensity Medium**: `#FEF3C7` (amber-100)
- **Intensity High**: `#FFE4E6` (rose-100)
- **Warning Yellow**: `#FEF9C3` (yellow-50)
- **Warning Orange**: `#FFEDD5` (orange-100)
- **Info Blue**: `#DBEAFE` (blue-100)

#### Material 3 Theme

- Custom `ColorScheme.fromSeed()`
- Centered AppBar titles
- 12px border radius cards
- Custom input decoration with teal focus
- Elevated/outlined button styling

### 11.2 Accessibility Features

- **OpenDyslexic font** support (toggleable)
- **Larger text/controls** mode with scaling
- **Compact view** option for reduced padding
- **Animation toggle** for motion sensitivity
- **High contrast** color choices
- **Touch targets** minimum 44x44px
- **Screen reader** compatibility

---

## 12. Testing Infrastructure

### 12.1 Test Coverage

#### Unit Tests (`test/`)

- Service layer tests
- Model serialization tests
- Utility function tests
- Widget unit tests

#### Integration Tests (`integration_test/`)

- Datastore integration tests
- End-to-end recording flow
- Calendar interaction tests
- Authentication flow tests

### 12.2 Test Utilities

- Mock services via dependency injection
- Fake Firebase implementations
- Test fixtures and factories
- Golden file testing support

### 12.3 Coverage Enforcement

- CI coverage thresholds
- Per-package coverage reports
- Coverage trend tracking
- Branch coverage requirements

---

## 13. Dependencies

### 13.1 Production Dependencies

| Package | Purpose |
| ------- | ------- |
| `append_only_datastore` | FDA-compliant event storage |
| `collection` | Enhanced collections |
| `crypto` | Password hashing |
| `dart_jsonwebtoken` | JWT handling |
| `firebase_core` | Firebase SDK |
| `flutter_secure_storage` | Secure credential storage |
| `flutter_timezone` | Timezone detection |
| `http` | HTTP client |
| `intl` | Internationalization |
| `package_info_plus` | App version info |
| `shared_preferences` | Preferences storage |
| `sugar` | Utility extensions |
| `table_calendar` | Calendar widget |
| `url_launcher` | External link handling |
| `uuid` | UUID generation |
| `timezone` | Timezone database |
| `timezone_button_dropdown` | Timezone picker |

### 13.2 Dev Dependencies

| Package | Purpose |
| ------- | ------- |
| `flutter_test` | Testing framework |
| `integration_test` | Integration testing |
| `flutter_lints` | Code analysis |
| `fake_cloud_firestore` | Firebase mocking |
| `flutter_launcher_icons` | App icon generation |
| `flutter_native_splash` | Splash screen generation |
| `flutter_flavorizr` | Flavor management |

---

## 14. API Integration

### 14.1 Cloud Function Endpoints

| Endpoint | Purpose |
| -------- | ------- |
| `/enroll` | Code-based enrollment |
| `/register` | Account creation |
| `/login` | Authentication |
| `/changePassword` | Password update |
| `/sync` | Record sync (upload) |
| `/getRecords` | Record sync (download) |
| `/health` | Service health check |
| `/sponsorConfig` | Feature flag config |

### 14.2 API Configuration (`app_config.dart`)

- Environment-based API base URLs
- Firebase Hosting rewrites (CORS avoidance)
- Test override support
- Runtime configuration via dart-define

---

## 15. Data Validation & Compliance

### 15.1 REQ-CAL Compliance Features

#### REQ-CAL-p00001: Old Entry Justification

- Entries older than yesterday require justification
- Dialog prompts for reason selection
- Stored with audit trail

#### REQ-CAL-p00002: Short Duration Confirmation

- Events <=1 minute trigger confirmation
- Configurable via feature flag

#### REQ-CAL-p00003: Long Duration Confirmation

- Events exceeding threshold trigger confirmation
- Threshold configurable (1-24 hours)

### 15.2 Data Integrity Features

- **Append-only storage**: No data deletion
- **Hash chain verification**: Tamper detection
- **Audit timestamps**: Client + server times
- **Device identification**: Per-device UUID
- **User identification**: Per-user ID
- **Event versioning**: Parent record linking

---

## 16. Navigation & Routing

### 16.1 App Page Route (`app_page_route.dart`)

- Custom page transitions
- Animation support
- Modal vs. push navigation

### 16.2 Screen Navigation Flow

```text
Login/Enrollment
       ↓
   Home Screen
    ↙    ↘
Calendar  Settings
   ↓
Day Selection → Recording Screen
       ↘           ↓
   Date Records ←──┘
```

---

## 17. Web Platform Support

### 17.1 Responsive Web Frame (`responsive_web_frame.dart`)

- **Phone-sized viewport** on large screens (CUR-422)
- **Centered content** with max-width constraints
- **Device frame simulation** for consistent UX

### 17.2 Web-Specific Configuration

- PWA manifest
- Service worker support
- Firebase hosting configuration
- CORS handling via rewrites

---

## 18. Version Management

### 18.1 Automatic Versioning

- Version in `pubspec.yaml`: 0.7.64
- Auto-increment on merge to main (CUR-432)
- Version display in app menu (CUR-432)
- Package info integration

### 18.2 Release Process

1. PR validation (tests, coverage, lint)
2. Merge to main -> version bump
3. Tag production candidate
4. Deploy to staging
5. UAT approval
6. Deploy to production

---

## 19. Error Handling

### 19.1 Exception Types

- `MissingConfigException`: Required config missing
- `EnrollmentException`: Enrollment failures with typed errors
- Network errors: Handled with user-friendly messages

### 19.2 Error UI Patterns

- Inline error containers (red background)
- SnackBar notifications
- Dialog alerts for critical errors
- Loading states during async operations

---

## Appendix A: File Structure

```text
apps/clinical_diary/
├── lib/
│   ├── main.dart
│   ├── flavors.dart
│   ├── config/
│   │   ├── app_config.dart
│   │   └── feature_flags.dart
│   ├── l10n/
│   │   └── app_localizations.dart
│   ├── models/
│   │   ├── nosebleed_record.dart
│   │   └── user_enrollment.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── recording_screen.dart
│   │   ├── simple_recording_screen.dart
│   │   ├── calendar_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── login_screen.dart
│   │   ├── date_records_screen.dart
│   │   ├── day_selection_screen.dart
│   │   └── feature_flags_screen.dart
│   ├── services/
│   │   ├── nosebleed_service.dart
│   │   ├── auth_service.dart
│   │   ├── enrollment_service.dart
│   │   └── preferences_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── utils/
│   │   ├── app_page_route.dart
│   │   └── date_time_formatter.dart
│   └── widgets/
│       ├── time_picker_dial.dart
│       ├── intensity_picker.dart
│       ├── event_list_item.dart
│       ├── date_header.dart
│       ├── delete_confirmation_dialog.dart
│       ├── duration_confirmation_dialog.dart
│       ├── old_entry_justification_dialog.dart
│       ├── enrollment_success_dialog.dart
│       ├── overlap_warning.dart
│       ├── environment_banner.dart
│       ├── logo_menu.dart
│       ├── yesterday_banner.dart
│       ├── responsive_web_frame.dart
│       ├── flash_highlight.dart
│       ├── compact_date_picker.dart
│       ├── inline_time_picker.dart
│       ├── notes_input.dart
│       ├── intensity_row.dart
│       └── calendar_overlay.dart
├── test/
├── integration_test/
├── android/
├── ios/
├── web/
├── assets/
│   ├── icons/
│   └── images/
├── tool/
│   └── *.sh
└── pubspec.yaml
```

---

## Appendix B: Commit History Highlights

Key feature commits since November 21, 2024:

- `103541c`: Initial Flutter clinical diary app - 93% test coverage
- `201c3d6`: Cure HHT app icon and native splash screen
- `b31f2ae`: Login screen implementation
- `b4cac99`: Entry screen redesign
- `c6df022`: One-line history format with intensity icons
- `74c57b3`: Improved home page, recording screen UIs
- `858ba9b`: Cross-day time validation fixes
- `d07460e`: Compact view user preference
- `c7336e5`: Phase 2 larger text preference and UX polish
- `529f9bf`: Short duration (<=1m) handling
- `1070c2c`: UTC time display fix

---

*This document was generated on December 10, 2024 and represents the complete
feature set of the Clinical Diary application after 13 working days of
development.*
