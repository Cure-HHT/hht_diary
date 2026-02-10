# Diary Mobile Application

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Draft

> **See**: prd-architecture-multi-sponsor.md for overall architecture
> **See**: prd-database.md for data architecture
> **See**: prd-security.md for security architecture

---

## Executive Summary

The Diary mobile application is a **Flutter-based cross-platform app** (iOS and Android) that implements an offline-first architecture with multi-sponsor support. A single app deployed to app stores contains configurations for ALL sponsors, with sponsor detection via enrollment tokens.

**Key Features**:
- Single app supports multiple clinical trial sponsors
- Offline-first with automatic background sync
- Event Sourcing for complete audit trail`
- Sponsor-specific branding and configuration
- Secure connection to sponsor's GCP backend
- FDA 21 CFR Part 11 compliant data capture

**Technology Stack**:
- **Framework**: Flutter (single codebase � iOS, Android, Web)
- **Language**: Dart
- **Backend**: Cloud Run with Dart Container GCP (also, indirectly, Cloud SQL + Identity Platform)
- **Local Storage**: FLutter Secure Storage 
- **State Management**: No third-party library needed.
- **Networking**: Firebase Hosting -> Cloud Run

---

## Multi-Sponsor Architecture

# REQ-d00005: Sponsor Configuration Detection Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00007, p00008

## Rationale

This requirement enables a single mobile application binary to serve multiple clinical trial sponsors through dynamic configuration loading. By extracting sponsor identity from enrollment tokens, the system eliminates the need for separate app builds per sponsor while maintaining strict data isolation. The enrollment token acts as the trust anchor - it encodes the sponsor identifier which maps to the sponsor's backend URL, allowing the app to fetch sponsor-specific settings, branding, and assets at runtime. This architecture reduces operational complexity (one app submission to app stores) while preserving the security boundary between sponsors. Configuration validation ensures the app cannot connect to incomplete or misconfigured backends, and secure token storage prevents unauthorized access to sponsor APIs. The requirement addresses REQ-p00007 (automatic sponsor configuration) and REQ-p00008 (single app architecture) by defining the technical implementation details developers need to build this capability.

## Assertions

A. The mobile application SHALL implement automatic sponsor detection from enrollment tokens without requiring separate app builds per sponsor.
B. The system SHALL parse enrollment tokens to extract sponsor identifiers.
C. The system SHALL map extracted sponsor identifiers to the sponsor's backend URL.
D. The system SHALL fetch sponsor-specific configuration settings from the identified sponsor's backend, including API URL.
E. The system SHALL load sponsor-specific app assets from the sponsor's backend.
F. The system SHALL support runtime sponsor context switching based on the active user session.
G. The system SHALL validate sponsor configuration completeness before establishing backend connection.
H. The system SHALL securely store sponsor-specific authentication tokens.
I. The system SHALL connect to the correct sponsor GCP backend matching the enrollment code.
J. The system SHALL apply sponsor branding after configuration load completes.
K. The system SHALL reject invalid enrollment tokens with clear error messages.
L. The system SHALL NOT leak data across sponsors in configuration storage or authentication mechanisms.
M. The app bundle SHALL contain only masked sponsor URLs.
N. The backend URL SHALL NOT reveal the sponsor or site identity.

*End* *Sponsor Configuration Detection Implementation* | **Hash**: 33d3b6b0
---

### Single App, Multiple Sponsors

**Deployment Model**:
- **One app** on App Store / Google Play Store
- App name: "Clinical Diary" (generic, not sponsor-specific)
- Sponsor detected via enrollment token
- Connects to sponsor's dedicated GCP backend

### Why Single App?

**Benefits**:
- Simplified distribution (one app listing vs many)
- Easier user enrollment (single QR code/link)
- Centralized app updates
- Consistent core functionality
- Reduced maintenance overhead

**Sponsor Isolation**:
- Each sponsor: separate GCP project (Identity Platform + Cloud SQL + Cloud Run)
- No data sharing between sponsors
- Sponsor branding applied post-enrollment
- Authentication tokens scoped to single sponsor

---

## User Enrollment Flow

### Step 1: User Receives Enrollment Token
### Step 2: App Detects Sponsor
### Step 3: Token Validation
### Step 4: User Creates Account
### Step 5: Sponsor Branding Applied

**Visual Customization**:
- App logo --> Sponsor logo
- Study welcome screen content

TODO - we don't have a welcome screen.  Is this shown once with a "don't show again"?
---

## Offline-First Architecture

# REQ-d00004: Local-First Data Entry Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00006

## Rationale

This requirement implements the offline-first architecture mandated by REQ-p00006 at the development level. Clinical trial participants often operate in environments with unreliable network connectivity, making local-first data entry essential for ensuring no diary entries are lost. The implementation uses sembast with Flutter secure local storage to mirror the server's Event Sourcing schema, providing full application functionality without network dependency. Background synchronization processes handle eventual consistency when connectivity is restored, with conflict detection supporting multi-device usage scenarios common in clinical trials.

## Assertions

A. The mobile application SHALL implement offline-first data entry using sembast with Flutter secure local storage.
B. The system SHALL capture all user diary entries locally before network synchronization.
C. The application SHALL provide full diary entry functionality without network connectivity.
D. The sembast database SHALL mirror the server Event Sourcing schema.
E. All diary entry create operations SHALL be saved to local storage first.
F. All diary entry update operations SHALL be saved to local storage first.
G. All diary entry delete operations SHALL be saved to local storage first.
H. The system SHALL trigger background sync processes upon connectivity changes.
I. The system SHALL detect conflicts in multi-device scenarios.
J. The system SHALL resolve conflicts in multi-device scenarios.
K. The system SHALL implement automatic retry logic for failed synchronization attempts.
L. The system SHALL persist local data across app restarts.
M. The sembast database SHALL be created on first app launch.
N. All diary operations SHALL function without network connection.
O. Local changes SHALL sync automatically when network connectivity is available.
P. The conflict resolution mechanism SHALL handle multi-device scenarios.
Q. The system SHALL NOT lose data during offline periods.
R. Background sync processes SHALL respect battery usage constraints.
S. Background sync processes SHALL respect data usage constraints.

*End* *Local-First Data Entry Implementation* | **Hash**: 39589dad
---

### Core Principle

**Local-First, Sync Second**:
- All user actions saved locally **first**
- App fully functional without network
- Background sync when online
- Conflict resolution on sync

**Benefits**:
- Works in areas with poor connectivity
- Instant user experience (no waiting for server)
- Data loss prevention
- Reduces server load

---

### Local Data Storage
**Technology**: sembast (via `sembast` package) and flutter_secure_storage
**Schema** (mirrors server Event Sourcing pattern):

### Background Sync

**Sync Trigger Conditions**:
- App regains network connectivity
- User manually triggers sync
- Every 15 minutes if online TODO - we sync immediately after each change, this is probably not necessary.
- On app resume from background

---

# REQ-d00013: Application Instance UUID Generation

**Level**: Dev | **Status**: Draft | **Implements**: p00006

## Rationale

This requirement supports multi-device conflict resolution for offline-first data entry (REQ-p00006). When patients use multiple devices or reinstall the app, unique device identifiers enable the system to attribute changes to specific app instances, detect multi-device usage patterns, and properly resolve synchronization conflicts. The UUID serves as the device fingerprint in the audit trail, supporting FDA 21 CFR Part 11 compliance by enabling complete traceability of which device generated each data modification.

## Assertions

A. The mobile application SHALL generate a UUID v4 identifier on first launch after installation.
B. The application SHALL use a cryptographically secure random number generator for UUID generation.
C. The application SHALL persist the UUID in device-local secure storage (iOS Keychain on iOS, Android Keystore on Android).
D. The application SHALL retrieve the persisted UUID on all subsequent launches.
E. The application SHALL validate the retrieved UUID on subsequent launches.
F. The application SHALL include the UUID in all event records synchronized to the server via the device_uuid field.
G. The application SHALL generate a new UUID only on fresh installation.
H. The application SHALL NOT generate a new UUID during application updates.
I. The application SHALL preserve the existing UUID across application updates.
J. The application SHALL make the UUID accessible to synchronization logic.
K. The application SHALL make the UUID accessible to conflict resolution logic.
L. The application SHALL include the UUID in all record_audit.device_info JSONB fields.
M. The conflict resolution logic SHALL be able to identify the source device for each change using the UUID.

*End* *Application Instance UUID Generation* | **Hash**: 5a81d46b
---

### Conflict Resolution

**Conflict Detection**:
CONFLICT-1: 
scenario: user installs App on new device, doesn't have local copy of data
scenario: user uses more than one device to make entries
trigger: Server `record_state.version` > local version
resolution: fast-forward local-db: replay server events locally

TODO - there is no conflict described. 

CONFLICT-2: 
scenario: user uses more than one device to make entries, modifies same entry on both before they are detected via CONFLICT-1
trigger: non-fast-forward conflict
resolution: prompt user to choose one

CONFLICT-3: 
scenario: investigator modifies entry through portal
trigger: `event_uudi` modified by non-patient, fast-forward-able
resolution: push event(s) to App, replay event(s), notify patient, patient dismisses notification

CONFLICT-4: 
scenario: different data values without appropriate event(s) TODO - this is not clear
trigger:  when record is `locked` (made soft-read-only), compare its record_status with remote record_status and there is a meaningful mismatch (aside from metadata)
resolution: Log error. Report to investigator.

---

## User Interface

### Main Screens

**1. Enrollment Screen**:
- Scan QR code or paste enrollment link
- Token validation
- Terms of service / consent

**2. Login Screen**:
  Account creation (email + password)

**3. Home / Dashboard**:
- Today's diary entries summary
- Quick add button
- Sync status indicator

**4. Create/Edit Diary Entry**:
- Date and time picker
- Event type selection (sponsor-configured) - TODO - what's this?
- Custom fields based on study protocol
- Save button (saves locally, syncs in background)
- Validation with clear error messages

**4. History View**:
- Calendar view by month -> list view by day -> detailed view -> edit option

**5. Annotations View** (if investigator adds annotation/changes record):
- Notification badge
- View annotation / change
- Mark as resolved

TODO - this needs clarity

**6. Profile / Settings**:
- User information (local only - never sync'd)  TODO???
- Study information 
- Sync status and manual sync button
- Notification settings
- Preferences & Accessibility
- Logout

---

## Security Features
### Data Encryption

**Encryption at Rest**
**Secure Key Storage**
**Encrypted data transfer**

---

## Data Export and Import

# REQ-d00085: Local Database Export and Import

**Level**: Dev | **Status**: Draft | **Implements**: p01062

## Rationale

This requirement implements GDPR data portability (Article 20) at the development level, ensuring patients can obtain their clinical diary data in a structured, commonly used, and machine-readable format. Local-only operation ensures data portability works regardless of network connectivity or server availability, addressing scenarios where patients may switch devices, need offline backups, or exercise their right to data portability under GDPR. The requirement supports patient autonomy and regulatory compliance by enabling self-service data extraction and restoration.

## Assertions

A. The system SHALL provide a database export function that serializes sembast diary tables to a JSON file.
B. The export JSON schema SHALL include diary entries, timestamps, event types, and user-entered values.
C. The system SHALL save exported files to device storage with user-selectable location via Downloads or share sheet.
D. The system SHALL provide a database import function that parses JSON files and inserts records into the local sembast database.
E. The system SHALL validate imported data structure and integrity before insertion.
F. The system SHALL handle conflicts when importing data that overlaps with existing records by skipping duplicates based on event_uuid.
G. The system SHALL provide progress indication for large export and import operations.
H. Export and import operations SHALL operate entirely offline without requiring network connectivity.
I. Exported files SHALL use the single JSON file format with a schema version header.
J. Exported files SHALL use the .diary-export.json file extension.
K. The system SHALL NOT include sync_status, device_uuid, or pending_events tables in exported files.
L. The import merge strategy SHALL skip duplicate records identified by event_uuid and insert new records only.
M. The system SHALL use the file_picker package for cross-platform file selection during import.
N. The system SHALL use the share_plus package for share sheet export functionality.
O. The export button SHALL be accessible from the Settings screen.
P. The export function SHALL create valid JSON files containing all diary entries.
Q. The system SHALL enable sharing of exported files via the system share sheet.
R. The import button SHALL be accessible from the Settings screen.
S. The import function SHALL successfully restore diary entries from valid export files.
T. The system SHALL reject malformed or incompatible import files with a clear error message.
U. The system SHALL complete export and import operations for datasets containing 1000 or more entries within 30 seconds.

*End* *Local Database Export and Import* | **Hash**: eaa18d27
---

## Deployment & Distribution

# REQ-d00006: Mobile App Build and Release Process

**Level**: Dev | **Status**: Draft | **Implements**: o00010

## Rationale

This requirement defines the mobile app build and release process that implements the operational release process (o00010) at the development level. Flutter's cross-platform compilation enables a single codebase to be deployed across iOS, Android, and web platforms, while bundled configurations allow sponsor switching at runtime without requiring per-sponsor builds. This approach ensures consistent app distribution across the iOS App Store and Google Play Store while maintaining sponsor isolation through runtime configuration selection rather than separate app builds.

## Assertions

A. The system SHALL build the mobile application as a single app package containing configurations for all sponsors.
B. The build process SHALL produce artifacts for iOS, Android, and web platforms from a single Flutter codebase.
C. The system SHALL increment version numbers following semantic versioning for each release.
D. The build process SHALL sign iOS artifacts with Apple Developer certificates.
E. The build process SHALL sign Android artifacts with Google Play certificates.
F. The system SHALL provide an automated build pipeline that generates release artifacts.
G. The build pipeline SHALL validate that no sponsor-specific information appears in store listings before release.
H. The mobile application SHALL perform runtime app version checking to inform users of available updates.
I. The system SHALL automatically perform version checks daily when the application is used.
J. The system SHALL define a minimum required version for the mobile application.
K. The system SHALL force users to upgrade when their installed version is lower than the minimum required version.
L. A single build SHALL produce both iOS and Android artifacts.
M. The build artifacts SHALL include all sponsor configurations.
N. The mobile application SHALL pass iOS App Store review processes.
O. The mobile application SHALL pass Google Play Store review processes.
P. Version numbers SHALL be synchronized across iOS, Android, and web platforms.
Q. Store listings SHALL NOT contain sponsor-specific branding.
R. The build pipeline SHALL validate configuration completeness before producing release artifacts.

*End* *Mobile App Build and Release Process* | **Hash**: 3b07a626
---

### App Store Listing

**App Name**: Daily Diary

**Description**:
> Keep a daily log of your sypmptoms. Share with your doctor and others.
> Supports synchronization with clinical trials and studies.
> Use your enrollment token from your coordinator to get started.

**Keywords**: clinical trial, patient diary, health tracking, medical research

**Screenshots**: Generic (no sponsor-specific branding in store listing)

---


## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Architecture**: prd-database.md
- **Security Architecture**: prd-security.md
- **FDA Compliance**: prd-clinical-trials.md
- **Flutter Documentation**: https://flutter.dev/docs
- **Identity Platform Flutter**: https://firebase.google.com/docs/auth/flutter/start
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-01-24 | Initial mobile app specification | Development Team |
| 2.0 | 2025-11-24 | Updated for GCP backend | Development Team |

---

**Document Classification**: Internal Use - Product Requirements
**Review Frequency**: Quarterly or when adding new sponsors
**Owner**: Product Team / Mobile Development Lead
