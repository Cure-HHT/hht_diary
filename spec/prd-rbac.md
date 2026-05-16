# Role-Based Access Control

This section defines the role model used across the solution: the generic role templates provided by the platform, the inventory of actions subject to access control, and the sponsor portal deployment's role assignments and permissions. All functional requirements that reference roles or permissions depend on the definitions established here.

## DIARY-PRD-rbac-customizable: Customizable Role-Based Access Control

**Level**: prd | **Status**: Legacy | **Implements**: -

### Overview

The system supports multi-role assignment and seamless role switching without disrupting active sessions. Self-privilege-escalation is prevented structurally by disallowing users to modify role assignments of their own account.

### Assertions

A. The System SHALL allow a **User Account** to be assigned one or more roles.

B. The System SHALL allow an active role to be switched without terminating the user's session.

C. The System SHALL NOT permit a user to modify the role assignments of their own **User Account**.

### Rationale

Clinical trial sponsor portals are routinely staffed by individuals who hold more than one operational role across studies or sites (e.g. a Study Coordinator who is also an Administrator on a sister study). Forcing those users to maintain separate accounts duplicates audit trails, fragments responsibility, and increases the operational burden of account lifecycle. Allowing multi-role assignment with seamless switching keeps a single accountable identity per individual while supporting the legitimate need to perform actions in different capacities. The structural prohibition on self-modification of role assignments is a defense-in-depth control against privilege escalation that does not depend on any single permission check elsewhere in the system.

*End* *Customizable Role-Based Access Control* | **Hash**: 099e2eb7

## DIARY-PRD-action-inventory: Action Inventory

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

### Overview

The Action Inventory enumerates every operation subject to role-based access control. It is the authoritative source for the sponsor-level permissions table — every permission granted or denied in a sponsor deployment must reference an action from this inventory. Actions not listed here cannot be granted or denied. Sponsor deployments may extend the inventory with deployment-specific actions.

### Definitions

**Action:** A discrete operation that a user can perform within the System, subject to role-based access control. An Action either changes system state or retrieves protected data.

**Action Inventory:** The complete enumerated set of Actions the System recognizes, comprising the platform-level inventory in this requirement and any sponsor-level extensions.

**Sponsor-Level Action Extension:** An additional Action defined by a specific sponsor deployment beyond the platform Action Inventory.

### Assertions

A. The System SHALL enforce role-based access control for every **Action** in the **Action Inventory**.

B. The System SHALL reject any attempt to perform an **Action** by a user whose active role does not have permission for that **Action**.

C. The System SHALL permit an **Action** to proceed when the user's active role has permission for that **Action** and the user is within the permitted scope.

D. The System SHALL support **Sponsor-Level Action Extensions** to the **Action Inventory**.

### Action Inventory Table

| Category | Action ID | Action |
| :---- | :---- | :---- |
| **Participant Management** | ACT-PAT-001 | Link participant |
|  | ACT-PAT-002 | Start Trial |
|  | ACT-PAT-003 | Disconnect participant |
|  | ACT-PAT-004 | Reconnect participant |
|  | ACT-PAT-005 | Mark participant as not participating |
|  | ACT-PAT-006 | Reactivate participant |
|  | ACT-PAT-007 | View participant info |
| **Questionnaire** | ACT-QST-001 | Send questionnaire |
|  | ACT-QST-002 | Call back questionnaire |
|  | ACT-QST-003 | Finalize questionnaire |
| **User Account** | ACT-USR-001 | Create User Account |
|  | ACT-USR-002 | Edit User Account |
|  | ACT-USR-003 | Deactivate User Account |
|  | ACT-USR-004 | Reactivate User Account |
|  | ACT-USR-005 | Unlock User Account |
|  | ACT-USR-006 | Resend activation email |
|  | ACT-USR-007 | Assign role to User Account |
|  | ACT-USR-008 | Assign Site to User Account |
| **Site** | ACT-SIT-001 | View Sites |
| **Audit Log** | ACT-AUD-001 | View audit log |
| **Administrator Settings** | ACT-ADM-001 | View Administrator Settings |

### Rationale

The Action Inventory is the single source of truth for what operations the platform recognizes as access-controlled. Sponsor deployments author their permissions table by referencing these Action IDs; deployments may extend the inventory with sponsor-specific actions but cannot redefine or remove platform actions. Centralizing the inventory ensures that every audit log entry, permission check, and role binding refers to a stable, named operation rather than an ad hoc string, which is essential for FDA 21 CFR Part 11 auditability and for cross-sponsor consistency in the platform's compliance posture.

*End* *Action Inventory* | **Hash**: f17b676a

## DIARY-PRD-role-definitions: Role Definitions

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

### Overview

This requirement defines the generic role templates the platform provides and maps the sponsor portal's named roles to those templates. Sponsor deployments bind permissions to roles via the deployment's permissions table; the platform-side definitions establish the shared vocabulary.

### Definitions

**Study Coordinator:** A portal user responsible for managing day-to-day participant interactions at one or more assigned Sites.

**Clinical Research Associate (CRA):** A portal user responsible for monitoring Study Coordinator activities and site compliance at one or more assigned Sites.

**Administrator:** A portal user responsible for managing User Accounts, role assignments, and Site assignments across the study.

### Assertions

A. The System SHALL recognize the following roles in the sponsor portal: **Study Coordinator**, **Clinical Research Associate**, and **Administrator**.

B. The System SHALL map the **Study Coordinator** role to the **Investigator** generic role template.

C. The System SHALL map the **Clinical Research Associate** role to the **Auditor** generic role template.

D. The System SHALL map the **Administrator** role to the **Administrator** generic role template.

### Rationale

The sponsor portal's named roles are deployment-facing labels chosen for clarity to clinical staff; the underlying generic role templates (Investigator, Auditor, Administrator) carry the platform-level semantics and are the units of inheritance for cross-sponsor permission patterns. Establishing the mapping at the platform level lets sponsor configurations alter labels and add scope rules without diverging from the platform's shared model, and lets cross-cutting compliance behavior key off the generic template rather than every sponsor's chosen name.

*End* *Role Definitions* | **Hash**: 1f0ab3a3

## DIARY-GUI-role-switching: Role Switching — Interface Behavior

**Level**: GUI | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

### Overview

This requirement specifies how the sponsor portal interface exposes role switching to users assigned more than one role.

### Definitions

**Role Selector:** UI element displayed in the header that shows the user's currently active role and allows users with multiple assigned roles to switch their active role.

### Assertions

**Display**

A. The interface SHALL display the **Role Selector** in the header for any user assigned two or more roles.

B. The interface SHALL NOT display the **Role Selector** for a user assigned exactly one role.

C. The **Role Selector** SHALL display the user's currently active role.

D. When opened, the **Role Selector** SHALL display the complete list of the user's assigned roles and SHALL visually indicate which role is currently active.

**Interaction**

E. When the user selects a role from the **Role Selector**, the interface SHALL set that role as the active role.

F. When the active role changes, the interface SHALL load the default landing view for the selected role.

G. The **Role Selector** SHALL NOT present a confirmation step before switching roles.

### Rationale

Users assigned multiple roles need an unobtrusive, always-visible affordance to confirm and change which role is currently active, since the active role determines visible data and available actions throughout the portal. Hiding the selector from single-role users keeps the header uncluttered for the common case. Omitting a confirmation step keeps role switching fast for users who switch many times per session; the underlying audit log already records role context for every action so the cost of an accidental switch is bounded.

*End* *Role Switching — Interface Behavior* | **Hash**: 8d6caff0
