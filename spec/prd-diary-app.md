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

**Level**: PRD | **Implements**: p00044 | **Status**: Draft

A smartphone application for iOS, Android and the web (TODO - need to validate web security) enabling clinical trial patients to record daily health observations with offline capability and automatic synchronization.

Mobile application SHALL provide:
- Offline-first data entry for all diary operations
- Automatic data synchronization when network available 
  - TODO - to where?  CureHHT is the default sponsor until enrollment?  Do old records sync?  Do new records sync to both?
  - Sponsors may want "Record" button disabled until enrollment, what about a user that already is using the app with CureHHT?
- Multi-sponsor support with automatic configuration
- Sponsor-specific branding and customization
- FDA 21 CFR Part 11 compliant audit trails
- TODO 
- User's Guide?  
- Chat Support? 
- Contact with study personnel
- Upgrades - automatic? On choice/forced?
- Observability - can the app report errors, metrics, logs to a server?

**Rationale**: Provides the patient-facing interface for clinical trial data capture, designed for ease of use regardless of connectivity. Single app serving all sponsors simplifies distribution and maintenance while maintaining complete data isolation.

**Acceptance Criteria**:
- Available on iOS and Android app stores
- Functions offline for core diary operations
- Automatic data synchronization when online
- Sponsor branding applied per enrollment
- Complete audit trail of all patient actions

*End* *Clinical Diary Mobile Application* | **Hash**: 2a543266

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

# REQ-p00007: Automatic Sponsor Configuration

**Level**: PRD | **Implements**: p00043, p00001 | **Status**: Draft

The app SHALL automatically configure itself for the correct sponsor and study based on the enrollment link provided to the patient, eliminating manual sponsor/study selection.

Automatic configuration SHALL ensure:
- Enrollment link contains sponsor and study identification TODO - is "study" == site? Is site set in the portal?
- App reads enrollment information and connects to correct sponsor system
- Sponsor branding and configuration loaded automatically
- Patient never manually selects sponsor from list
- No opportunity for patient to enroll in wrong study

**Rationale**: Simplifies patient enrollment and prevents enrollment errors. Patients should not need to understand technical concepts like "sponsor" or navigate complex study selection menus. Automatic configuration based on enrollment link ensures patients always connect to the correct study while maintaining sponsor isolation (p00001).

**Acceptance Criteria**:
- Single enrollment link/QR code provided per patient
- App determines sponsor and study from link alone  TODO - "study" == site?  Does the app need to know the site?
- Correct sponsor branding displayed immediately after enrollment TODO - can a site have it's own brand?
- Patient cannot switch to different sponsor after enrollment - TODO - unless they already sync to CureHHT
- Invalid or expired enrollment links rejected with clear error message

*End* *Automatic Sponsor Configuration* | **Hash**: 02bcaf1a
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

**Level**: PRD | **Implements**: p00043 | **Status**: Draft

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

*End* *Offline-First Data Entry* | **Hash**: c5ff6bf6
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

**Level**: PRD | **Implements**: p00043 | **Status**: Draft

The system SHALL enforce temporal boundaries for nosebleed entries to maintain data integrity and prevent invalid records.

Temporal validation SHALL ensure:
- Calendar view disables selection of future dates
- Date picker restricts selection to current date and earlier
- End time does not exceed current real time
- Users cannot create entries before diary start day (see REQ-p01039)
- Entries more than 24 hours old require justification with reason selection - TODO - always or on sponsor config?
- Entries less than 2 minutes old require confirmation - TODO - always or on sponsor config?
- No time overlap exists with other entries TODO - warning when overlaps exist

**Rationale**: Temporal validation ensures data reflects actual events, prevents logical impossibilities (future events, overlapping nosebleeds, entries before app usage), and maintains clinical trial data quality. Capturing reasons for delayed entries helps researchers understand data quality and patient adherence patterns.

**Acceptance Criteria**:

*Future Prevention:*
- Future dates visually disabled/grayed out in calendar view
- Future dates not selectable in date picker
- Current date is maximum selectable date in calendar
- End time picker maximum value is current real time
- Future times visually disabled/grayed out in time picker
- End time validation ensures: end time ≥ start time AND end time ≤ current time
- Current time updates dynamically if user keeps picker open #TODO What does "current time" mean???

*Historical Boundaries:*
- System enforces diary start day boundaries per REQ-p01039
- Dates before diary start day visually distinct per REQ-p01040

*24-Hour Justification:*
- When entry date/time is more than 24 hours in the past, system displays reason selection prompt
- User must select from predefined reasons: "I forgot to record it at the time", "I didn't have access to the app", "I was in a medical facility", "Technical issues with the app", "Other (specify)"
  - TODO - Other (specify) may not be allowed, should only allow a fixed set 
- User cannot proceed with entry creation without selecting reason
- System stores selected reason with entry metadata

*Overlap Prevention:*
- System validates entries for time overlaps before saving (both new and edited entries)
- System displays error message identifying conflicting entry: "This time overlaps with an existing nosebleed record from [start] to [end]"
- User can navigate to view conflicting record

*End* *Temporal Entry Validation* | **Hash**: 897ddcf3

---

## Diary Start Day

# REQ-p01039: Diary Start Day Definition

**Level**: PRD | **Implements**: p00043, p00050 | **Status**: Draft

The system SHALL establish and maintain a "diary start day" representing the earliest date for which diary entries are valid, enabling users to record historical events while maintaining data integrity boundaries.

Diary start day SHALL ensure:
- Default value is set to the day before the first diary entry is created
- User can override the start day by selecting an earlier date and creating an entry
  - TODO - then what's the use a start day?
- Start day cannot be set to a future date
- Start day cannot be set earlier than 365 days before app installation 
  - TODO - any any device for the logged in user or the device for a non-logged in user
- Start day persists across app sessions and device changes via cloud sync

**Rationale**: Clinical trial participants may need to record nosebleeds that occurred before their first app usage. By defaulting the start day to the day before the first entry, users immediately see that they can record past events. This feature demonstrates to users that they can backfill historical data while maintaining reasonable temporal boundaries for data quality. The one-year limit prevents unreliable retrospective data entry while still accommodating patients who want to capture recent history.

**Acceptance Criteria**:

*Default Behavior:*
- When user creates their first diary entry, system sets start day to (entry date - 1 day)
- If first entry is created for a past date, start day is set to (that past date - 1 day)
- Start day is stored locally and synced to cloud when online
- Users are not explicitly prompted to set start day during onboarding

*User Override:*
- User can implicitly set an earlier start day by selecting a date before current start day and creating an entry, up to one year before the installation day
- When user selects a date before current start day in calendar, entry creation automatically updates start day
- Start day moves backward (earlier) but never forward (later) once set
- System displays confirmation when start day is being extended: "This will extend your diary history to include [date]. Continue?"

*Boundary Enforcement:*
- Calendar view disables dates more than 365 days before app installation
- Dates before start day are visually distinct but selectable (triggers start day extension)
- Error message displayed if user attempts to set start day beyond 365-day limit: "Diary records cannot be created more than one year before app installation"

*Persistence:*
- Start day stored in local database with cloud sync
- Start day restored correctly after app reinstallation (from cloud backup)
- Start day consistent across multiple devices for same user

*End* *Diary Start Day Definition* | **Hash**: 04c5ae15

---

## Calendar Visual Indicators

# REQ-p01040: Calendar Visual Indicators for Entry Status

**Level**: PRD | **Implements**: p00043, p01039 | **Status**: Draft

The calendar view SHALL provide clear visual indicators distinguishing between dates with recorded entries, dates with no entries within the diary period, and dates outside the diary period.

Calendar visual indicators SHALL display:
- Dates with diary entries: highlighted with sponsor theme color (filled dot or colored background)
- Dates with no entries within diary period (from start day to today): marked in black/dark color indicating "no nosebleed recorded"
- Dates before diary start day: grayed out and visually muted to indicate they are outside the diary period
- Future dates: grayed out and disabled (not selectable) - TODO - that's three grays.
- Current date: outlined or otherwise distinguished from other dates

**Rationale**: Users need clear visual feedback to understand their diary history at a glance. Showing dates within the diary period that have no entries as "black" (or distinctively marked) communicates that those days were part of the diary period but had no nosebleeds recorded—valuable clinical information. This visual distinction helps patients identify gaps in their records and provides researchers with insight into both recorded events and recorded absence of events.

**Acceptance Criteria**:

*Entry Status Indicators:*
- Days with one or more entries display a filled indicator (dot, badge, or colored background)
- Days with multiple entries display a count badge or multiple indicator
- Indicator color matches sponsor branding theme
- Indicator is visible without requiring user interaction (hover/tap)

*No-Entry Days Within Diary Period:*
- Days from start day through yesterday with no entries display dark/black indicator
- Dark indicator clearly distinguishable from days with entries
- Dark indicator conveys "active diary period, no event recorded" meaning
- Today shows neutral styling until end of day (then becomes no-entry if applicable)

*Outside Diary Period:*
- Days before start day appear grayed out/muted
- Future days appear grayed out/muted and are not tappable
- Clear visual distinction between "outside period" (gray) and "no entry recorded" (black/dark)

*Accessibility:*
- Color indicators supplemented with icons or patterns for colorblind users
  - Patterns would be good for all users.  Before start date and after today would look good with a /// pattern
- Sufficient contrast ratios for all visual states
- Screen reader announces entry status when navigating calendar
- Accessible fonts definable by sponsor feature set and available in user preferences. 

*End* *Calendar Visual Indicators for Entry Status* | **Hash**: 565effd6

---

## References

- **Platform**: prd-system.md
- **Implementation**: dev-app.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md
- **Database**: prd-database.md
- **Compliance**: prd-clinical-trials.md
