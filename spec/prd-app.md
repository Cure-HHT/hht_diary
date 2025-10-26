# Clinical Diary Mobile Application

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: dev-app.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for overall architecture
> **See**: prd-security.md for security architecture

---

## Executive Summary

The Clinical Diary mobile application is a smartphone app for iOS and Android that allows clinical trial patients to record daily health observations. The app works offline and automatically syncs data when internet is available, ensuring patients can make entries anytime, anywhere.

**Key Benefits**:
- Single app serves all clinical trial sponsors
- Works without internet connection
- Automatic data synchronization
- Secure and compliant with FDA regulations
- Personalized with sponsor branding

---

## How It Works

### REQ-p00007: Automatic Sponsor Configuration

**Level**: PRD | **Implements**: p00001 | **Status**: Active

The app SHALL automatically configure itself for the correct sponsor and study based on the enrollment link provided to the patient, eliminating manual sponsor/study selection.

Automatic configuration SHALL ensure:
- Enrollment link contains sponsor and study identification
- App reads enrollment information and connects to correct sponsor system
- Sponsor branding and configuration loaded automatically
- Patient never manually selects sponsor from list
- No opportunity for patient to enroll in wrong study

**Rationale**: Simplifies patient enrollment and prevents enrollment errors. Patients should not need to understand technical concepts like "sponsor" or navigate complex study selection menus. Automatic configuration based on enrollment link ensures patients always connect to the correct study while maintaining sponsor isolation (p00001).

**Acceptance Criteria**:
- Single enrollment link/QR code provided per patient
- App determines sponsor and study from link alone
- Correct sponsor branding displayed immediately after enrollment
- Patient cannot switch to different sponsor after enrollment
- Invalid or expired enrollment links rejected with clear error message

---

### Daily Use

**Recording Entries**:
- Patients open the app and tap to create a new entry
- App presents questions or forms based on the study protocol
- Entries are saved immediately on the phone
- Internet connection not required

**Viewing History**:
- Patients can see all their previous entries
- Calendar view shows which days have entries
- Search and filter to find specific entries

**Syncing Data**:
- App automatically uploads entries when online
- Sync indicator shows current status
- Works in background - patients don't need to wait

---

## Offline Capability

### REQ-p00006: Offline-First Data Entry

**Level**: PRD | **Implements**: - | **Status**: Active

Patients SHALL be able to record diary entries without requiring internet connectivity, ensuring clinical trial participation is not dependent on network availability.

Offline capability SHALL ensure:
- Diary entries saved locally on device immediately upon creation
- Entries synchronized to central database when network connection available
- Patients can view their complete entry history offline
- App functions normally without internet access for core diary operations

**Rationale**: Clinical trial participants may have limited or intermittent internet access (hospital basements, rural areas, poor cell coverage). Offline capability removes connectivity as a barrier to participation and ensures patients can always make scheduled diary entries at the required times.

**Acceptance Criteria**:
- Patients can create, edit, and view diary entries with no network connection
- Unsynchronized entries clearly indicated to patient
- Automatic synchronization when network becomes available
- No data loss if app closed before synchronization completes
- Conflict resolution when same entry modified on multiple devices

---

## Multi-Sponsor Support

### One App, All Sponsors

A single "Clinical Diary" app on app stores serves all pharmaceutical sponsors:

**Benefits for Patients**:
- Simple enrollment - just one app to find and download
- Consistent user experience across studies
- Automatic updates and improvements

**Benefits for Sponsors**:
- Custom branding automatically applied
- Complete data isolation between sponsors
- Independent study configurations
- No cross-contamination of data

### Sponsor Customization

Each sponsor can customize:
- Logo and company colors
- Welcome screens and instructions
- Custom questionnaires
- Study-specific features

Patients see only their sponsor's information - the app adapts automatically.

---

## Security and Compliance

**Patient Data Protection**:
- Data encrypted on phone and during transmission
- Secure authentication required
- Each sponsor's data completely isolated
- No sharing of information between studies

**FDA Compliance**:
- Complete audit trail of all changes
- Tamper-evident record keeping
- Meets FDA 21 CFR Part 11 requirements

**See**: prd-security.md for security details
**See**: prd-clinical-trials.md for compliance requirements

---

## User Experience Priorities

**Simplicity**: App designed for easy daily use without training

**Reliability**: Offline-first ensures entries never lost

**Privacy**: Only patient can see their own data

**Support**: Clear help text and guidance throughout

---

## References

- **Implementation**: dev-app.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md
- **Database**: prd-database.md
- **Compliance**: prd-clinical-trials.md
