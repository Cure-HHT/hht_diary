# Device Resilience User Journeys

Device- and configuration-sensitive journeys for the daily epistaxis eDiary (Android). Each journey is exercised by a runnable integration test in `integration_test/firebase_test_lab_smoke_test.dart` annotated with `Verifies: <JOURNEY>`.

---

# JNY-DIARY-01: Recording Flow Remains Legible at Large Font Scale

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Complete a nosebleed recording while the device uses an enlarged system font scale, without any control being clipped or overflowing
**Context**: Priya has set her device font size to its largest accessibility setting.

Validates: DIARY-GUI-epistaxis-record-A+D

## Steps

1. Priya opens the diary; the home screen renders at the enlarged font scale.
2. Priya taps Record Nosebleed and begins the recording flow.
3. On each step (Start Time, Max Intensity, End Time) the Progress Indicator and the Back action remain fully visible and untruncated.
4. Priya sets the start time, selects an intensity, and sets the end time.
5. The flow completes with no layout overflow on any screen.

## Expected Outcome

Every recording-flow screen lays out without overflow at the largest font scale; the Progress Indicator and Back action are visible throughout, and the record is saved.

*End* *Recording Flow Remains Legible at Large Font Scale*

---

# JNY-DIARY-02: Calendar Day Disposition Renders on a Small High-Density Screen

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: View the calendar and read each day’s disposition legend on a compact, high-density display without clipping
**Context**: Priya’s device has a physically small screen at a high pixel density.

Validates: DIARY-PRD-day-disposition-A

## Steps

1. Priya opens the diary and taps View Calendar.
2. The calendar renders with the day-disposition legend (including the No nosebleeds marker).
3. Each day cell and the legend remain readable and untruncated at the small, dense geometry.
4. Priya taps a date and the day summary opens without layout overflow.

## Expected Outcome

The calendar and its day-disposition legend render legibly with no overflow on a small high-density screen, and a day can be opened from it.

*End* *Calendar Day Disposition Renders on a Small High-Density Screen*

---

# JNY-DIARY-03: In-Progress Record Survives Device Rotation

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Rotate the device mid-recording and have the partially entered record preserved as a resumable draft
**Context**: Priya starts a recording and rotates her device before finishing.

Validates: DIARY-PRD-incomplete-entry-preservation-A+B

## Steps

1. Priya taps Record Nosebleed and sets the start time.
2. Before completing the entry, Priya rotates the device to landscape and back to portrait.
3. The recording screen is still shown with the entered data intact.
4. Priya exits the flow; the incomplete entry is preserved as a resumable draft.
5. The home screen surfaces the preserved draft as an incomplete-entry reminder.

## Expected Outcome

The partially entered record is not lost across rotation and is preserved as a resumable draft that the home screen surfaces for completion.

*End* *In-Progress Record Survives Device Rotation*

---

# JNY-DIARY-04: Overlap Resolution Controls Are Reachable in Landscape

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Resolve an overlapping-event conflict using the resolution controls while the device is in landscape orientation
**Context**: A new entry overlaps an existing one, triggering the conflict-resolution screen, viewed in landscape.

Validates: DIARY-PRD-entry-overlap-resolution-A

## Steps

1. Priya records an event whose start time overlaps an existing entry.
2. The System detects the overlap and presents the conflict-resolution screen.
3. With the device in landscape, the resolution controls (keep new, keep existing, merge) remain visible and tappable.
4. Priya chooses a resolution and the conflict is resolved without layout overflow.

## Expected Outcome

The overlap-resolution controls are fully reachable and operable in landscape orientation, and the conflict resolves cleanly.

*End* *Overlap Resolution Controls Are Reachable in Landscape*

---

# JNY-DIARY-05: Yesterday Disposition Is Correct Across a Date Boundary

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Answer the yesterday banner correctly when the device clock is at a midnight / DST boundary
**Context**: Priya opens the diary with the device clock set near a midnight or daylight-saving boundary.

Validates: DIARY-PRD-day-disposition-B

## Steps

1. Priya opens the diary near the local date boundary; the yesterday banner asks "Did you have nosebleeds?".
2. Priya answers No for yesterday.
3. The System dispositions the correct local calendar day as No-Nosebleed.
4. The banner is dismissed and the home records reflect the correct day.

## Expected Outcome

The yesterday disposition is applied to the correct local calendar day despite the date-boundary timing, with no off-by-one-day error.

*End* *Yesterday Disposition Is Correct Across a Date Boundary*

---

# JNY-DIARY-06: Event Day Attribution Is Correct Across Midnight Rollover

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Record an event started just before midnight and have it attributed to the correct day with correct timezone-aware duration
**Context**: Priya records an event while the device clock rolls over midnight during entry.

Validates: DIARY-PRD-epistaxis-capture-standard-D

## Steps

1. Priya begins a recording with a start time just before local midnight.
2. The clock rolls past midnight while she completes the entry.
3. Priya sets the end time and saves the record.
4. The System computes the duration in a timezone-aware way and attributes the event to its start day.
5. The record appears under the correct day in Your Records.

## Expected Outcome

The event is attributed to its start day with a correct timezone-aware duration, unaffected by the midnight rollover.

*End* *Event Day Attribution Is Correct Across Midnight Rollover*

---

# JNY-DIARY-07: Finalizing a Record Is Idempotent Under Rapid Taps

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Finalize a record with a rapid double-tap and produce exactly one record while returning to the home screen
**Context**: On a slower device, Priya double-taps the Set End Time / finalize control.

Validates: DIARY-GUI-epistaxis-record-K

## Steps

1. Priya completes a recording up to the end-time step.
2. Priya taps Set End Time twice in quick succession.
3. The System saves exactly one record (no duplicate).
4. The interface returns Priya to the home screen.
5. Your Records shows a single new entry.

## Expected Outcome

A rapid double-tap on finalize saves exactly one record and returns to the home screen, with no duplicate entry.

*End* *Finalizing a Record Is Idempotent Under Rapid Taps*

---

# JNY-DIARY-08: Recording Chrome Survives Rapid Navigation Churn

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Navigate rapidly between home, recording, and calendar without the app accumulating errors or losing its recording chrome
**Context**: Priya quickly bounces between screens, as can happen on a laggy device.

Validates: DIARY-GUI-epistaxis-record-A

## Steps

1. Priya rapidly opens and backs out of the recording flow several times.
2. Priya rapidly opens and backs out of View Calendar several times.
3. Throughout, the Progress Indicator appears on each recording-flow screen as expected.
4. No exception accumulates and the app settles back on the home screen.

## Expected Outcome

Rapid navigation churn does not produce exceptions or lose the recording-flow chrome; the app returns cleanly to the home screen.

*End* *Recording Chrome Survives Rapid Navigation Churn*

---

# JNY-DIARY-09: Delete and Cancel Keep the Record List Consistent

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Delete a saved event and confirm the list updates, while cancelling a delete leaves the event unchanged
**Context**: Priya manages an existing saved event from her diary.

Validates: DIARY-GUI-epistaxis-delete-F+G

## Steps

1. Priya opens a saved Epistaxis Event and selects the delete action.
2. Priya confirms the delete reason; the event is removed from her diary and the list updates.
3. Priya opens another saved event and selects delete, then cancels the reason dialog.
4. The cancelled event remains unchanged in the list.

## Expected Outcome

Confirming a delete removes the event and updates the list; cancelling a delete leaves the event unchanged — the list stays consistent in both cases.

*End* *Delete and Cancel Keep the Record List Consistent*

---

# JNY-DIARY-10: Accessibility Preference Persists Across the Session

**Actor**: Priya, a study Participant using the daily epistaxis diary on her Android device
**Goal**: Toggle an accessibility preference in settings and have the daily-status state remain consistent afterward
**Context**: Priya adjusts an accessibility preference and returns to her diary.

Validates: DIARY-PRD-epistaxis-capture-standard-B

## Steps

1. Priya opens Settings and then Accessibility & Preferences.
2. Priya toggles an accessibility preference.
3. Priya returns to the home screen; the preference is still applied.
4. Her daily-status values remain mutually exclusive and unchanged by the toggle.

## Expected Outcome

The accessibility preference persists after returning to the diary, and daily-status state remains consistent and mutually exclusive.

*End* *Accessibility Preference Persists Across the Session*

