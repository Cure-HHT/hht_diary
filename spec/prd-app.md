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
- Secure connection to sponsor's Supabase instance
- FDA 21 CFR Part 11 compliant data capture

**Technology Stack**:
- **Framework**: Flutter (single codebase � iOS + Android)
- **Language**: Dart
- **Backend**: Supabase (per sponsor)
- **Local Storage**: SQLite via sqflite package
- **State Management**: Riverpod
- **Networking**: Supabase client for Dart

---

## Multi-Sponsor Architecture

### Single App, Multiple Sponsors

**Deployment Model**:
- **One app** on App Store / Google Play Store
- App name: "Clinical Diary" (generic, not sponsor-specific)
- Contains **ALL** sponsor configurations bundled in app
- Sponsor detected via enrollment token
- Connects to sponsor's dedicated Supabase instance


### Why Single App?

**Benefits**:
- Simplified distribution (one app listing vs many)
- Easier user enrollment (single QR code/link)
- Centralized app updates
- Consistent core functionality
- Reduced maintenance overhead

**Sponsor Isolation**:
- Each sponsor: separate Supabase project (database + auth)
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
- **Supabase Flutter Client**: https://supabase.com/docs/reference/dart/introduction

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-24 | Initial mobile app specification | Development Team |

---

**Document Classification**: Internal Use - Product Requirements
**Review Frequency**: Quarterly or when adding new sponsors
**Owner**: Product Team / Mobile Development Lead
