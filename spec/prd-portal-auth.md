# *Sponsor* Portal Authentication

**Sponsor Portal** authentication comprises *Password* composition and reuse rules, two-factor authentication, forgot-*Password* recovery (PRD plus the workflow GUI), and *Session* management.

## DIARY-PRD-password-requirements: Password Requirements

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-access-control-identity

Password
: A secret string of characters used to authenticate a user's identity when accessing the **System**.

Password Reuse Limit
: The configurable number of the user's most recent **Passwords** that a new **Password** must not match.

### Assertions

A. The **System** SHALL require a **Password** to be a minimum of 12 characters in length.

B. The **System** SHALL require a **Password** to contain at least one uppercase letter, one lowercase letter, one numeric character, and one special character.

C. The **System** SHALL reject a **Password** that is commonly used or easily guessable as per NIST SP 800-63B commonly used *Password* list.

D. The **System** SHALL require a **Password** to be changed after 90 days, unless a different interval has been configured for the study.

E. The **System** SHALL prevent a *User* from accessing the **System** until their **Password** has been changed upon expiry.

F. The **System** SHALL reject a new **Password** that matches any of the *User*'s previous **Password Reuse Limit** **Passwords**, where **Password Reuse Limit** is configurable per study.

### Rationale

The composition rules (length, character classes) and the common-*Password* rejection are baseline defenses against credential-guessing attacks: each rule independently raises the cost of a successful brute-force or dictionary attempt, and together they place the minimum acceptable *Password* well above the threshold at which automated attacks succeed against unprotected accounts. The NIST SP 800-63B reference is the authoritative source for the common-*Password* list and is named explicitly so the deployment can update the list as NIST updates its guidance. The 90-day expiry is a *Sponsor*-overridable default; the override exists because some *Sponsor* deployments operate under regulatory regimes that mandate a different interval. The reuse-limit rule prevents the common operator behavior of cycling between two passwords (defeats the purpose of expiry); making the limit configurable lets a deployment choose how aggressive its reuse defense should be.

*End* *Password Requirements* | **Hash**: e31a37b2

## DIARY-PRD-two-factor-authentication: Two-Factor Authentication

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-access-control-identity

### Overview

Two-Factor Authentication adds a second independent factor beyond the **Password** to prevent unauthorized access in the event of credential compromise. The platform supports configurable second factors so each *Sponsor* Portal can select the method that best fits its operational and regulatory context.


Second Factor
: The independent authentication factor required in addition to the **Password** during login. The specific method is sponsor-configurable per study.

Verification Code
: A single-use, time-limited code presented as the **Second Factor** during login.

Code Expiry
: The configurable duration after which an unused **Verification Code** becomes invalid.

### Assertions

**Enforcement**

A. The **System** SHALL require Two-Factor Authentication for every login to the **Sponsor Portal**.

B. The **System** SHALL NOT grant access to the **Sponsor Portal** until both the **Password** and a valid **Verification Code** have been successfully validated.

**Verification Code Lifecycle**

C. When a **User Account** owner submits a valid **Password**, the **System** SHALL generate a **Verification Code** and deliver it via the configured **Second Factor** method.

D. The **System** SHALL ensure each **Verification Code** is single-use and is invalidated immediately upon successful use.

E. When a **Verification Code** has not been used within the **Code Expiry** duration, the **System** SHALL invalidate the **Verification Code**.

F. When a **Verification Code** has been invalidated, the **System** SHALL require the **User Account** owner to restart the login process to receive a new **Verification Code**.

**Configuration**

G. The **System** SHALL support *Sponsor*-configurable selection of the **Second Factor** method per study.

H. The **System** SHALL support *Sponsor*-configurable **Code Expiry** per study.

### Rationale

The single *Password* is no longer a sufficient credential for clinical *Trial* portal access: credential leakage from unrelated services, phishing, and shared-workstation compromise are all common, and any of them can hand an attacker a working *Password* without the *User* noticing. The *Second Factor* breaks that single-credential failure mode by requiring possession of an independent channel (email, authenticator app, or SMS, depending on *Sponsor* configuration) before access is granted. The **Verification Code** is single-use and time-limited because a code that survived either property would inherit the same replay vulnerability the *Second Factor* exists to prevent. *Sponsor*-configurability of the method and expiry duration recognises that the operational tradeoffs vary by deployment: a *Sponsor* with strict email infrastructure may choose a longer expiry; a *Sponsor* with authenticator-app adoption may choose a much shorter one.

*End* *Two-Factor Authentication* | **Hash**: b699486d

## DIARY-PRD-password-forgot: Forgot Password

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-access-control-identity

### Overview

A **User Account** owner who has forgotten their **Password** must be able to reset it without *Administrator* intervention. The reset mechanism uses a time-limited, single-use **Verification Link** delivered to the registered **Email Address** to confirm the requester controls the account.

### Assertions

**Initiation**

A. The **System** SHALL allow a **User Account** owner to initiate a **Password** reset from the **Sponsor Portal** login interface by providing their **Email Address**.

B. When a **Password** reset is initiated, the **System** SHALL generate a **Verification Link** and deliver it to the registered **Email Address**.

C. The **System** SHALL display a confirmation that an email has been sent regardless of whether the **Email Address** matches an existing **User Account**.

**Verification Link Behavior**

D. When a **Verification Link** issued for **Password** reset is used or 24 hours have passed from generation, whichever occurs first, the **System** SHALL invalidate the **Verification Link**.

E. When a new **Password** reset **Verification Link** is issued for a **User Account**, the **System** SHALL invalidate any previously issued **Password** reset **Verification Link** for that **User Account**.

**Reset Completion**

F. When a **User Account** owner accesses a valid **Verification Link**, the **System** SHALL allow them to set a new **Password**.

G. Upon successful **Password** reset, the **System** SHALL terminate all active sessions associated with that **User Account**.

H. The **System** SHALL require Two-Factor Authentication on the next login following a successful **Password** reset.

**Rejection Behavior**

I. When a **User Account** owner attempts to access an invalidated **Verification Link**, the **System** SHALL reject the attempt and prompt the *User* to initiate a new **Password** reset.

### Rationale

Self-service *Password* reset is a usability requirement (users who lose their **Password** must not be blocked from the system pending an *Administrator* escalation) and a security requirement (the reset mechanism must not become an attack channel). The verification-link mechanism mirrors the activation workflow: a single-use, time-bounded URL delivered to the registered *Email Address* is the credential that proves control of the account. The display-confirmation-regardless rule prevents *User* enumeration via the reset form — an attacker submitting addresses learns nothing about which ones exist in the system. Terminating all active sessions on successful reset and requiring 2FA on the next login closes the window in which a stolen *Session* or stolen 2FA token from the pre-reset interval could still operate against the now-changed account. The shorter expiry (24 hours, versus 14 days for activation) reflects the higher attack value of a *Password*-reset link compared to an activation link.

*End* *Forgot Password* | **Hash**: 0aa45cc5

## DIARY-GUI-password-forgot-workflow: Forgot Password Workflow Interface

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-password-forgot

### Overview

The Forgot *Password* workflow spans four screens: the request screen where the **User Account** owner enters their **Email Address**, the confirmation screen shown after *Submission*, the reset screen reached through a valid **Verification Link**, and the invalid link screen reached through an invalidated **Verification Link**. Consistent screen behavior across the flow ensures the **User Account** owner can complete recovery or recognize when to start over.

### Assertions

**Entry Point**

A. The **Sponsor Portal** login interface SHALL present a Forgot *Password* *Action* that navigates to the Forgot *Password* Request screen.

**Forgot Password Request Screen**

B. The Forgot *Password* Request screen SHALL present a single **Email Address** input field and a Submit *Action*.

C. The Forgot *Password* Request screen SHALL present a Back to Login *Action* that returns to the login interface.

D. The interface SHALL not enable the Submit *Action* until a value has been entered in the **Email Address** field.

E. The interface SHALL validate that the entered value conforms to a valid *Email Address* format before *Submission* is accepted.

F. When the Submit *Action* is invoked, the interface SHALL navigate to the Confirmation screen.

**Confirmation Screen**

G. The Confirmation screen SHALL display a message indicating that an email has been sent if the submitted **Email Address** is associated with an account.

H. The Confirmation screen SHALL display the duration after which the **Verification Link** expires.

I. The Confirmation screen SHALL display guidance to check the spam folder if the email is not received.

J. The Confirmation screen SHALL present a Back to Login *Action* that returns to the login interface.

K. The Confirmation screen SHALL display the same content regardless of whether the submitted **Email Address** matches an existing **User Account**.

**Reset Screen**

L. The Reset screen SHALL be reachable only by accessing a valid **Verification Link** delivered to the **User Account** owner's registered **Email Address**.

M. The Reset screen SHALL present a New **Password** field and a Confirm **Password** field.

N. Each **Password** field SHALL present a show/hide toggle that controls whether the entered value is displayed in plain text or masked.

O. The Reset screen SHALL present a Submit *Action*.

P. The interface SHALL not enable the Submit *Action* until both **Password** fields have been populated and contain matching values.

Q. When the Submit *Action* is invoked and the **Password** is rejected for failing composition or reuse rules, the interface SHALL display an inline message identifying which rule was violated and SHALL not navigate away from the Reset screen.

R. When the Submit *Action* is invoked and the **Password** is accepted, the interface SHALL navigate to the **Sponsor Portal** login interface and display a confirmation that the **Password** has been changed.

**Invalid Link Screen**

S. When a **User Account** owner accesses an invalidated **Verification Link**, the interface SHALL display the Invalid Link screen.

T. The Invalid Link screen SHALL display a message indicating that the **Verification Link** is no longer valid.

U. The Invalid Link screen SHALL present an *Action* that navigates to the Forgot *Password* Request screen.

### Rationale

The four-screen structure mirrors the four states the workflow can reach: requesting reset, awaiting email, completing reset, recovering from an invalidated link. Identical confirmation content regardless of whether the email matches is the GUI-level enforcement of the *User*-enumeration resistance established at the PRD level — divergent UI between matching and non-matching cases would leak the same information the PRD assertion is trying to hide. The inline composition-rule error on Submit is necessary because users who submitted an invalid **Password** must learn which rule failed without losing the typed values, otherwise the show/hide toggle gains a punitive UX where users repeatedly retype the same long *Password*. The Invalid Link screen's link back to the request screen restarts the recovery loop in a single click, recognising that the most common reason for an invalidated link is the 24-hour expiry catching a *User* who opened the email belatedly.

*End* *Forgot Password Workflow Interface* | **Hash**: d41e7764

## DIARY-PRD-session-management: Session Management

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-access-control-identity

### Overview

The **Sponsor Portal** terminates inactive sessions to limit the window during which an unattended authenticated *Session* could be exploited. *Session* limits also ensure that *Role* and permission changes take effect within a bounded time.


Session
: An authenticated period during which a **User Account** owner can access the **Sponsor Portal** without re-entering credentials.

Session Idle Timeout
: The configurable maximum duration of inactivity allowed during a **Session** before the **System** terminates it.

Session Timeout Warning
: A notice presented to a **User Account** owner a configurable interval before the **Session Idle Timeout** is reached, offering to extend the **Session** without re-authenticating.

Timeout Warning Threshold
: The configurable interval before the **Session Idle Timeout** at which the **Session Timeout Warning** is presented.

### Assertions

**Session Establishment**

A. The **System** SHALL establish a **Session** when a **User Account** owner successfully completes Two-Factor Authentication.

**Idle Timeout**

B. The **System** SHALL track elapsed inactivity from the **User Account** owner's most recent interaction with the **Sponsor Portal**.

C. When the **Session Idle Timeout** is exceeded, the System SHALL terminate the **Session** and require re-authentication.

**Termination**

D. The **System** SHALL allow a **User Account** owner to explicitly terminate their **Session** by logging out.

E. When a **User Account** is deactivated, the **System** SHALL terminate all active **Sessions** associated with that **User Account** immediately.

F. When a **User Account**'s **Role** or **Site** assignment is changed, the **System** SHALL terminate all active **Sessions** associated with that **User Account** immediately.

G. When the **System** terminates a **Session** under assertion E or F, the **System** SHALL reject every subsequent request authenticated by a **Session** established before the termination timestamp.

**Configuration**

H. The **System** SHALL support *Sponsor*-configurable **Session Idle Timeout** per study, with a default of 10 minutes.

**Timeout Warning**

I. The **System** SHALL present a **Session Timeout Warning** to the **User Account** owner one **Timeout Warning Threshold** before the **Session Idle Timeout** is reached, allowing the owner to extend the **Session** without re-authenticating.

J. The **System** SHALL support *Sponsor*-configurable **Timeout Warning Threshold** per study, with a default of 60 seconds.

K. When the **User Account** owner extends the **Session** from the **Session Timeout Warning**, the **System** SHALL reset elapsed inactivity.

### Rationale

A **Session** in the **Sponsor Portal** is a high-value authentication artifact — it represents a successful two-factor login and confers access to clinical data and *User* Account management capabilities for its duration. The *Idle Timeout* caps the window in which an unattended workstation could be exploited; tracking inactivity from the *User*'s most recent interaction (rather than from *Session* creation) is the standard pattern that balances security against operational disruption. The cascade rules (*Deactivation*, *Role* change, *Site* change immediately terminate sessions) ensure that authorization changes take effect synchronously rather than waiting for the next login: a Coordinator who has lost their *Role* for cause cannot continue acting under the old *Role* until their **Session** happens to time out. Assertion G states the enforcement obligation explicitly: terminating a **Session** must reject every request bearing that **Session** on every subsequent authenticated endpoint, not merely mark the **Session** as terminated in storage — a bookkeeping flip without an enforcement check would leave the pre-termination credential operational until natural expiry and defeat the whole cascade. *Sponsor*-configurability of the timeout duration acknowledges that the right tradeoff between security and operator disruption varies by deployment; the 10-minute default reflects clinical-portal industry baseline. The **Session Timeout Warning** gives an active operator a chance to preserve in-progress work before an idle **Session** is terminated, and resetting elapsed inactivity on extension makes the warning a genuine reprieve rather than a notice; the warning lead is *Sponsor*-configurable for the same reason the timeout itself is — the right tradeoff between security and operator disruption varies by deployment.

*End* *Session Management* | **Hash**: e4c6d237

## DIARY-GUI-portal-session-expiry: Portal session expiry interface

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-session-management

### Overview

The **Sponsor Portal** warns an idle operator before their **Session** ends and lets them extend it in one *Action*, mirroring the warning + countdown pattern the *Participant* *Questionnaire* uses. On expiry the operator is returned to the re-authentication surface with an informational, non-error message.

### Assertions

A. The interface SHALL present a **Session Timeout Warning** with a live countdown when one **Timeout Warning Threshold** before the **Session Idle Timeout** is reached.

B. The **Session Timeout Warning** SHALL offer a "Stay signed in" *Action* that extends the **Session** and a "Sign out" *Action* that ends it; passive interaction SHALL NOT extend the **Session** once the warning is shown.

C. On **Session** expiry the interface SHALL present the re-authentication surface with an informational, non-error message.

### Rationale

Surfacing a countdown rather than a silent logout lets an operator who is reading (not clicking) keep their **Session** before losing in-progress context, while requiring an explicit *Action* to extend ensures a genuinely-absent operator's **Session** still lapses. Offering a "Sign out" *Action* inside the warning is necessary because the warning blocks interaction with the rest of the interface, so an operator who wants to end the **Session** immediately needs a way to do so without waiting for the countdown. Reusing the *Participant* *Questionnaire*'s warning pattern keeps the two timeout experiences consistent. The informational expiry message avoids alarming a returning operator who simply stepped away.

*End* *Portal session expiry interface* | **Hash**: 0a1581a9
