# Administrator Settings — User Journeys

> **Role**: Administrator
> **Source**: spec/prd-administrator-settings.md
> **Scope**: Sponsor Portal (web). The journey begins with the Administrator already signed in and on the Administrator Dashboard.

---

# JNY-SET-01: View Administrator Settings

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Review the portal's read-only configuration parameters
**Context**: Jordan is on the Administrator Dashboard (any tab) and wants to confirm a configured value such as the session idle timeout.

Validates: DIARY-PRD-administrator-settings-A+B+C+D+E, DIARY-GUI-administrator-settings-A+B+C+D+E+F+G

## Steps

1. Jordan clicks the Settings action in the persistent header.
2. The Administrator Settings full-page view opens, with a header titled "Settings" and a back action, replacing the tab content.
3. The view shows a read-only notice stating that values cannot be changed here and that changes require contacting CureHHT personnel.
4. Jordan reviews the configuration parameters, grouped into labeled categories, with each row showing the parameter name, current value, and unit of measurement, in the deployment-configured order.
5. Jordan confirms there are no input, edit, or save controls anywhere on the page.
6. Jordan clicks the back action to return to the previously active tab.

## Expected Outcome

Jordan can read the current configuration parameters and their units, organized by category, and confirm the surface is strictly read-only. The back action returns to the previous dashboard context.

*End* *View Administrator Settings*
