# Appendices

## 7.1 Screens {-}

### 7.1.1 Questionnaire Review Screen {-}

*Trigger:* **Participant** answers the final question of a **Portal-Sent Questionnaire**, before **Submission**.   
*Displays:* **Questionnaire Display Name**, every question in original order, the **Participant**'s selected response beneath each question, an Edit affordance per question, and a **Submit** action.   
*Outcome:* Selecting **Submit** completes **Submission**.   
*Reference:* GUI-p00001.

![](image-01.png)

### 7.1.2 Questionnaire Preamble Screen {-}

*Trigger:* **Participant** opens a **Portal-Sent Questionnaire**.   
*Displays:* **Questionnaire Display Name**, estimated time to complete.

*Actions:* **I'm Ready** (proceed to first question), **Not Now** (return to **Main Screen**). *Reference:* REQ-p02065, GUI-p00001.

![](image-02.png)

### 7.1.3 Resolve Conflict — Resolution Screen {-}

*Trigger:* New or edited entry **Overlaps** with one or more **Conflicting Records**. **Displays:** New entry and **Conflicting Record** side by side, showing time range, duration, and severity for each.

*Actions:* **Keep New** (retain new entry, discard **Conflicting Record**), **Keep Existing** (retain **Conflicting Record**, discard new entry), **Merge Records** (combine both using earliest start time, latest end time, and higher severity). **Conditional behavior:**

* **Merge Records** is presented only when the **Conflicting Record**'s event date has not exceeded the **Lock Threshold**.  
* When the **Conflicting Record** is older than the **Justification Threshold**, an **Entry Justification** is required before saving the resolution.

*Outcome:* **Participant** is navigated to the **Record Nosebleed** screen pre-filled with the resulting entry data for review and confirmation. 

*Reference:* REQ-p05008, GUI-p05009.

![](image-03.png)

## 

### 7.1.4 Troubleshooting Popover {-}

*Trigger:* **Study Coordinator** selects the information icon adjacent to the **Status Badge** on a **Questionnaire Card** in **Delivery Failed** status. 

*Displays:* Guidance for resolving delivery issues for the affected **Questionnaire**. 

*Dismissal:* Click outside the popover.

*Reference:* GUI-CAL-p00006.

![](image-04.png)

## 7.2 Modals {-}

### 7.2.1 User Information Modal {-}

*Trigger:* **Administrator** selects a **User Account** row from the User Management interface.  
*Target identification:* **Full Name**, **Email Address**, **Status**.   
*Displays:* Assigned **Role**(s) and **Site** assignments. When the **User Account** holds one or more non-**Administrator** **Roles**, the **Administrator** may select a single **Role** to scope the displayed **Site** list. When the **User Account** is an **Administrator**, the modal indicates access to all **Sites**. *Actions (Active Users tab):* **Edit User**, **Deactivate User**, **Close**. The **Deactivate User** action is not presented for the currently authenticated user's own account.   
*Actions (Inactive Users tab):* **Reactivate User**, **Close**.   
*Reference:* GUI-p00033.

![](image-05.png)

### 

### 7.2.2 Show Linking Code {-}

*Trigger:* **Study Coordinator** selects **Show Linking Code** for a **Participant**.   
*Target identification:* **Participant** ID. 

*Variants:*

* **Pending** status: displays the active **Mobile Linking Code** with **Copy** and **Save as PDF** actions. **Save as PDF** generates a PDF containing the **Mobile Linking Code** and **Participant** instructions.  
* Any other status: displays the **Participant Linking Code** (the code previously used to establish the connection) with a **Copy** action, and indicates the code is shown for reference only.

*Dismissal:* **Close**.   
*Reference:* GUI-p03001.

Pending Status

![](image-06.png)

After Participant was linked to the Mobile Application

![](image-07.png)

### 7.2.3 Manage Questionnaires Modal {-}

*Trigger:* **Study Coordinator** selects **Manage Questionnaires** for a **Participant** with **Trial Active** status. 

*Target identification:* **Participant** ID in the modal header. 

*Displays:* One **Questionnaire Card** per **Questionnaire Type** enabled for the deployment. Each card shows the **Questionnaire Type** name and current **Questionnaire Status**, with content and actions varying by status and **Cycle** state (e.g., **Send Now**, **Start Next Cycle**, **Finalize**, call back). 

*Dismissal:* Close action. 

*Reference:* GUI-CAL-p00006.

![](image-08.png)

## 7.3 Dialogs {-}

### 7.3.1 Deactivate User Account — Reason Dialog (Free Text) {-}

*Trigger:* **Administrator** initiates deactivation of a **User Account** from the **Active Users** tab. *Target identification:* **Full Name**. 

*Consequence summary:* The **User Account** will be deactivated and the user will no longer be able to access the **System**. 

*Pattern:* Reason Dialog — Free Text (see §4.1). 

*Reference:* REQ-p20031, GUI-p00031.

![](image-09.png)

### 7.3.2 Reactivate User Account — Reason Dialog (Free Text) {-}

*Trigger:* **Administrator** initiates reactivation of a **User Account** from the **Inactive Users** tab. 

*Target identification:* **Full Name**. 

*Consequence summary:* The **User Account** will be set to **Pending Activation** and the user will be required to complete the activation workflow before regaining access. 

*Pattern:* Reason Dialog — Free Text (see §4.1). 

*Reference:* REQ-p20032, GUI-p00032.

![](image-10.png)

### 7.3.3 Link Participant — Confirmation Dialog {-}

*Trigger:* **Study Coordinator** initiates **Link Participant** for a **Participant** with **Not Connected** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* A **Mobile Linking Code** will be generated for the **Participant** and will expire after the configured duration. 

*Pattern:* Confirmation Dialog (see §4.1). 

*Reference:* REQ-p70009, GUI-p03001.

![](image-11.png)

### 

### 7.3.4 Linking Code Generated — Acknowledgement Dialog {-}

*Trigger:* **Study Coordinator** confirms generation of a **Mobile Linking Code** from the Link Participant Confirmation Dialog (§7.3.3). 

*Target identification:* **Participant** ID. 

*Displays:* Generated **Mobile Linking Code** with a **Copy** action, and remaining time until expiry. *Outcome:* On dismissal, the **Participant**'s **Status Badge** updates to **Pending**. 

*Pattern:* Acknowledgement Dialog (see §4.1). 

*Reference:* GUI-p03001.

![](image-12.png)

### 7.3.5 Start Trial — Confirmation Dialog {-}

*Trigger:* **Study Coordinator** selects **Start Trial** for a **Participant** with **Linked \- Awaiting Start** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* **Diary Data Synchronization** will be activated, transmitting diary entries to the **Sponsor Portal** and **Rave EDC**. The **Participant**'s status will update to **Trial Active**. 

*Pattern:* Confirmation Dialog (see §4.1). 

*Reference:* REQ-CAL-p00022, GUI-CAL-p00005.

![](image-13.png)

### 

### 7.3.6 Disconnect Participant — Reason Dialog {-}

*Trigger:* **Study Coordinator** selects **Disconnect Participant** from the **Participant Actions Modal** for a **Participant** with **Linked \- Awaiting Start** or **Trial Active** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* Data synchronization between the **Mobile Application** and the **Sponsor Portal** will stop. All **Participant** data will be preserved. 

*Reason options:* Device Issues, Technical Issues, Other. 

*Pattern:* Reason Dialog — Predefined List (see §4.1). 

*Reference:* REQ-p70010, REQ-CAL-p00020.

![](image-14.png)

### 

### 7.3.7 Reconnect Participant — Reason Dialog (Free Text) {-}

*Trigger:* **Study Coordinator** selects **Reconnect Participant** from the **Participant Actions Modal** for a **Participant** with **Disconnected** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* A new **Mobile Linking Code** will be generated. The **Participant** must enter the new code to restore the connection. 

*Pattern:* Reason Dialog — Free Text (see §4.1). 

*Reference:* REQ-p70011.

![](image-15.png)

### 7.3.8 Mark as Not Participating — Reason Dialog (Predefined) {-}

*Trigger:* **Study Coordinator** selects **Mark as Not Participating** for a **Participant** with **Disconnected** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* Sponsor-specific rules will no longer be applied to the **Participant**'s **Mobile Application**. *Reason options:* Subject Withdrawal, Death, Protocol Treatment/Study Complete, Other. 

*Pattern:* Reason Dialog — Predefined List (see §4.1). 

*Reference:* REQ-p70017, REQ-CAL-p00064.

![](image-16.png)

### 

### 7.3.9 Reactivate Participant — Reason Dialog (Free Text) {-}

*Trigger:* **Study Coordinator** selects **Reactivate Participant** from the **Participant Actions Modal** for a **Participant** with **Not Participating** status. 

*Target identification:* **Participant** ID. 

*Consequence summary:* Sponsor-specific rules will be re-applied to the **Participant**'s **Mobile Application** and the standard reconnection workflow will become available.

*Pattern:* Reason Dialog — Free Text (see §4.1). 

*Reference:* REQ-p70016.

![](image-17.png)

### 7.3.10 Delete Record — Reason Dialog — Predefined List {-}

*Trigger:* **Participant** initiates the delete action on an **Epistaxis Event**, either during the recording flow or from event history.   
*Consequence summary:* The **Epistaxis Event** will be removed from the **Participant**'s diary. *Reason options:* Entered by mistake, Duplicate entry, Incorrect information, Other.   
*Pattern:* Reason Dialog — Predefined List (see §4.1).   
*Reference:* GUI-p00003.

![](image-18.jpg)

### 7.3.11 Post-Submission Acknowledgement Dialog {-}

*Trigger:* **Participant** confirms **Submission** of a **Portal-Sent Questionnaire**.   
*Consequence summary:* Confirms the **Questionnaire** has been submitted and informs the **Participant** that the **Study Coordinator** will review the responses.   
*Pattern:* Acknowledgement Dialog (see §4.1).   
*Reference:* GUI-p00001.

![](image-19.png)

### 

### **7.3.12 Session Expiry Dialog** 

*Trigger:* **Participant** opens a **Portal-Sent Questionnaire** that has reached **Session Expiry**.   
*Consequence summary:* Informs the **Participant** that the session has expired and previous answers were not saved.   
*Actions:* **Start Again** (begin the **Questionnaire** from the **Preamble**), **Not Now** (return to **Main Screen**).   
*Pattern:* Acknowledgement Dialog (see §4.1).   
*Reference:* REQ-p01073, GUI-p00004.

![](image-20.png)

### 7.3.13 Questionnaire Finalization Dialog {-}

*Trigger:* Study Coordinator selects **Finalize** on a **Questionnaire Card** with **Delivery Failed** or **Ready to Review** status.  
*Consequence summary:* Finalizes the Questionnaire — locks all Participant responses permanently, calculates the score, transmits it to Rave EDC, and prevents the Participant from editing their answers in the Mobile Application.  
*Actions:* Finalize Questionnaire (apply finalization with the selected Cycle), Cancel (close the dialog with no changes).  
*Inputs:* Cycle dropdown — selectable values are the Current Cycle N Day 1 value, End of Treatment, and End of Study.  
*Cross-flow:* When a Terminal Cycle value (End of Treatment or End of Study) is selected, confirming opens the Terminal Cycle Warning Dialog before finalization is applied.  
*Pattern:* Confirmation Dialog (see §4.1).  
*Reference:* REQ-CAL-p00023 I–M, GUI-CAL-p00007 A–F.

![](image-21.png)

### 7.3.14 Terminal Cycle Warning Dialog {-}

*Trigger:* **Study Coordinator** confirms finalization of a **Questionnaire** with a **Terminal Cycle** value (**End of Treatment** or **End of Study**) selected in the **Finalization Dialog**.   
*Target identification:* **Participant** ID, **Questionnaire Type**, **Terminal Cycle** being assigned. *Consequence summary:* The **Participant**'s answers will be locked, the score will be transmitted to **Rave EDC**, and the **Questionnaire Type** will be closed for the **Participant** so no further **Questionnaires** of that type may be sent.   
*Cancellation behavior:* On cancel, the **Questionnaire** remains unchanged and the **Study Coordinator** is returned to the **Finalization Dialog**.   
*Pattern:* Confirmation Dialog (see §4.1).   
*Reference:* GUI-CAL-p00007.

![](image-22.png)

### 7.3.15 Call Back Questionnaire — Reason Dialog (Free Text) {-}

*Trigger:* **Study Coordinator** initiates the call back action on a **Questionnaire** with **Sent**, **Delivery Failed**, or **Ready to Review** status.   
*Target identification:* **Participant** ID, **Questionnaire Type**.   
*Consequence summary:* The **Questionnaire** status will be set to **Not Sent**.   
*Pattern:* Reason Dialog — Free Text (see §4.1).   
*Reference:* REQ-CAL-p00023, GUI-CAL-p00006.

![](image-23.png)

### 7.3.16 Call Back Notice {-}

*Trigger:* A **Portal-Sent Questionnaire** assigned to the **Participant** has been called back by the **Study Coordinator**.   
*Consequence summary:* Informs the **Participant** that the **Questionnaire** is no longer active and any answers entered will not be saved.   
*Presentation contexts:*

* The **Portal-Sent Questionnaire** is called back while the **Participant** has it open.  
* The **Participant** opens the **Mobile Application** after a call back has occurred.  
* The **Participant** attempts to submit a **Portal-Sent Questionnaire** that has been called back while offline.

*Behavior:* Cannot be dismissed by tapping outside its bounds. On acknowledgement, the **Participant** is returned to the **Main Screen** and the corresponding **Questionnaire Task** is removed from the **Task List**.   
*Pattern:* Acknowledgement Dialog (see §4.1).   
*Reference:* GUI-CAL-p07002.

![](image-24.png)

### 7.3.17 Successful Linking Confirmation {-}

*Trigger:* A **Participant** successfully submits a valid **Mobile Linking Code** on the **Join the Study** screen.   
*Consequence summary:* Confirms to the **Participant** that the device has been linked to the study and transitions the **Participant** from personal use mode into linked use mode. 

*Behavior:* On acknowledgement, the **Participant** is navigated to the **User Profile** screen.  
*Pattern:* Acknowledgement Dialog (see §4.1).   
*Reference:* GUI-p05015.![](image-25.png)

## 7.4 Notifications {-}

### 7.4.1 Timeout Warning Notification {-}

A push notification delivered to the Participant when a configured Questionnaire Session Timeout is approaching expiry. Tapping the notification opens the questionnaire in the Mobile Application. The wording is sponsor-configurable per Questionnaire definition; the default text is *\["Your \[Questionnaire Display Name\] session is about to expire. Open the app to continue and submit your answers."\]*

![](image-26.png)

### 

### 7.4.2 Session Expiry Notification {-}

A push notification delivered to the Participant when the configured Session Timeout has been exceeded for an in-progress Questionnaire and the Participant's previously entered answers have been discarded. Tapping the notification opens the Mobile Application; if the Participant returns to the Questionnaire, the Session Expiry Dialog is displayed. The wording is sponsor-configurable per Questionnaire definition; the default text is *\["Your \[Questionnaire Display Name\] session has expired and your answers were not saved. Open the app to start again."\]*

![](image-27.png)

### 

### 7.4.3 Disconnection Notification {-}

A persistent, non-dismissible in-app notification displayed in the System Notice Area at the top of the Main Screen when the Participant's status is Disconnected. The notification persists until the Participant is reconnected to the Sponsor Portal. The wording is sponsor-configurable; the default text is *\["Your connection with the study has been interrupted. Please contact your study site for assistance."\]*

![](image-28.png)

### 7.4.4 Portal-Sent Questionnaire Notification {-}

A push notification delivered to the Participant when a Study Coordinator sends a Portal-Sent Questionnaire from the Sponsor Portal. Tapping the notification opens the Mobile Application; the Participant accesses the Questionnaire from the Questionnaire Task on the Main Screen. The wording is sponsor-configurable; the default text is *\["A \[Questionnaire Display Name\] questionnaire is ready for you to complete. Open the app to begin."\]*

![](image-29.png)

### 7.4.5 Yesterday Entry Reminder Notification {-}

A push notification delivered to the Participant at the configured Reminder Time when no Daily Status has been recorded for the previous calendar day. Tapping the notification opens the Mobile Application; the Participant accesses the Yesterday Reminder Task on the Main Screen. The wording is sponsor-configurable; the default text is *\["Did you have a nosebleed yesterday? Take a moment to record yesterday's status in your diary."\]*

![](image-30.png)

### 7.4.6 Ongoing Epistaxis Event Reminder {-}

A push notification delivered to the Participant when an Incomplete Record has not been interacted with for the configured Reminder Interval. Tapping the notification opens the Mobile Application; the Participant returns to the Incomplete Record to either complete it or confirm the event is still ongoing. The wording is sponsor-configurable; the default text is *\["Is your nosebleed still going? You started recording a nosebleed but haven't finished. Tap to update.”*

![](image-31.png)

### 7.4.7 Historical Gap Reminder {-}

A push notification delivered to the **Participant** at the configured Reminder Time when one or more Historical Gaps exist within the editable window. Tapping the notification opens the Mobile Application; the Participant accesses the missing days via the Calendar. The wording is sponsor-configurable; the default text is *\["You have one day without a recorded entry. Tap to review and complete your diary."\]*

![](image-32.png)

