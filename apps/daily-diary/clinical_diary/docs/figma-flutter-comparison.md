# Flutter vs Figma Design Comparison Report
This is a temporary document and can be removed.
**Document**: Implementation Gap Analysis
**Date**: 2025-11-28
**Source Design**: CureHHTApp-v4---GenericCo---Playground (Figma Make)
**Target Implementation**: apps/daily-diary/clinical_diary (Flutter)

---

## Executive Summary

This document compares the Flutter implementation of the Diary mobile app against the Figma Make design prototype. The analysis identifies missing features, visual differences, and implementation gaps that should be addressed for design fidelity.

**Key Findings**:
- **2 Major Missing Features** - Questionnaire system, Survey Events
- **0 Visual Differences** - All visual elements now match Figma design
- **1 Flutter Addition** - Internationalization (EN/ES/FR) not in design
- **8 Features Completed** - Day Selection, Date Records, Color-coded Calendar, Special Event Cards, Logo Menu, Multi-day Indicator, Animated Enrollment Dialog, Custom Intensity Icons

---

## Implementation Checklist

### High Priority (Core Functionality)

- [ ] **1. Questionnaire System**
  - [ ] Create questionnaire data model
  - [ ] Build QuestionnaireFlowScreen
  - [ ] Add SurveyViewScreen
  - [ ] Store completed surveys locally
  - [ ] Display survey events in timeline

- [x] **2. Day Selection Screen** ✅ DONE
  - [x] Create DaySelectionScreen widget
  - [x] Three-option interface (Add nosebleed, No nosebleeds, Unknown)
  - [x] Integrate with calendar flow
  - [x] Tests written (13 tests)

- [ ] **3. Survey Event Types**
  - [ ] Add survey event type to model
  - [ ] Blue survey event card in EventListItem
  - [ ] "View Only" label and clipboard icon

- [x] **4. Color-coded Calendar** ✅ DONE (was already implemented)
  - [x] Status-based date colors (red/green/yellow/black/grey)
  - [x] Legend component
  - [x] Missing data highlighting

### Medium Priority (UX Enhancement)

- [x] **5. Date Records Screen** ✅ DONE
  - [x] Create DateRecordsScreen widget
  - [x] List of events for selected date
  - [x] "Add new event" button
  - [x] Edit capability for each event
  - [x] Tests written (11 tests)

- [x] **6. Logo Menu Implementation** ✅ DONE
  - [x] Make header logo tappable
  - [x] Data Management popup menu (Add Example Data, Reset All Data)
  - [ ] Questionnaire triggers (deferred - questionnaire system not implemented)
  - [x] End Clinical Trial option
  - [x] Instructions & Feedback external link
  - [x] Tests written (14 tests)

- [x] **7. Special Event Card Styling** ✅ DONE
  - [x] Green "No nosebleeds" card with checkmark
  - [x] Yellow "Unknown" card with question mark
  - [x] Tests written (8 tests)

### Low Priority (Visual Polish)

- [x] **8. Custom Intensity Icons** ✅ DONE
  - [x] Download/create droplet illustration assets
  - [x] Replace Material Icons in IntensityPicker
  - [x] Custom nose/droplet images from Figma

- [x] **9. Animated Enrollment Dialog** ✅ DONE
  - [x] Add transition animation (Pending → Success)
  - [x] Tests written (6 tests)

- [x] **10. Multi-day Event Indicator** ✅ DONE
  - [x] Show "(+1 day)" for events crossing midnight
  - [x] Tests written (4 tests)

---

## Missing Features (Critical)

### 1. Questionnaire System - NOT IMPLEMENTED

**Figma Components**:
- `QuestionnaireFlow.tsx` - Multi-step questionnaire with preamble, questions, review
- `SurveyViewScreen.tsx` - View completed survey responses
- `data/questionnaires.ts` - Questionnaire definitions (NOSE HHT, Quality of Life)

**Functionality**:
- NOSE HHT questionnaire for nasal symptom evaluation
- Quality of Life surveys for comprehensive health assessment
- Multi-step flow with progress indicator
- Preamble screens before questions
- Review/summary screen before submission
- Survey completion events displayed in timeline
- View-only access to completed surveys

**Flutter Status**: No questionnaire functionality exists.

**Relevant Requirements**: REQ-p00008 (if applicable)

---

### 2. Day Selection Screen - ✅ IMPLEMENTED

**Figma Component**: `DaySelectionScreen.tsx`

**Functionality**:
- Shows when selecting a calendar date without existing records
- Title: "[Date] - What happened on this day?"
- Three prominent action buttons:
  - "Add nosebleed event" (red, primary)
  - "No nosebleed events" (green)
  - "I don't recall / unknown" (outline)

**Flutter Status**: ✅ Implemented in `lib/screens/day_selection_screen.dart`
- Integrated with calendar flow in `calendar_screen.dart`
- 13 passing tests in `test/screens/day_selection_screen_test.dart`

---

### 3. Date Records Screen - ✅ IMPLEMENTED

**Figma Component**: `DateRecordsScreen.tsx`

**Functionality**:
- Shows all events for a specific selected date
- List of events with edit capability
- "Add new event" button
- Back navigation

**Flutter Status**: ✅ Implemented in `lib/screens/date_records_screen.dart`
- Integrated with calendar flow in `calendar_screen.dart`
- 11 passing tests in `test/screens/date_records_screen_test.dart`

---

### 4. Missing Data Calendar - ✅ IMPLEMENTED

**Figma Component**: `MissingDataCalendar.tsx`

**Functionality**:
- Specialized calendar overlay for missing data
- Color-coded dates:
  - Red: Nosebleed events
  - Green: No nosebleeds confirmed
  - Yellow: Unknown status
  - Black: Missing/Incomplete data
  - Grey: No events (before first record)
- Legend explaining color codes
- Only allows selection of missing data days
- "Tap a highlighted date to add data for that day"

**Flutter Status**: ✅ Implemented in `lib/screens/calendar_screen.dart`
- Color-coded status indicators
- Legend with all status types
- Day selection screen for dates without records

---

### 5. Logo Menu (Data Management) - ✅ IMPLEMENTED

**Figma Location**: `HomeScreen.tsx` - Tappable logo in header

**Functionality**:
- Data Management section:
  - Add Example Data
  - Reset All Data
- Questionnaire triggers:
  - NOSE Study Questionnaire
  - Quality of Life Survey
- Clinical Trial:
  - End Clinical Trial Enrollment (if enrolled)
- External link:
  - Instructions and Feedback

**Flutter Status**: ✅ Implemented in `lib/widgets/logo_menu.dart`
- Integrated with home screen header
- Data Management options (Add Example Data, Reset All Data with confirmation)
- End Clinical Trial option (shown only when enrolled)
- Instructions & Feedback external link
- Questionnaire triggers deferred until questionnaire system is implemented
- 14 passing tests in `test/widgets/logo_menu_test.dart`

---

### 6. Survey Events in Event List - NOT IMPLEMENTED

**Figma Component**: `EventListItem.tsx` (survey event handling)

**Functionality**:
- Survey events displayed as special cards:
  - Blue background styling
  - Clipboard icon (📋)
  - Survey name displayed
  - "View Only" label
  - Completion time shown
  - Tappable to view survey responses

**Flutter Status**: `event_list_item.dart` only handles nosebleed records.

---

### 7. Special Event Type Cards - ✅ IMPLEMENTED

**Figma Component**: `EventListItem.tsx` (special event types)

**Functionality**:
- "No Nosebleed Events" card:
  - Green background (green-50)
  - Checkmark icon (✓)
  - "Confirmed no events for this day"
- "Unknown" event card:
  - Yellow background (yellow-50)
  - Question mark icon (?)
  - "Unable to recall events for this day"

**Flutter Status**: ✅ Implemented in `lib/widgets/event_list_item.dart`
- Green "No nosebleed events" card with check_circle icon
- Yellow "Unknown" card with help_outline icon
- 8 additional tests (23 total for EventListItem)

---

## Visual/UI Differences

### 8. Intensity Icons

| Aspect | Figma Design | Flutter Implementation |
| -------- | -------------- | ------------------------ |
| Icon Type | Custom image assets (droplet illustrations) | Material Icons |
| Icons Used | `spottingIcon.png`, `drippingIcon.png`, etc. | `Icons.water_drop`, `Icons.opacity`, etc. |
| Color Scheme | Intensity-specific colors (green→yellow→red) | Blue-grey scale |

**Figma Assets**:
- `2abb485475a2155888f0b9cf5d60b00d0e60c0dc.png` (Spotting)
- `b7c32eb7099d240e6e35c5e4d31747c2f17d3f14.png` (Dripping)
- `7143b924359de55136b437848338c8123becffb7.png` (Dripping quickly)
- `af3ed36b994236e727da82af8cc77fecd4419201.png` (Steady stream)
- `d8f6cd656bd09578a87697e17d921cc06a8fe405.png` (Pouring)
- `2b7e1aa050a7930996e53d943b2b2436daf6a8ca.png` (Gushing)

---

### 9. Event List Item Layout

| Aspect | Figma Design | Flutter Implementation |
| -------- | -------------- | ------------------------ |
| Layout | Single-line: time + icon + duration | Multi-row card with vertical color bar |
| Time Display | Start time only | Time range (start - end) |
| Intensity | Image icon inline | Vertical color stripe + text name |
| Duration | Text inline (e.g., "45m") | Badge/chip style |

---

### 10. Calendar Styling

| Aspect | Figma Design | Flutter Implementation |
| -------- | -------------- | ------------------------ |
| Status Colors | Multi-color (red/green/yellow/black/grey) | Basic (no status colors) |
| Legend | Present with explanations | Missing |
| Today Indicator | Ring/border styling | Standard Flutter |
| Missing Data | Black highlight | Not highlighted |

---

### 11. Multi-day Event Indicator - ✅ IMPLEMENTED

**Figma**: End time shows "(+1 day)" when event crosses midnight

**Flutter Status**: ✅ Implemented in `lib/widgets/event_list_item.dart`
- Shows "(+1 day)" indicator when event end time is on a different day
- 4 tests for multi-day events

---

## Flutter Additions (Not in Design)

### 12. Internationalization (i18n)

**Flutter Implementation**:
- `l10n/app_localizations.dart`
- Supports: English, Spanish (Español), French (Français)
- Language selection in Settings screen

**Figma Design**: English only (no language selection in SettingsScreen.tsx)

**Note**: This is appropriate for EU deployment and should be retained.

---

## Feature Matrix

| Feature | Figma | Flutter | Status |
| --------- | :-----: | :-------: | -------- |
| Home Screen | ✅ | ✅ | Partial (missing logo menu) |
| Recording Flow | ✅ | ✅ | Complete |
| Intensity Selection | ✅ | ✅ | Different UI (icons) |
| Time Picker | ✅ | ✅ | Complete |
| Notes Input | ✅ | ✅ | Complete |
| Calendar | ✅ | ✅ | ✅ Complete with colors |
| Missing Data Calendar | ✅ | ✅ | ✅ Complete |
| Day Selection Screen | ✅ | ✅ | ✅ Complete |
| Date Records Screen | ✅ | ✅ | ✅ Complete |
| Profile Screen | ✅ | ✅ | Complete |
| Settings Screen | ✅ | ✅ | Complete (+ i18n) |
| Clinical Trial Enrollment | ✅ | ✅ | Complete |
| Questionnaire Flow | ✅ | ❌ | Missing |
| Survey View Screen | ✅ | ❌ | Missing |
| Survey Events | ✅ | ❌ | Missing |
| Special Event Cards | ✅ | ✅ | ✅ Complete |
| Logo Menu | ✅ | ✅ | ✅ Complete (minus questionnaires) |
| Yesterday Banner | ✅ | ✅ | Complete |
| Delete Confirmation | ✅ | ✅ | Complete |
| Overlap Warning | ✅ | ✅ | Complete |
| Internationalization | ❌ | ✅ | Flutter addition |

---

## Recommendations

### High Priority (Core Functionality)

1. **Implement Questionnaire System** - TODO
   - Create questionnaire data model
   - Build questionnaire flow screen
   - Add survey view screen
   - Store completed surveys
   - Display in event timeline

2. ~~**Add Day Selection Screen**~~ - ✅ DONE
   - ~~Create intermediate screen for calendar date selection~~
   - ~~Three-option interface for date without records~~

3. **Implement Survey Event Types** - TODO
   - Update NosebleedRecord model to support survey events
   - Update EventListItem to render survey cards

4. ~~**Add Color-coded Calendar**~~ - ✅ DONE (was already implemented)
   - ~~Implement status-based date colors~~
   - ~~Add legend component~~
   - ~~Highlight missing data days~~

### Medium Priority (UX Enhancement)

5. ~~**Date Records Screen**~~ - ✅ DONE
   - ~~Create screen showing all events for selected date~~

6. ~~**Logo Menu Implementation**~~ - ✅ DONE
   - ~~Make header logo tappable~~
   - ~~Add data management popup menu~~
   - Questionnaire triggers deferred

7. ~~**Special Event Card Styling**~~ - ✅ DONE
   - ~~Style "No nosebleeds" events (green)~~
   - ~~Style "Unknown" events (yellow)~~

### Low Priority (Visual Polish)

8. ~~**Custom Intensity Icons**~~ - ✅ DONE
   - ~~Replace Material Icons with design assets~~
   - ~~Match Figma severity illustrations~~

9. ~~**Animated Enrollment Dialog**~~ - ✅ DONE
   - ~~Add transition animation (Pending → Success)~~

10. ~~**Multi-day Event Indicator**~~ - ✅ DONE
    - ~~Show "(+1 day)" for events crossing midnight~~

---

## Implementation Notes

### Requirement Traceability

When implementing missing features, reference:
- **REQ-p00008**: If questionnaires relate to data collection requirements
- **REQ-d00004**: Local-First Data Entry Implementation
- **REQ-d00005**: User Profile Screen Implementation

### Testing Requirements

Per dev-core-practices.md:
- Write tests BEFORE implementation (TDD)
- Use real databases over mocks where possible
- Contract tests for any service integrations

### File Locations

**Flutter App**: `apps/daily-diary/clinical_diary/lib/`
- Screens: `screens/`
- Widgets: `widgets/`
- Models: `models/`
- Services: `services/`

**Figma Source**: Accessible via MCP at:
`file://figma/make/source/9u9F1NFQ4zqYeHkxSuVcTf/`

---

**Document Classification**: Internal Use - Development Reference
**Review Frequency**: As implementation progresses
**Owner**: Development Team
