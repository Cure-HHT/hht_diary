# Open-Source Licensing

Licensing posture of the *Diary* Platform and the obligation to display applicable license text to end users. Authored at the BASE level: this is internal product-ownership framing (what the platform commits to as open source, and how it honors that commitment in-app), not a *Sponsor*-authored requirement.

## DIARY-BASE-open-source-licensing: Open-Source Licensing

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

### Overview

The shared core is open source under a copyleft license that keeps it transparent and fork-resistant, while each *Sponsor*'s own extensions and configuration remain that *Sponsor*'s proprietary property.

### Assertions

A. The shared core codebase SHALL be licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

B. Sponsor-specific extensions, customizations, and configuration SHALL be permitted to remain proprietary to the owning *Sponsor*.

C. Platform documentation SHALL be distributed under a license compatible with redistribution and modification.

### Rationale

An AGPL core makes the platform's regulated-data handling auditable in the open and prevents closed proprietary forks of the shared substrate, which reinforces the trust posture a clinical platform depends on. Drawing the license boundary at the core/extension seam preserves each *Sponsor*'s intellectual property in its own overlay while keeping the common machinery public, consistent with the platform's shared-core / per-*Sponsor*-overlay architecture.

*End* *Open-Source Licensing* | **Hash**: 2c8152a7

## DIARY-BASE-license-display: License Display

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-open-source-licensing

### Overview

The obligation to make the full text of every applicable open-source and third-party license available to end users from within the application, satisfiable offline and without runtime dependency on an external host. The display *entry point* is provided by the *User Profile* surface (*DIARY-GUI-user-profile*); this requirement fixes the *content* obligations behind it.

### Assertions

A. The application SHALL make available to the *User* the full text of the license for each included code module or content asset.

B. The application SHALL render license text from content bundled with the application and SHALL NOT fetch license text from external URLs at runtime.

C. Each displayed license SHALL be labeled with its name and the software or asset it applies to.

D. The application SHALL present license text such that its full content can be read when it exceeds the available display area.

### Rationale

AGPL and third-party license compliance requires end users to be able to read the full applicable license text. Bundling the text rather than fetching it keeps the obligation satisfiable offline and free of runtime dependency on an external host, and clear labeling lets a *User* match each license to the component it governs.

*End* *License Display* | **Hash**: d967174d
