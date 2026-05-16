# Administrator Settings

This section defines the **Administrator Settings** surface, a read-only view available to Administrators that displays the current values of sponsor-configured platform parameters. The surface provides Administrators with visibility into how the deployment is configured without granting modification capability.

## DIARY-PRD-administrator-settings: Administrator Settings Surface

**Level**: prd | **Status**: Legacy | **Implements**: -

### Overview

The **Sponsor Portal** maintains a body of sponsor-configured platform parameters that govern System behavior. These parameters are defined in individual requirements throughout the specification and are typically static for the duration of a deployment. **Administrators** require visibility into the current values of these parameters to support troubleshooting, audit response, and operational verification, without needing to consult the specification or contact CureHHT personnel. The **Administrator Settings** surface consolidates these values into a single read-only view scoped to the **Administrator** role.

### Definitions

**Configuration Parameter**: A named, sponsor-configured value that governs a specific System behavior, defined in a single source requirement and surfaced to **Administrators** for visibility.

**Configuration Category**: A grouping of related **Configuration Parameters** presented together within the **Administrator Settings** surface.

**Administrator Settings**: The read-only surface within the **Sponsor Portal** that displays **Configuration Parameters** to **Administrators**, organised by **Configuration Category**.

### Assertions

**Availability**

A. The **System** SHALL provide an **Administrator Settings** surface within the **Sponsor Portal**.

**Content**

B. The **System** SHALL display each **Configuration Parameter** in **Administrator Settings** with its name, current value, and unit of measurement where applicable.

C. The **System** SHALL display each **Configuration Parameter** under exactly one **Configuration Category**.

D. The **System** SHALL display the current value of each **Configuration Parameter** as defined by the source requirement that establishes it.

**Read-Only Behavior**

E. The **System** SHALL NOT permit modification of any **Configuration Parameter** value from the **Administrator Settings** surface.

**Configuration**

F. The **System** SHALL support sponsor-configurable selection of which **Configuration Parameters** are surfaced in **Administrator Settings** per deployment.

G. The **System** SHALL support sponsor-configurable definition of **Configuration Categories** per deployment.

### Rationale

Sponsor-configured parameters (session timeouts, code expiries, threshold values, reminder schedules) shape the system's runtime behavior but are not visible to the **Administrator** who is operationally responsible for the deployment. Without a surface that exposes these values, troubleshooting and audit response require the **Administrator** to either read the specification or escalate to CureHHT, neither of which scales. Consolidating the visible parameters under the **Administrator** role, with one **Configuration Category** per logical grouping and one source-requirement reference per parameter, gives the **Administrator** a single place to confirm "what is this deployment configured to do?" without granting modification capability. Modification stays out of band (the parameters are set during sponsor onboarding and changed via CureHHT change-control) because their values are tightly coupled to compliance review; a runtime modification surface would bypass that review.

*End* *Administrator Settings Surface* | **Hash**: 318dd00f

## DIARY-GUI-administrator-settings: Administrator Settings Interface

**Level**: GUI | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-administrator-settings

### Overview

The **Administrator Settings** surface is reached from the **Settings** action in the **Administrator Dashboard** header. The surface presents **Configuration Parameters** as a grouped list, with each **Configuration Category** as a section heading and each **Configuration Parameter** as a row beneath it. The interface communicates the read-only nature of the view so the **Administrator** does not expect to edit values directly.

### Assertions

**Display**

A. The interface SHALL display the **Administrator Settings** surface as a full-page view that replaces the **Administrator Dashboard** top-level tab content.

B. The interface SHALL display a header on the **Administrator Settings** surface containing the title **Settings** and a back action that returns the **Administrator** to the previously active top-level tab.

C. The interface SHALL display each **Configuration Category** as a labeled section.

D. The interface SHALL display each **Configuration Parameter** as a row within its **Configuration Category** section, showing the parameter name, the current value, and the unit of measurement where applicable.

E. The interface SHALL display **Configuration Parameters** in the order defined by the deployment configuration.

**Read-Only Indication**

F. The interface SHALL display a notice on the **Administrator Settings** surface indicating that values are read-only and that changes require contacting CureHHT personnel.

G. The interface SHALL NOT present any input control, edit action, or save action on the **Administrator Settings** surface.

### Rationale

Settings is a low-frequency surface — an **Administrator** opens it during troubleshooting or audit response, not during routine workflow — so it is reached via a single header action rather than a tab. Presenting it as a full-page view that replaces the tab content (rather than a modal or a side-panel) reflects the surface's information density (multiple categories, many parameters per category) and lets the **Administrator** scan the entire configuration without scrolling between panels. The explicit read-only notice and the absence of any input control communicate the read-only contract at the GUI level: an **Administrator** who reaches this screen should not waste time looking for an edit affordance, and should know who to contact (CureHHT personnel) when a value needs to change. The back action returns to the previously active tab rather than always defaulting to **Users** because Administrators frequently reach Settings from the audit log during an investigation and should be returned to the same investigation context.

*End* *Administrator Settings Interface* | **Hash**: f10caf2f
