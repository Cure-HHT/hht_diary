# *User* Account Management

The *Sponsor* Portal supports the full **User Account** lifecycle: creation, activation, *Site* assignment, activation-email resend, edit, *Deactivation*, and reactivation. A consistent *User*-management interface — tabs, modals, the *Administrator* Dashboard, and the shared **Reason Field Constraints** that govern every free-text reason input — exposes these capabilities to the *Administrator* *Role*.

## DIARY-PRD-user-account-create: Create User Account

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Overview

This requirement defines the minimum identity and authorization data the **System** captures when an **Administrator** creates a new **User Account**. Subsequent requirements in this file refine activation, *Site* assignment, edits, and lifecycle transitions on the account established here.


User Account
: The complete set of identity, credential, and authorization data that the **Sponsor Portal** maintains for a single human user.

Full Name
: The full name of the person associated with a **User Account**, comprising two separate fields: First Name (given name) and Last Name (family name). Personally identifiable information (**PII**) that identifies a specific individual in the context of the **Sponsor Portal**.

Email Address
: A unique technical identifier used as a destination for system notifications and as a username for authentication to access the system.

PII
: Personally Identifiable Information — data that identifies an individual, such as a person's name or email address.

### Assertions

A. The **System** SHALL require a **Full Name**, **Email Address**, at least one **Role**, and — for non-**Administrator** accounts — at least one **Site** to be selected before a **User Account** is created.

B. The **System** SHALL validate the format of the *Email Address* provided (e.g., presence of an "@" symbol).

C. The **System** SHALL allow assignment of the **Administrator**, **CRA** and **Study Coordinator** *Role* during *User* Account creation.

### Rationale

A **User Account** is the unit of authorization and audit attribution in the **Sponsor Portal**: every *Action* recorded in the *Audit Trail* is bound to the account that performed it, and every permission check resolves against the account's assigned roles and Sites. Requiring **Full Name**, **Email Address**, *Role*, and (for non-Administrators) at least one *Site* at creation time ensures the account is fully addressable, fully scoped, and fully attributable from the moment it exists; partial accounts that lack one of these fields would either be unable to receive activation email, unable to participate in audit reporting, or unable to be authorized for any operation. Validating the email format at the creation boundary catches obvious typos before the activation flow consumes an invalid address.

*End* *Create User Account* | **Hash**: 862753f8

## DIARY-PRD-user-account-activation-workflow: Account Activation Workflow

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create

### Overview

The account activation process starts when a **User Account** is created, reactivated, or when an activation email is sent again. Activation links are time-limited and can only be used once, which helps protect account security. A *User* cannot access the system until their account has been successfully activated.


Verification Link
: A unique, time-limited, single-use secured URL delivered to an email address to confirm that the recipient controls that address.

Activation Webpage
: A **Verification Link** associated with a **User Account** that provides a mechanism for the **Account Owner** to activate their account and configure their password and 2FA.

Account Owner
: The person associated with a **User Account**, who activates and uses it.

### Assertions

**Account States**

A. When the status of the **User Account** is **Pending Activation**, the *User* SHALL NOT be able to access the system.

**Activation Webpage Lifecycle**

B. When a **User Account** is set to **Pending Activation**, the **System** SHALL create a unique **Activation Webpage** for that **User Account**.

C. When an **Activation Webpage** is created, the **System** SHALL deliver it to the associated **User Account** owner's registered **Email Address**. The username of the *User* is the **Email Address** that has been entered during *User* creation.

D. When a **User Account** owner has activated their account and configured a valid *Password* and 2FA, the **System** SHALL set its status to **Active**.

**Email Address Verification Lifecycle**

E. When an **Administrator** updates the *Email Address* of a *User*, a new **Verification Link** is generated and sent to that updated *Email Address*. When the **Verification Link** is used, the **System** SHALL replace the previous **Email Address** with the new **Email Address** as the **User Account**'s username.

**Verification Link Behavior**

F. When a **Verification Link** is used or 14 days have passed from generation, whichever occurs first, the **System** SHALL invalidate the **Verification Link**.

G. When a new **Verification Link** is issued for a **User Account**, the **System** SHALL invalidate any previously issued **Verification Link** for that **User Account**.

**Rejection Behavior**

H. When a *User* attempts to access an invalidated **Verification Link**, the **System** SHALL reject the attempt and display the following message: "This link is no longer valid. Please contact your *Administrator* to request a new activation email."

### Rationale

Account activation is the boundary at which a candidate **User Account** (created or restored by an *Administrator*) becomes a credentialed account that can authenticate. Two security properties are essential at this boundary: control of the registered *Email Address* (verified by delivering a single-use link to that address), and a bounded window in which the verification holds (14 days). Single-use enforcement prevents the link from being replayed if it leaks; expiry caps the window during which a stolen or stale link could be exploited; invalidating prior links when a new one is issued ensures that resend operations do not leave multiple valid paths open simultaneously. The mid-lifecycle email-update path uses the same verification mechanism so that an *Administrator*-initiated address change cannot redirect login to an address the *User* does not control. The rejection message is deliberately generic — it directs the *User* to the *Administrator* without disclosing whether the underlying account exists, which preserves *User*-enumeration resistance.

*End* *Account Activation Workflow* | **Hash**: bc27bb86

## DIARY-PRD-user-account-site-assignment: Site Assignment

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create

### Overview

**Sites** are managed in **Rave EDC**. The portal displays **Sites** for assignment purposes only and does not allow modification, to maintain data integrity. Near real-time synchronization ensures that the *Site* list reflects the data within **Rave EDC** at all times.


Site
: A clinical research location authorized by the Sponsor to enroll **Participants** and conduct trial activities. Each **Site** is uniquely identified and synchronized from **Rave EDC**.

### Assertions

A. The system SHALL include only **Sites** that are created in **Rave EDC**.

B. The system SHALL refresh the list of valid **Sites** each time an **Administrator** logs in.

C. An **Administrator** SHALL have access to all **Sites**.

D. The system SHALL allow an **Administrator** to assign any **Site** to a **User Account**.

### Rationale

**Sites** are clinical *Trial* entities owned by the EDC system of record, not by the portal; replicating *Site* authorship in the portal would create a divergent inventory and break the EDC-to-portal data-integrity contract. The portal therefore reads the *Site* list and never edits it, refreshing on *Administrator* login so that newly-created Sites are available promptly for assignment without requiring an explicit sync *Action*. Administrators are granted study-wide *Site* visibility because their accountability for **User Account** lifecycle requires they be able to assign any *Site* to any account; restricting Administrators to a *Site* subset would block legitimate account configuration and create operational deadlocks during staff onboarding.

*End* *Site Assignment* | **Hash**: 3aa95698

## DIARY-PRD-user-account-activation-resend: Resend Activation Email

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-activation-workflow

### Overview

A *User* may not receive or may lose their activation email before completing setup. Resending generates a new **Activation Webpage** and invalidates the previous one, ensuring only one valid link exists at any time.

### Assertions

A. While the status of the **User Account** is **Pending Activation**, the system SHALL allow the **Administrator** to resend a new activation email.

B. The system SHALL NOT impose a limit on the number of resend attempts for a **Pending Activation** **User Account**.

C. When an activation email is resent, the system SHALL create a new **Activation Webpage** for that **User Account** and invalidate the previous one.

### Rationale

The activation email is the only delivery channel for the **Activation Webpage**, and legitimate failure modes (spam filtering, address typos surfaced after creation, transient email infrastructure issues) are common. Allowing unlimited resends keeps the recovery path open for the *Administrator* without requiring an escalation channel; the resend operation is itself audited and rate-limited only by the *Administrator*'s manual cadence, so abuse potential is low. Invalidating the previous link on each resend keeps the single-valid-link invariant from the parent activation workflow intact: at most one **Verification Link** exists per **User Account** at any moment, regardless of how many times the activation email has been resent.

*End* *Resend Activation Email* | **Hash**: fb61a75a

## DIARY-PRD-user-account-edit: Edit User Account

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create

### Overview

This functionality allows *User* access to be updated as roles or responsibilities change. If access is removed or changed, the *User* is immediately logged out by the system to prevent access to information they should no longer see. When an *Email Address* is updated, the new one must be verified by the *User* again before using their *User* account.

### Assertions

A. The **System** SHALL allow an **Administrator** to edit any **User Account** other than their own, including another **Administrator** account.

B. The **System** SHALL require at least one **Role** for non-**Administrator** users.

C. The **System** SHALL require at least one **Site** for non-**Administrator** users.

D. The **System** SHALL validate **Email Address** uniqueness across all existing **User Accounts**.

E. When an **Administrator** changes a **User Account**'s **Role** or **Site**, the **System** SHALL enforce the change immediately.

F. When an **Administrator** changes a **User Account**'s **Email Address**, the **System** SHALL deliver a **Verification Link** to the new **Email Address**.

G. When an **Administrator** initiates an **Email Address** change, the **System** SHALL notify the **User Account** owner at the original **Email Address** that a change has been initiated.

### Rationale

*User* edits encode three risks the platform contains structurally. First, an *Administrator* editing their own account could escalate privilege or remove their own *Deactivation* safeguard; prohibiting self-edit closes that channel. Second, *Role* or *Site* changes that take effect on the next login leave a window in which a *User* retains stale authorization; enforcing the change immediately collapses that window. Third, an email change is effectively a credential change (the email is the username and the activation channel), so the new address must be verified by the same mechanism used at account creation, and the prior address must be notified so that an unauthorized change initiated against an unattended *Administrator* *Session* is visible to the legitimate *Account Owner*. The regular **Administrator**↔**Administrator** path is explicitly permitted by assertion A.

*End* *Edit User Account* | **Hash**: fbc46f1c

## DIARY-PRD-user-account-deactivate: Deactivate User Account

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create
**Satisfies**: DIARY-PRD-reason-field-constraints

Deactivation
: The action of revoking a **User Account**'s ability to access the system without permanently removing the account or its associated data. A deactivated account retains all historical data and **Audit Trail** but cannot be used to log in or maintain active sessions.

### Assertions

A. The System SHALL allow an **Administrator** to deactivate any **User Account** except their own, including another **Administrator** account.

B. The System SHALL terminate all active sessions associated with a **User Account** immediately upon **Deactivation**.

C. The System SHALL prevent login to a deactivated **User Account**.

D. The System SHALL preserve all data and **Audit Trail** associated with a deactivated **User Account**.

E. The System SHALL set the status of a deactivated **User Account** to **Deactivated**.

F. When an **Administrator** deactivates a **User Account**, the **System** SHALL require a free text reason before applying the change. The reason SHALL be captured in the *Audit Trail*.

### Rationale

*Deactivation* is the standard off-boarding mechanism for users who should no longer access the system — completion of a study assignment, *Role* change off the study, departure from the *Sponsor* or *Site* organization. Retaining the account record and its full **Audit Trail** is required by *FDA 21 CFR Part 11*: every historical *Action* attributed to that account must remain auditable indefinitely, even after the account is no longer usable. Terminating active sessions immediately is necessary because any *Session* in flight at *Deactivation* time was authenticated under the about-to-be-revoked credentials and must be invalidated to honor the access decision. Prohibiting self-*Deactivation* closes a denial-of-service vector against the *Administrator* workforce (an *Administrator* deactivating themselves and leaving no other active *Administrator* could lock out the deployment). The free-text reason is captured to support audit reviews of why each account was deactivated.

*End* *Deactivate User Account* | **Hash**: e31cba84

## DIARY-PRD-user-account-reactivate: Reactivate User Account

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-deactivate
**Satisfies**: DIARY-PRD-reason-field-constraints

### Assertions

A. The System SHALL support reactivation of any deactivated **User Account**.

B. When a **User Account** is reactivated, the system SHALL restore all previously assigned roles and **Site** assignments.

C. Upon reactivation, the status of the **User Account** SHALL be set to **Pending Activation** state.

D. When an **Administrator** reactivates a **User Account**, the **System** SHALL require a free text reason before applying the change. The reason SHALL be captured in the *Audit Trail*.

### Rationale

Reactivation is the inverse of *Deactivation* and serves the case where a previously off-boarded *User* resumes a *Role* on the study — a returning *Study Coordinator*, an *Administrator* restored after a leave of absence. Restoring previously assigned roles and **Site** assignments is the operational expectation: the reactivation event is logically "this same person, same responsibilities, again", not a fresh account creation. Routing the reactivated account through **Pending Activation** rather than directly to **Active** is a security floor: the *User* must complete a fresh activation flow, which proves they still control the registered *Email Address* and produces a current credential (*Password*, 2FA) rather than reviving stale credentials that may have been compromised during the deactivated interval. The free-text reason is captured for the same audit purpose as *Deactivation*.

*End* *Reactivate User Account* | **Hash**: eb83c7e5

## DIARY-PRD-reason-field-constraints: Reason Field Constraints

**Level**: PRD | **Status**: Draft | **Implements**: - | **Template**

### Overview

Where a reason is required before an *Action* proceeds, consistent input constraints ensure reasons are meaningful and auditable. Empty or whitespace-only submissions are rejected to ensure every high-impact *Action* is accompanied by a documented reason for compliance purposes. This requirement is the platform-wide template for free-text reason inputs and is referenced by every Reason Dialog (Free Text) defined elsewhere in the specification.

### Assertions

A. Where the **System** requires a reason, the **System** SHALL reject a *Submission* where the reason is empty or contains only whitespace.

B. Where the **System** requires a reason, the **System** SHALL enforce a maximum input length of 100 characters.

### Rationale

Free-text reason inputs accompany high-impact, irreversible actions (*Deactivation*, disconnection, mark-as-not-participating, record deletion) and are the principal narrative artifact the *Audit Trail* carries forward for those actions. Two failure modes degrade their audit value: empty or whitespace-only submissions (which let users bypass the reason requirement while passing the input control) and unbounded length (which lets users paste pages of irrelevant text that obscure the actual rationale). The whitespace rejection rule eliminates the former; the 100-character cap addresses the latter while still leaving room for a usefully descriptive sentence. Both constraints are platform-wide so reviewers see consistent reason-field behavior across every *Action* that requires one, and so the audit log's free-text field has predictable bounds.

*End* *Reason Field Constraints* | **Hash**: b7b8a786

## DIARY-GUI-user-management-tabs: User Management Tabs

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create, DIARY-PRD-user-account-edit

### Overview

The *User* management interface separates active and inactive accounts into distinct tabs to reduce cognitive load and prevent accidental actions on the wrong account. Real-time search and preserved search state allow Administrators to work efficiently across tabs without losing context.


Active Users
: The **User Management** tab listing **User Accounts** in Active status.

Inactive Users
: The **User Management** tab listing **User Accounts** in Inactive status.

Assigned Sites
: The **Sites** a **User Account** is authorized to access, scoping the **Participants** and data the user can see.

### Assertions

**Tab Display**

A. The interface SHALL display two tabs: *Active Users* and *Inactive Users*.

B. The *Active Users* tab SHALL display all *User* Accounts with a status of Active or Pending Activation.

C. The *Inactive Users* tab SHALL display all *User* Accounts with a status of Deactivated.

D. The interface SHALL display the *Active Users* tab by default.

E. The interface SHALL highlight the currently active tab.

F. Each tab SHALL display the total count of *User* Accounts it contains inline with the tab label.

G. When a *User* Account status changes, the interface SHALL move the account to the appropriate tab immediately.

**Search Behavior**

H. The interface SHALL provide a single search input that filters *User* Accounts by *Full Name* and *Email Address*.

I. The interface SHALL update search results in real time as the *User* types.

J. The interface SHALL preserve the search state when the *User* switches between tabs.

**Empty State**

K. When a tab contains no *User* Accounts matching the current search, the interface SHALL display a message indicating no results were found.

**Row Display**

L. The interface SHALL display each **User Account** as a row showing **Full Name**, **Email Address**, **Role(s)**, **Assigned Sites**, and **Status**.

M. Each **User Account** row SHALL be selectable and open the **User Information Modal**.

N. The interface SHALL display a **Create User** *Action*.

### Rationale

Active and inactive accounts are operationally distinct surfaces: actions available on one are not available on the other, and the most common *Administrator* error in unified lists is acting on an inactive account believing it was active. Splitting into two tabs makes the active/inactive distinction structural rather than visual, and immediate row-movement on status change keeps each tab self-consistent without manual refresh. Real-time search across **Full Name** and **Email Address** matches the two identifiers Administrators use in practice (a *Full Name* supplied by someone reporting an issue, or an *Email Address* supplied by the *User* themselves). Preserving search state across tabs supports the recurring workflow of "search for a *User*, check Active, then check Inactive" without forcing the *Administrator* to retype the query. Row selection opens the **User Information Modal** rather than navigating away, so the table context remains visible behind the modal and consecutive lookups are quick.

*End* *User Management Tabs* | **Hash**: 763777de

## DIARY-GUI-user-account-deactivate: Deactivate User Account

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-deactivate
**Satisfies**: DIARY-PRD-reason-field-constraints

### Overview

The *Deactivation* *Action* is available from the *Active Users* tab only, since deactivated accounts are no longer present there after the *Action* completes.

### Assertions

**Availability**

A. The interface SHALL make the *Deactivation* *Action* available for every **User Account** displayed in the **Active Users** tab, with the exception of the current *User*'s own account.

**Interaction Flow**

B. When the *Deactivation* *Action* is initiated, the interface SHALL display the confirmation dialog and require a free text reason before proceeding.

C. The interface SHALL not allow the *Deactivation* *Action* to proceed until a reason has been provided.

D. If the *User* cancels the confirmation, the **User Account** will remain unchanged.

E. When *Deactivation* is confirmed, the interface SHALL move the **User Account** to the **Inactive Users** tab immediately.

### Rationale

The *Deactivation* surface is anchored to the **Active Users** tab because that is where the *Administrator* finds candidates for *Deactivation*; offering the same *Action* from the *Inactive Users* tab would be either a no-op (the account is already deactivated) or a confusing alternative entry point. Excluding the *Administrator*'s own account from the *Action* list closes the self-*Deactivation* channel from the GUI side, complementing the PRD-level prohibition and making the unavailable state visible rather than producing a back-end rejection after the *Administrator* has invested in the workflow. Requiring the reason at the confirmation step rather than after the *Action* commits gives the *Administrator* a final opportunity to back out and ensures the reason is captured before any state change is applied.

*End* *Deactivate User Account* | **Hash**: bb9d75f2

## DIARY-GUI-user-account-reactivate: Reactivate User Account

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-reactivate
**Satisfies**: DIARY-PRD-reason-field-constraints

### Overview

Reactivation is initiated from the *Inactive Users* tab and immediately returns the account to the *Active Users* tab with **Pending Activation** status, requiring the *User* to complete the activation workflow before regaining access.

### Assertions

**Availability**

A. The interface SHALL make the reactivation *Action* available for every **User Account** displayed in the **Inactive Users** tab.

**Interaction Flow**

B. When the reactivation *Action* is initiated, the interface SHALL display the confirmation dialog and require a free text reason before proceeding.

C. The interface SHALL NOT allow the reactivation *Action* to proceed until a reason has been provided.

D. If the *User* cancels the confirmation, the **User Account** will remain unchanged.

E. When reactivation is confirmed, the interface SHALL move the **User Account** to the **Active Users** tab immediately with a status of **Pending Activation**.

### Rationale

Reactivation is anchored to the **Inactive Users** tab to mirror the *Deactivation* pattern: the candidate set lives in the inactive tab, and the *Action* there is the only one available. Moving the account to the **Active Users** tab with **Pending Activation** status on confirmation makes the next-step responsibility (the *User* must complete the activation flow before logging in) immediately visible — the account is back in the active surface and its status badge communicates that login is gated on activation. The free-text reason is gathered at the same confirmation step as *Deactivation* for symmetry and to keep the *Audit Trail*'s reason fields populated for every reactivation event.

*End* *Reactivate User Account* | **Hash**: 15f0d2fd

## DIARY-GUI-user-information-modal: User Information Modal

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-create, DIARY-PRD-user-account-edit

### Overview

The **User Information Modal** provides a summary view of a **User Account** and the primary actions available for that account. All account management actions are initiated from this modal.


User Information Modal
: A modal dialog displaying the details and available actions for a selected **User Account**.

### Assertions

**Display**

A. The **User Information Modal** SHALL display the **Full Name**, **Email Address**, **Status**, assigned **Role**(s), and **Site** assignments of the selected **User Account**.

B. The **User Information Modal** SHALL display every **Role** assigned to the **User Account**.

C. When the **User Account** is an **Administrator**, the interface SHALL indicate that the **User Account** has access to all **Sites**.

D. When the **User Account** holds one or more non-**Administrator** **Roles**, the interface SHALL allow the viewer to select a single **Role** to scope the **Site** list.

E. When a **Role** is selected, the interface SHALL display only the **Site(s)** assigned to the **User Account** under that **Role**.

F. The interface SHALL display the total count of **Sites** assigned to the selected **Role**.

G. The interface SHALL display each **Site** entry using the **Site** identifier and **Site** name.

H. The interface SHALL indicate which **Role** is currently selected.

**Actions**

I. The **User Information Modal** SHALL present an **Edit User** *Action*, a **Deactivate User** *Action*, and a **Close** *Action* for accounts displayed in the **Active Users** tab.

J. The **User Information Modal** SHALL present a **Reactivate User** *Action* and a **Close** *Action* for accounts displayed in the **Inactive Users** tab.

K. The **User Information Modal** SHALL NOT present a **Deactivate User** *Action* for the currently authenticated *User*'s own account.

L. When the *User* selects **Close**, the interface SHALL dismiss the modal without making any changes.

M. When the *User* selects **Edit User**, the interface SHALL open the edit workflow for that **User Account**.

N. The **User Information Modal** SHALL display the heading "*User* Information".

O. The **User Information Modal** SHALL display a distinct icon alongside each *Action* it presents.

### Rationale

The **User Information Modal** is the per-account hub: every lifecycle *Action* (edit, deactivate, reactivate) launches from here, and every account-related question (who, what *Role*, which Sites) is answered here. Scoping the *Site* list by *Role* addresses the multi-*Role* case directly — a *User* holding both *Study Coordinator* and CRA roles on overlapping but distinct *Site* sets is shown the correct subset for whichever *Role* context the *Administrator* is reasoning about. Surfacing **Sites** by *Role* rather than as a flat union prevents the inverse error in which an *Administrator* believes a *User* has *Study Coordinator* access at a *Site* that they actually have only as a CRA. Suppressing **Deactivate User** on the current *User*'s own account mirrors the PRD-level self-*Deactivation* prohibition and the GUI-level *Active Users* tab rule, so the unavailable state is consistent across every surface a self-*Deactivation* attempt could originate from. The modal's heading and a distinct icon per *Action* are fixed so the surface reads as deliberate product: a mistitled modal or a label-only *Action* (one glyph rendering, its neighbor blank) reads as unfinished or broken, and the icons let an *Administrator* distinguish a benign edit from a destructive *Deactivation* at a glance.

*End* *User Information Modal* | **Hash**: 843f9afb

## DIARY-GUI-administrator-dashboard: Administrator Dashboard

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Overview

The **Administrator Dashboard** is the primary surface for an **Administrator** to manage **User Accounts** and review *Audit Log* activity. Organising the surface as a container with two top-level tabs separates **User Account** management from *Audit Log* review while keeping both areas reachable from a single entry point. The dashboard scaffolding defined here establishes the header, the top-level tab navigation, and the default landing tab; the contents of each tab are governed by the requirements referenced from those tabs.


Administrator Dashboard
: The default surface presented to an **Administrator** upon successful authentication to the **Sponsor Portal**, containing top-level navigation to **User Account** management and audit log review.

### Assertions

**Header**

A. The interface SHALL display a header at the top of the **Administrator Dashboard** containing the **Sponsor Portal** name, the **Full Name** of the authenticated *User*, the *User*'s active **Role**, a **Settings** *Action*, and a **Logout** *Action*.

B. The header SHALL remain visible on every screen of the **Administrator Dashboard**.

C. When the **Administrator** selects **Settings**, the interface SHALL navigate to the **Administrator Settings** surface defined in *Diary*-GUI-*Administrator*-settings.

**Top-Level Tabs**

D. The **Administrator Dashboard** SHALL display two top-level tabs: **Users** and **Audit Logs**.

E. The **Users** tab SHALL display the *User* Management interface defined in *Diary*-GUI-*User*-management-tabs.

F. The **Audit Logs** tab SHALL display the *Administrator* *Audit Log View* defined in *Diary*-GUI-audit-log-*Administrator*.

G. The interface SHALL display the **Users** tab by default upon login.

H. The interface SHALL display a visual indicator identifying the currently active top-level tab.

**Logout**

I. When the **Administrator** selects **Logout**, the **System** SHALL terminate the **Session** and return the **Administrator** to the **Sponsor Portal** login interface.

### Rationale

The **Administrator Dashboard** consolidates the two responsibilities of the **Administrator** *Role* — **User Account** management and audit review — into adjacent tabs of a single surface so the *Administrator* can switch between investigating an account and reviewing the *Audit Log* without navigating away from a shared context. A persistent header keeps identity (who is logged in, in what *Role*), system context (which *Sponsor* Portal), settings access, and logout reachable from any screen of the dashboard, which is necessary because an *Administrator* may need to log out from any state without first navigating back to a landing page. Defaulting to the **Users** tab on login matches the most common *Administrator* entry point (open the dashboard to perform account actions); the Audit Logs tab is one click away when investigation is the goal.

*End* *Administrator Dashboard* | **Hash**: bdabc38a
