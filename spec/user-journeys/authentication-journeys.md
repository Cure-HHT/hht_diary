# Authentication & Account Lifecycle — User Journeys

> **Role**: Administrator
> **Source**: spec/prd-portal-auth.md, spec/prd-user-account.md, spec/prd-rbac.md
> **Scope**: Sponsor Portal (web). Each journey is one happy-path interaction lifecycle that begins with a fresh browser on the portal login page (no active session). These authentication journeys are written for the Administrator role but the underlying flows are shared across portal roles.

---

# JNY-AUTH-01: Accept Activation Invite & Set Initial Password

**Actor**: Jordan Avery, a newly created Sponsor Portal Administrator
**Goal**: Activate the account from the invitation email and set an initial password so the account becomes usable
**Context**: An existing Administrator has just created Jordan's account, which is in **Pending Activation** status. Jordan has received the activation email but has never signed in.

Validates: DIARY-PRD-user-account-activation-workflow-C+F

**Spec gap**: No DIARY-GUI requirement defines the activation / set-password screen. This journey validates the PRD activation behavior only; the set-password UI mirrors the Forgot Password reset screen (DIARY-GUI-password-forgot-workflow) by convention.

## Steps

1. Jordan opens the activation email and clicks the verification link.
2. The browser opens the portal activation screen with two password fields (New Password and Confirm Password), each with a show/hide toggle.
3. Jordan enters a password that meets the composition rules (12+ characters, upper- and lower-case, a number, and a special character) and re-enters it in the Confirm field.
4. Jordan submits the form.
5. The system validates the password against the composition and reuse rules, accepts it, sets the account to **Active**, and records the account as activated.
6. The system redirects Jordan to the login page with a success confirmation.

## Expected Outcome

The activation link is consumed (single-use) and the account is **Active**. Jordan can now log in with the new password. Re-using the same activation link afterward shows an invalid-link result.

*End* *Accept Activation Invite & Set Initial Password*

---

# JNY-AUTH-02: Log In With Two-Factor Authentication

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Sign in to the portal and reach the Administrator Dashboard
**Context**: Jordan's account is **Active**. The browser is on the portal login page with no active session.

Validates: DIARY-PRD-two-factor-authentication-A+B+C, DIARY-PRD-session-management-A

**Spec gap**: No DIARY-GUI requirement defines the login or two-factor code-entry screens. This journey validates the PRD two-factor and session behavior only.

## Steps

1. Jordan enters their email address and password on the login page and submits.
2. The system verifies the credentials and sends a single-use verification code to Jordan's email.
3. The system presents the second-factor screen prompting for the verification code.
4. Jordan retrieves the code from email and enters it.
5. The system validates the code (single-use, time-limited) and establishes an authenticated session.
6. The system lands Jordan on the Administrator Dashboard (Users tab) with the persistent header showing their name and active role.

## Expected Outcome

Jordan holds an active session and sees the Administrator Dashboard. The verification code cannot be reused, and the session is subject to the configured idle timeout.

*End* *Log In With Two-Factor Authentication*

---

# JNY-AUTH-03: Reset a Forgotten Password

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Regain access after forgetting the account password
**Context**: Jordan cannot remember their password. The browser is on the portal login page.

Validates: DIARY-PRD-password-forgot-A+B+C+D+F+G+H, DIARY-GUI-password-forgot-workflow-A+B+D+E+F+G+H+I+K+L+M+N+O+P+R

## Steps

1. Jordan clicks the "Forgot Password" action on the login page.
2. On the request screen, Jordan enters their email address; the Submit button enables only once a validly formatted email is present, and Jordan submits.
3. The interface navigates to a confirmation screen that displays the same content regardless of whether the email matches an account, states the link expiry duration, and suggests checking the spam folder.
4. Jordan opens the password-reset email and clicks the verification link.
5. The browser opens the reset screen with New Password and Confirm Password fields, each with a show/hide toggle; Submit enables only when both fields match and are populated.
6. Jordan enters a compliant new password and submits.
7. The system updates the credential, terminates all of Jordan's active sessions, and returns to the login page with a success confirmation.

## Expected Outcome

The reset link is consumed (single-use) and the password is updated. Jordan must complete two-factor authentication on the next login. An expired or already-used link instead shows the invalid-link screen with an option to restart the flow.

*End* *Reset a Forgotten Password*

---

# JNY-AUTH-04: Switch Active Role

**Actor**: Jordan Avery, an Administrator who also holds the Study Coordinator role
**Goal**: Switch from the Administrator role to another assigned role without signing out
**Context**: Jordan is logged in and viewing the Administrator Dashboard. Jordan has more than one assigned role, so the role selector is visible in the header.

Validates: DIARY-PRD-rbac-customizable-A+B, DIARY-GUI-role-switching-A+C+D+E+F+G

## Steps

1. Jordan opens the role selector in the header, which shows the current active role.
2. The selector displays the complete list of Jordan's assigned roles, with the current role visually indicated.
3. Jordan selects a different role.
4. Without any confirmation step, the interface loads the default landing view for the selected role.
5. The session remains active throughout; subsequent requests carry the newly selected role.

## Expected Outcome

Jordan is now operating under the newly selected role with its default landing view, using the same uninterrupted session. The role selector header reflects the new active role.

*End* *Switch Active Role*

---

# JNY-AUTH-05: Log Out

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: End the portal session deliberately
**Context**: Jordan is logged in and finished working. Any dashboard screen is showing the persistent header.

Validates: DIARY-PRD-session-management-D, DIARY-GUI-administrator-dashboard-I

## Steps

1. Jordan clicks the Logout action in the persistent header.
2. The system terminates the session and invalidates the session state.
3. The system returns the browser to the portal login page.

## Expected Outcome

The session is ended. Returning to a protected page or replaying the prior session requires a fresh login, including two-factor authentication.

*End* *Log Out*
