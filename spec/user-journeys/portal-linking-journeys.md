# Portal Linking User Journeys

> **Source**: prd-portal.md

---

# JNY-Portal-Linking-01: Link New Patient

**Actor**: Dr. Sarah Mitchell (Investigator)
**Goal**: Link a new patient's mobile app to the sponsor portal, enabling data synchronization
**Context**: A patient has been enrolled in the trial by the sponsor. Dr. Mitchell needs to generate a Mobile Linking Code so the patient can connect their mobile app.

Validates: REQ-d00094, REQ-d00099, REQ-d00101, REQ-d00109

## Steps

1. Dr. Mitchell opens the Sponsor Portal and navigates to patient linking
2. Dr. Mitchell clicks "Link New Patient" and selects the patient's site
3. The system generates a unique Mobile Linking Code and displays it once on screen
4. Dr. Mitchell provides the Mobile Linking Code to the patient verbally or on paper
5. The patient downloads the mobile app and enters the Mobile Linking Code
6. The system validates the code and links the patient's app to the portal
7. The patient begins using the app for diary entries and questionnaires
8. The mobile app syncs data to the portal automatically

## Expected Outcome

The patient's mobile app is successfully linked to the portal. Their data syncs automatically, and Dr. Mitchell can monitor their progress.

*End* *Link New Patient*

---

# JNY-Portal-Linking-02: Lost Mobile Phone Recovery

**Actor**: Dr. Sarah Mitchell (Investigator)
**Goal**: Secure a patient's trial data after they report a lost phone and restore their access on a new device
**Context**: A patient contacts Dr. Mitchell to report their phone was lost. The patient has obtained a new phone and wants to continue participating in the trial.

Validates: REQ-d00101, REQ-d00105

## Steps

1. The patient reports their lost phone to Dr. Mitchell
2. Dr. Mitchell opens the Sponsor Portal and locates the patient record
3. Dr. Mitchell clicks "Disconnect Patient" and selects reason "Lost Device"
4. The system invalidates the linking code immediately
5. The lost phone (if found by someone) can no longer sync or access trial data
6. Dr. Mitchell clicks "Reconnect Patient" and provides the reason for reconnection
7. The system generates a new linking code (the old code remains permanently invalid)
8. Dr. Mitchell provides the new code to the patient
9. The patient enters the new code in the mobile app on their new device
10. The system validates the code and reconnects the patient
11. The mobile app syncs any diary data that was collected locally during the disconnected period

## Expected Outcome

The patient's trial data is secured from unauthorized access on the lost device. The patient resumes participation on their new device with no data loss, and all locally stored entries sync successfully.

*End* *Lost Mobile Phone Recovery*
