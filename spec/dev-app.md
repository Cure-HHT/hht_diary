# Clinical Diary Mobile Application

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for overall architecture
> **See**: prd-database.md for data architecture
> **See**: prd-security.md for security architecture

---

## Executive Summary

The Clinical Diary mobile application is a **Flutter-based cross-platform app** (iOS and Android) that implements an offline-first architecture with multi-sponsor support. A single app deployed to app stores contains configurations for ALL sponsors, with sponsor detection via enrollment tokens.

**Key Features**:
- Single app supports multiple clinical trial sponsors
- Offline-first with automatic background sync
- Event Sourcing for complete audit trail
- Sponsor-specific branding and configuration
- Secure connection to sponsor's GCP backend (Cloud SQL + Identity Platform)
- FDA 21 CFR Part 11 compliant data capture

**Technology Stack**:
- **Framework**: Flutter (single codebase � iOS + Android)
- **Language**: Dart
- **Backend**: GCP (Cloud SQL + Identity Platform + Cloud Run per sponsor)
- **Local Storage**: SQLite via sqflite package
- **State Management**: Riverpod
- **Networking**: Firebase Auth SDK + HTTP client for Cloud Run API

---

## Multi-Sponsor Architecture

# REQ-d00005: Sponsor Configuration Detection Implementation

**Level**: Dev | **Implements**: p00007, p00008 | **Status**: Active

The mobile application SHALL implement automatic sponsor detection and configuration loading based on enrollment tokens, enabling a single app binary to support multiple sponsors without requiring separate app builds per sponsor.

Implementation SHALL include:
- Enrollment token parser extracting sponsor identifier
- Configuration loader fetching sponsor-specific settings (GCP project ID, Firebase config, API URL, branding assets)
- Runtime sponsor context switching based on active user session
- Bundled sponsor configurations in app assets
- Validation of sponsor configuration completeness before connection
- Secure storage of sponsor-specific authentication tokens

**Rationale**: Implements automatic sponsor configuration (p00007) and single app architecture (p00008) at the development level. Token-based sponsor detection enables streamlined user enrollment while maintaining complete data isolation between sponsors.

**Acceptance Criteria**:
- Enrollment token correctly identifies sponsor
- Sponsor configuration loaded from bundled assets
- App connects to correct sponsor GCP backend
- Sponsor branding applied after configuration load
- Invalid tokens rejected with clear error messages
- No cross-sponsor data leakage in configuration or authentication

*End* *Sponsor Configuration Detection Implementation* | **Hash**: d43b407d
---

### Single App, Multiple Sponsors

**Deployment Model**:
- **One app** on App Store / Google Play Store
- App name: "Clinical Diary" (generic, not sponsor-specific)
- Contains **ALL** sponsor configurations bundled in app
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
- Each sponsor: separate GCP project (Cloud SQL + Identity Platform)
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

---

## Offline-First Architecture

# REQ-d00004: Local-First Data Entry Implementation

**Level**: Dev | **Implements**: p00006 | **Status**: Active

The mobile application SHALL implement offline-first data entry using SQLite for local storage, ensuring all user diary entries are captured locally before network synchronization, enabling full functionality without network connectivity.

Implementation SHALL include:
- SQLite database mirroring server Event Sourcing schema
- All diary entry operations (create, update, delete) saved locally first
- Background sync process triggered by connectivity changes
- Conflict detection and resolution for multi-device scenarios
- Automatic retry logic for failed synchronization attempts
- Local data persistence across app restarts

**Rationale**: Implements offline-first architecture (p00006) at the development level. Flutter's sqflite package provides SQLite access for local-first data storage, enabling clinical trial participants to record diary entries regardless of network availability.

**Acceptance Criteria**:
- SQLite database created on first app launch
- All diary operations work without network connection
- Local changes sync automatically when online
- Conflict resolution handles multi-device scenarios
- No data loss during offline periods
- Background sync respects battery and data usage constraints

*End* *Local-First Data Entry Implementation* | **Hash**: 843d0664
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
**Technology**: SQLite (via `sqflite` package)
**Schema** (mirrors server Event Sourcing pattern):

### Background Sync

**Sync Trigger Conditions**:
- App regains network connectivity
- User manually triggers sync
- Every 15 minutes if online
- On app resume from background

---

# REQ-d00013: Application Instance UUID Generation

**Level**: Dev | **Implements**: p00006 | **Status**: Active

The mobile application SHALL generate and persist a unique instance identifier (UUID v4) on first launch after installation, enabling device-level attribution in audit trails and multi-device conflict resolution.

Implementation SHALL include:
- UUID v4 generation on first app launch using cryptographically secure random number generator
- Persistent storage of UUID in device-local secure storage (iOS Keychain / Android Keystore)
- UUID included in all event records synchronized to server (`device_uuid` field)
- UUID retrieval and validation on subsequent app launches
- New UUID generation only on fresh installation (not on app updates)
- UUID accessible to sync and conflict resolution logic

**Rationale**: Implements multi-device conflict resolution aspect of offline-first data entry (p00006). When patients use multiple devices or reinstall the app, unique device identifiers enable the system to attribute changes to specific app instances, detect multi-device usage patterns, and properly resolve synchronization conflicts. The UUID serves as the device fingerprint in the audit trail.

**Acceptance Criteria**:
- UUID generated once on first launch using `uuid` Dart package
- Same UUID retrieved on all subsequent launches
- UUID persisted in `flutter_secure_storage` (survives app restarts)
- New installation generates different UUID
- App update preserves existing UUID
- UUID included in all `record_audit.device_info` JSONB fields
- Conflict resolution logic can identify source device for each change

*End* *Application Instance UUID Generation* | **Hash**: 447e987e
---

### Conflict Resolution

**Conflict Detection**:
CONFLICT-1: 
scenario: user installs App on new device, doesn't have local copy of data
scenario: user uses more than one device to make entries
trigger: Server `record_state.version` > local version
resolution: fast-forward local-db: replay server events locally

CONFLICT-2: 
scenario: user uses more than one device to make entries, modifies same entry on both before they are detected via CONFLICT-1
trigger: non-fast-forward conflict
resolution: prompt user to choose one

CONFLICT-3: 
scenario: investigator modifies entry through portal
trigger: `event_uudi` modified by non-patient, fast-forward-able
resolution: push event(s) to App, replay event(s), notify patient, patient dismisses notification

CONFLICT-4: 
scenario: different data values without appropriate event(s)
trigger:  when record is `locked` (made soft-read-only), compare its record_status with remote record_status and there is a meaningful mismatch (aside from metadata)
resolution: Log error. Report to investigator.

---

## User Interface

### Main Screens

**1. Enrollment Screen**:
- Scan QR code or paste enrollment link
- Token validation
- Account creation (email + password)
- Terms of service / consent

**2. Home / Dashboard**:
- Today's diary entries summary
- Quick add button
- Sync status indicator

**3. Create/Edit Diary Entry**:
- Date and time picker
- Event type selection (sponsor-configured)
- Custom fields based on study protocol
- Save button (saves locally, syncs in background)
- Validation with clear error messages

**4. History View**:
- Calendar view by month -> list view by day -> detailed view -> edit option

**5. Annotations View** (if investigator adds annotation/changes record):
- Notification badge
- View annotation / change
- Mark as resolved

**6. Profile / Settings**:
- User information (local only - never sync'd)
- Study information 
- Sync status and manual sync button
- Notification settings
- Logout

---

## Security Features
### Data Encryption

**Encryption at Rest**
**Secure Key Storage**
**Encrypted data transfer**

---

## Deployment & Distribution

# REQ-d00006: Mobile App Build and Release Process

**Level**: Dev | **Implements**: o00010 | **Status**: Active

The mobile application SHALL be built and released as a single app package containing configurations for all sponsors, ensuring consistent app distribution across iOS App Store and Google Play Store while maintaining sponsor isolation.

Build process SHALL include:
- Single Flutter codebase compiled for iOS and Android platforms
- All sponsor configurations bundled in app assets at build time
- Version number incremented following semantic versioning
- Code signing with platform-specific certificates (iOS: Apple Developer, Android: Google Play)
- Automated build pipeline generating release artifacts
- Pre-release validation ensuring no sponsor-specific information in store listings

**Rationale**: Implements mobile app release process (o00010) at the development level. Flutter's cross-platform compilation enables single codebase deployment, while bundled configurations allow sponsor switching at runtime without requiring per-sponsor builds.

**Acceptance Criteria**:
- Single build produces both iOS and Android artifacts
- All sponsor configurations included in build artifacts
- App passes platform-specific review processes
- Version numbers synchronized across platforms
- No sponsor-specific branding in store listings
- Build pipeline validates configuration completeness

*End* *Mobile App Build and Release Process* | **Hash**: 6dfe9c2d
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
- **Firebase Auth Flutter**: https://firebase.google.com/docs/auth/flutter/start
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
