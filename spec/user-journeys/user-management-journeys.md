# User Management — Administrator User Journeys

> **Role**: Administrator (Administrator-only capabilities)
> **Source**: spec/prd-user-account.md, spec/prd-rbac.md
> **Scope**: Sponsor Portal (web). Each journey is one happy-path interaction lifecycle that begins with the Administrator already signed in and on the Administrator Dashboard (Users tab is the default landing view).

---

# JNY-USER-01: Create a New User Account

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Create a new portal user and trigger their activation invitation
**Context**: Jordan is on the Administrator Dashboard, Users tab. A new Study Coordinator needs portal access for a specific site.

Validates: DIARY-PRD-user-account-create-A+B+C, DIARY-PRD-user-account-site-assignment-A+C+D, DIARY-GUI-user-management-tabs-B+N

**Spec gap**: No DIARY-GUI requirement defines the create-user form layout itself; only the presence of the Create User action is specified (DIARY-GUI-user-management-tabs). This journey validates the create PRD behavior and the action's availability.

## Steps

1. Jordan clicks the "Create User" action in the user-management interface.
2. The create-user form appears. Jordan enters the Full Name and Email Address.
3. Jordan selects at least one role for the account (Administrator, CRA, or Study Coordinator).
4. Because the account is not an Administrator account, Jordan assigns at least one site from the site list (sourced from Rave EDC; Jordan can assign any site).
5. Jordan submits the form.
6. The system validates the email format and uniqueness, creates the account with status **Pending Activation**, and generates and sends an activation email to the new address.
7. The new account appears on the Active Users tab with **Pending Activation** status.

## Expected Outcome

A new user account exists in **Pending Activation** status with the specified name, email, role(s), and site(s), and an activation email has been delivered. The account cannot sign in until it is activated.

*End* *Create a New User Account*

---

# JNY-USER-02: Edit a User's Roles and Sites

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Change another user's role and site assignments
**Context**: Jordan is on the Administrator Dashboard, Users tab. An existing user's responsibilities have changed.

Validates: DIARY-PRD-user-account-edit-A+B+C+E, DIARY-GUI-user-information-modal-A+M

## Steps

1. Jordan searches for the user by name or email; the list filters in real time.
2. Jordan clicks the user's row to open the User Information Modal, which shows the Full Name, Email Address, status, assigned role(s), and site assignments.
3. Jordan clicks the "Edit User" action.
4. Jordan adjusts the role and/or site assignments, keeping at least one role and (for non-Administrator roles) at least one site.
5. Jordan submits the changes.
6. The system validates the input and applies the changes immediately; because role/site assignments changed, the system terminates that user's active sessions.

## Expected Outcome

The user's role and site assignments reflect the edits immediately. If the user was signed in, their sessions are terminated so the new authorization takes effect on next login. Jordan cannot edit their own account through this flow.

*End* *Edit a User's Roles and Sites*

---

# JNY-USER-03: Deactivate a User Account

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Revoke a user's portal access while preserving their history
**Context**: Jordan is on the Administrator Dashboard, Users tab, Active Users sub-tab. A user has left the study team.

Validates: DIARY-PRD-user-account-deactivate-A+B+C+D+E+F, DIARY-GUI-user-account-deactivate-A+B+C+E

## Steps

1. Jordan clicks the user's row (not their own) to open the User Information Modal.
2. Jordan clicks the "Deactivate User" action.
3. A confirmation dialog appears with a required free-text reason field.
4. Jordan enters a reason (non-empty, at most 100 characters; whitespace-only is rejected); the Submit button enables only once the reason is valid.
5. Jordan confirms.
6. The system records the action and reason in the audit trail, terminates the user's active sessions, sets the account to **Deactivated**, and preserves all historical data and audit entries.
7. The account moves to the Inactive Users sub-tab.

## Expected Outcome

The account is **Deactivated** and can no longer sign in; its data and audit trail remain intact, and the deactivation is attributable with the recorded reason. Jordan cannot deactivate their own account.

*End* *Deactivate a User Account*

---

# JNY-USER-04: Reactivate a Deactivated User Account

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Restore access for a previously deactivated user
**Context**: Jordan is on the Administrator Dashboard, Users tab, Inactive Users sub-tab. A previously deactivated user is returning to the study team.

Validates: DIARY-PRD-user-account-reactivate-A+B+C+D, DIARY-GUI-user-account-reactivate-A+B+C+E

## Steps

1. Jordan clicks the deactivated user's row to open the User Information Modal.
2. Jordan clicks the "Reactivate User" action.
3. A confirmation dialog appears with a required free-text reason field (non-empty, at most 100 characters).
4. Jordan enters a reason and confirms.
5. The system records the action and reason in the audit trail, restores the user's previously assigned roles and sites, and sets the account to **Pending Activation**.
6. The account moves back to the Active Users sub-tab with **Pending Activation** status, and an activation email is generated.

## Expected Outcome

The account is restored with its prior roles and sites and is in **Pending Activation**; the user must complete the activation flow before they can sign in again. The reactivation is attributable with the recorded reason.

*End* *Reactivate a Deactivated User Account*

---

# JNY-USER-05: Resend an Activation Email

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Re-send the activation invitation to a user who has not yet activated
**Context**: Jordan is on the Administrator Dashboard, Users tab, viewing a user in **Pending Activation** status whose original activation email was lost.

Validates: DIARY-PRD-user-account-activation-resend-A+C

**Spec gap**: No DIARY-GUI requirement defines the resend-activation action or its placement. This journey validates the resend PRD behavior only.

## Steps

1. Jordan opens the User Information Modal for the **Pending Activation** user.
2. Jordan triggers the "Resend Activation Email" action.
3. The system generates a new activation code, invalidates the prior code, and delivers a new activation email to the user's registered address.
4. The system confirms the email was sent.

## Expected Outcome

A fresh activation email is delivered and any prior activation link is now invalid. There is no limit on how many times the activation email may be resent.

*End* *Resend an Activation Email*

---

# JNY-USER-06: Browse and Search User Accounts

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Find and review user accounts across active and inactive states
**Context**: Jordan has just signed in and is on the Administrator Dashboard, Users tab (the default landing view).

Validates: DIARY-GUI-user-management-tabs-A+B+C+D+E+F+H+I+J+K+L, DIARY-GUI-administrator-dashboard-E+G

## Steps

1. Jordan sees the Users tab with two sub-tabs — Active Users (default) and Inactive Users — each showing a count and the currently active sub-tab highlighted.
2. Jordan reviews the Active Users list, where each row shows Full Name, Email Address, role(s), assigned sites, and status (Active or Pending Activation).
3. Jordan types part of a name or email into the search field; both sub-tabs filter in real time.
4. Jordan switches to the Inactive Users sub-tab; the search term is preserved across the switch and the list shows Deactivated accounts.
5. Jordan clears the search; when a search yields nothing, an empty-state message is shown.

## Expected Outcome

Jordan can locate any account by name or email and see its role, site, and status across the Active and Inactive sub-tabs, with search state preserved when switching between them.

*End* *Browse and Search User Accounts*
