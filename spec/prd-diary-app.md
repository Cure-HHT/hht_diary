# Clinical Diary Mobile Application

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: prd-system.md for platform overview
> **See**: dev-app.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for overall architecture
> **See**: prd-security.md for security architecture

---

# REQ-p00043: Clinical Diary Mobile Application

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

The mobile application serves dual purposes: personal health tracking for individual users and compliant data capture for clinical trials. Personal use mode prioritizes privacy and simplicity by requiring no account and storing data locally only. Enrolled use mode enables cloud synchronization for clinical trials and observational studies while maintaining FDA 21 CFR Part 11 compliance. The single-app multi-sponsor architecture simplifies distribution through public app stores while ensuring complete data isolation between sponsors through enrollment-based configuration.

## Assertions

A. The system SHALL provide a smartphone application for iOS platforms.
B. The system SHALL provide a smartphone application for Android platforms.
C. The system SHALL enable users to record daily health observations.
D. The system SHALL support local-first data entry for all diary operations as specified in REQ-p70000.
E. The system SHALL support personal use mode with local-only storage.
F. The system SHALL support enrolled use mode with cloud synchronization to study database.
G. The system SHALL NOT require account creation for personal use mode.
H. The system SHALL store all personal use mode data locally on device only.
I. The system SHALL NOT transmit personal use mode data over network for storage purposes.
J. The system SHALL enable enrollment via sponsor-provided enrollment link.
K. The system SHALL enable enrollment via CureHHT observational study.
L. The system SHALL automatically synchronize enrolled user data to study database when online.
M. The system SHALL support multi-sponsor deployments with automatic configuration based on enrollment link.
N. The system SHALL apply sponsor-specific branding for enrolled users based on their enrollment.
O. The system SHALL apply sponsor-specific customization for enrolled users based on their enrollment.
P. The system SHALL maintain FDA 21 CFR Part 11 compliant audit trails for enrolled users.
Q. The system SHALL NOT maintain audit trails for personal use mode users.
R. The system SHALL synchronize existing local data to study database upon user enrollment.
S. The system SHALL maintain complete data isolation between sponsors.
T. The system SHALL be available via iOS app store.
U. The system SHALL be available via Android app store.
V. The system SHALL support offline operation for core diary operations in personal use mode.
W. The system SHALL support offline operation for core diary operations in enrolled use mode.

*End* *Clinical Diary Mobile Application* | **Hash**: aedbfb5a

---

## Local Data Storage

# REQ-p70000: Local Data Storage

**Level**: PRD | **Status**: Draft | **Implements**: p00043

## Rationale

This requirement establishes a privacy-first architecture where patient data remains exclusively on the user's device during personal use, eliminating the need for user accounts, authentication systems, or cloud infrastructure. This approach minimizes privacy risks and regulatory complexity for casual users while providing an optional upgrade path through study enrollment for users who desire data backup and recovery. The design acknowledges the trade-off between privacy and data durability, ensuring users make informed decisions about their data storage preferences.

## Assertions

A. The system SHALL store all patient data locally on the device by default.
B. The system SHALL NOT require account creation for personal use.
C. The system SHALL NOT require user login for personal use.
D. The system SHALL NOT require cloud backup for personal use.
E. The system SHALL store all diary entries locally on the device immediately upon creation.
F. The system SHALL NOT perform cloud synchronization until the user enrolls in a study.
G. The system SHALL support single device usage only in personal use mode.
H. The system SHALL NOT support multiple device synchronization in personal use mode.
I. The system SHALL display a clear warning to users during onboarding that data loss will occur if the device is lost or damaged in personal use mode.
J. The system SHALL function fully without account creation.
K. The system SHALL function fully without user login.
L. The system SHALL NOT make network requests for data storage in personal use mode.
M. The system SHALL NOT require user credentials in personal use mode.
N. The system SHALL persist data across app restarts.
O. The system SHALL persist data across app updates.
P. The system SHALL provide users the option to enroll in the CureHHT observational study to enable cloud backup.
Q. The system SHALL provide users the option to enroll in clinical trials via enrollment link.
R. The system SHALL synchronize existing local data to the study database after user enrollment.
S. The system SHALL NOT automatically enroll users in any study.
T. The system SHALL require user-initiated action for study enrollment.
U. The system SHALL back up enrolled users' data through study database synchronization.

*End* *Local Data Storage* | **Hash**: af5c0a9d

---

## Executive Summary

The Clinical Diary mobile application is a smartphone app for iOS and Android that allows users to record daily health observations. The app supports two usage modes:

**Personal Use**: Download and use immediately with no account required. All data stored locally on device. Ideal for personal health tracking.

**Enrolled Use**: Join a clinical trial or CureHHT observational study to gain cloud backup and contribute to research. Automatic synchronization keeps data safe.

**Key Benefits**:
- Works without internet connection (both modes)
- No account required for personal use
- Cloud backup available through study enrollment
- Single app serves all clinical trial sponsors
- Secure and compliant with FDA regulations (enrolled users)
- Personalized with sponsor branding (enrolled users)

---

## How It Works

# REQ-p00007: Automatic Sponsor Configuration

**Level**: PRD | **Status**: Draft | **Implements**: p00043, p00001

## Rationale

This requirement simplifies patient enrollment and prevents enrollment errors by automating sponsor and study configuration. Patients should not need to understand technical concepts like 'sponsor' or navigate complex study selection menus. Automatic configuration based on enrollment link ensures patients always connect to the correct study while maintaining sponsor isolation as required by REQ-p00001. The enrollment link serves as the single source of truth for patient-sponsor-study binding, eliminating manual selection errors and ensuring proper sponsor isolation from the patient's first interaction with the app.

## Assertions

A. The app SHALL automatically configure sponsor and study settings based on the enrollment link provided to the patient.
B. The enrollment link SHALL contain sponsor and study identification information.
C. The app SHALL read enrollment information from the link and connect to the correct sponsor system.
D. The app SHALL load sponsor branding and configuration automatically upon enrollment.
E. The app SHALL NOT require patients to manually select a sponsor from a list.
F. The app SHALL NOT provide any mechanism for patients to enroll in an incorrect study.
G. Each patient SHALL receive a single unique enrollment link or QR code.
H. The app SHALL determine sponsor and study configuration from the enrollment link alone without additional patient input.
I. The app SHALL display the correct sponsor branding immediately after processing the enrollment link.
J. The app SHALL NOT allow patients to switch to a different sponsor after enrollment is completed.
K. The app SHALL reject invalid enrollment links with a clear error message.
L. The app SHALL reject expired enrollment links with a clear error message.

*End* *Automatic Sponsor Configuration* | **Hash**: 5498f554
---

TODO - this needs another spec #

### Daily Use

**Recording Entries**:
- Patients open the app and tap to create a new entry
  - TODO - Is this spec testable?
- App presents questions or forms based on the study protocol
  - TODO - needs details
- Entries are saved immediately on the phone
- Internet connection not required

**Viewing History**:
- Patients can see all their previous entries
  - Can they also see their previous forms?
- Calendar view shows which days have entries
- Search and filter to find specific entries
  - TODO - on what criteria?

**Syncing Data**:
- App automatically uploads entries when online
- Sync indicator shows current status
- Works in background - patients don't need to wait

---

## Offline Capability

# REQ-p00006: Offline-First Data Entry

**Level**: PRD | **Status**: Draft | **Implements**: p00043, p70000

## Rationale

Offline-first architecture ensures reliable data collection regardless of network conditions, a critical requirement for patient-facing clinical trial applications. All users benefit from local storage for immediate, reliable data entry. For patients enrolled in clinical trials or observational studies, automatic synchronization provides cloud backup and enables remote monitoring while maintaining the offline-first user experience. Personal use patients operate in a purely local mode with no cloud synchronization.

## Assertions

A. The system SHALL allow patients to create diary entries without requiring internet connectivity.
B. The system SHALL store all diary entries locally on the device immediately upon creation.
C. The system SHALL allow patients to edit diary entries without requiring internet connectivity.
D. The system SHALL allow patients to view their complete entry history without requiring internet connectivity.
E. The system SHALL provide full core diary functionality without internet access.
F. The system SHALL preserve all diary entries if the app closes unexpectedly.
G. The system SHALL clearly indicate to enrolled patients which entries have not yet synchronized to the study database.
H. The system SHALL automatically synchronize unsynchronized entries to the study database when network connectivity becomes available for enrolled users.
I. The system SHALL preserve all unsynchronized entries if the app closes before synchronization completes.
J. The system SHALL NOT synchronize diary entries to any study database for patients not enrolled in a study.
K. The system SHALL activate synchronization only after a user enrolls in a study as defined in REQ-p70000.

*End* *Offline-First Data Entry* | **Hash**: 438d5f2d
---

## Multi-Sponsor Support

### One App, All Sponsors

A single "Clinical Diary" app on app stores or one web url serves all pharmaceutical sponsors:

**Benefits for Patients**:
- Simple enrollment - just one app to find and download, only one web url
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
- Secure authentication required - TODO How secure? 2FA required? Biometrics?
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

**Support**: Clear help text and guidance throughout #TODO - needs details.

---

## Temporal Entry Validation

# REQ-p00050: Temporal Entry Validation

**Level**: PRD | **Status**: Draft | **Implements**: p00043

## Rationale

Temporal validation ensures data reflects actual events and prevents logical impossibilities such as future events, overlapping nosebleeds, or entries predating app usage. This maintains clinical trial data quality and integrity. Capturing reasons for delayed entries helps researchers understand data quality patterns and patient adherence behavior, which is critical for interpreting trial results.

## Assertions

A. The system SHALL disable selection of future dates in the calendar view.
B. The system SHALL restrict the date picker to current date and earlier dates only.
C. The system SHALL set the maximum selectable date in the calendar to the current date.
D. The system SHALL restrict end time selection to times that do not exceed the current real time.
E. The system SHALL visually disable or gray out future dates in the calendar view.
F. The system SHALL visually disable or gray out future times in the time picker.
G. The system SHALL validate that end time is greater than or equal to start time.
H. The system SHALL validate that end time is less than or equal to current time.
I. The system SHALL update the current time dynamically if the user keeps the time picker open.
J. The system SHALL enforce diary start day boundaries as specified in REQ-p01039.
K. The system SHALL prevent creation of entries before the diary start day.
L. The system SHALL visually distinguish dates before the diary start day as specified in REQ-p01040.
M. The system SHALL display a reason selection prompt when an entry date/time is more than 24 hours in the past.
N. The system SHALL provide predefined reason options including: 'I forgot to record it at the time', 'I didn't have access to the app', 'I was in a medical facility', 'Technical issues with the app', and 'Other (specify)'.
O. The system SHALL require the user to select a reason before proceeding with creation of entries more than 24 hours old.
P. The system SHALL store the selected delay reason with the entry metadata.
Q. The system SHALL validate entries for time overlaps before saving.
R. The system SHALL validate both new and edited entries for time overlaps.
S. The system SHALL display an error message identifying the conflicting entry when a time overlap is detected, including the start and end times of the conflicting record.
T. The system SHALL allow the user to navigate to view the conflicting record when a time overlap is detected.
U. The system SHALL require confirmation when creating entries less than 2 minutes old.

*End* *Temporal Entry Validation* | **Hash**: 0dff6cc4

---

## Diary Start Day

# REQ-p01039: Diary Start Day Definition

**Level**: PRD | **Status**: Draft | **Implements**: p00043, p00050

## Rationale

Clinical trial participants may need to record nosebleeds that occurred before their first app usage. By defaulting the start day to the day before the first entry, users immediately see that they can record past events. This feature demonstrates to users that they can backfill historical data while maintaining reasonable temporal boundaries for data quality. The one-year limit prevents unreliable retrospective data entry while still accommodating patients who want to capture recent history. The diary start day establishes a temporal boundary that balances the need for historical data capture with the requirement to maintain reliable, high-quality clinical trial data.

## Assertions

A. The system SHALL establish and maintain a diary start day representing the earliest date for which diary entries are valid.
B. The system SHALL set the default diary start day to one day before the date of the first diary entry created.
C. The system SHALL allow users to implicitly override the start day by selecting an earlier date and creating an entry.
D. The system SHALL NOT allow the start day to be set to a future date.
E. The system SHALL NOT allow the start day to be set earlier than 365 days before app installation on the current device.
F. The system SHALL persist the start day across app sessions in the local database.
G. The system SHALL sync the start day to the study database for enrolled users.
H. The system SHALL automatically update the start day when a user creates an entry for a date before the current start day.
I. The system SHALL move the start day backward (earlier) but SHALL NOT move it forward (later) once set.
J. The system SHALL display a confirmation message when the start day is being extended, showing the new date and requesting user confirmation.
K. The system SHALL disable calendar dates more than 365 days before app installation.
L. The system SHALL render dates before the start day as visually distinct but selectable in the calendar view.
M. The system SHALL display an error message if a user attempts to create an entry beyond the 365-day limit.
N. The system SHALL restore the start day correctly after app reinstallation for enrolled users from cloud backup.
O. The system SHALL NOT provide cloud backup of the start day for personal use mode.
P. The system SHALL NOT explicitly prompt users to set the start day during onboarding.

*End* *Diary Start Day Definition* | **Hash**: fe48ad66

---

## Calendar Visual Indicators

# REQ-p01040: Calendar Visual Indicators for Entry Status

**Level**: PRD | **Status**: Draft | **Implements**: p00043, p01039

## Rationale

Users need clear visual feedback to understand their diary history at a glance. The calendar view must distinguish between four date states: dates with recorded entries, dates within the active diary period with no entries, dates before the diary start, and future dates. Showing dates within the diary period that have no entries as distinctively marked communicates that those days were part of the diary period but had no nosebleeds recorded—valuable clinical information. This visual distinction helps patients identify gaps in their records and provides researchers with insight into both recorded events and recorded absence of events. Accessibility considerations ensure all users, including those with color vision deficiencies, can interpret the calendar status indicators.

## Assertions

A. The system SHALL display dates with diary entries highlighted with the sponsor theme color using a filled dot or colored background.
B. The system SHALL display dates with no entries within the diary period (from start day to yesterday) marked in black or dark color.
C. The system SHALL display dates before the diary start day as grayed out and visually muted.
D. The system SHALL display future dates as grayed out and disabled such that they are not selectable.
E. The system SHALL distinguish the current date from other dates using an outline or other visual treatment.
F. The system SHALL display a filled indicator (dot, badge, or colored background) on days with one or more entries.
G. The system SHALL display a count badge or multiple indicator on days with multiple entries.
H. The system SHALL render entry indicators using colors that match the sponsor branding theme.
I. The system SHALL display entry status indicators without requiring user interaction such as hover or tap.
J. The system SHALL display a dark or black indicator on days from start day through yesterday that have no entries.
K. The system SHALL ensure the dark indicator for no-entry days is clearly distinguishable from indicators for days with entries.
L. The system SHALL display today with neutral styling until end of day, after which it becomes a no-entry indicator if no entries were recorded.
M. The system SHALL ensure clear visual distinction between outside diary period dates (gray) and no-entry recorded dates (black or dark).
N. The system SHALL supplement color indicators with icons or patterns to support colorblind users.
O. The system SHALL use diagonal stripe patterns for dates before start date and dates after today.
P. The system SHALL maintain sufficient contrast ratios for all visual states to meet accessibility standards.
Q. The system SHALL announce entry status via screen reader when users navigate the calendar.
R. The system SHALL allow sponsors to define accessible fonts via sponsor feature set configuration.
S. The system SHALL allow users to select accessible fonts via user preferences.

*End* *Calendar Visual Indicators for Entry Status* | **Hash**: ae8a494b

---

## References

- **Platform**: prd-system.md
- **Implementation**: dev-app.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md
- **Database**: prd-database.md
- **Compliance**: prd-clinical-trials.md
