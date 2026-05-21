# URS-v1 Migration Mapping

Generated 2026-05-16 for the Phase-1.2 deliverable. Phase 3 consumes this table to author the new spec/ tree across the `hht_diary` and `hht_diary_callisto` repos.

## Routing rules (locked)

| URS prefix | New convention | Owning repo |
|---|---|---|
| `REQ-p…` | `DIARY-PRD-{kebab}` | hht_diary |
| `GUI-p…` | `DIARY-GUI-{kebab}` | hht_diary |
| `REQ-CAL-p…` | `CAL-PRD-{kebab}` | hht_diary_callisto |
| `GUI-CAL-p…` | `CAL-GUI-{kebab}` | hht_diary_callisto |

Kebab slug convention: **entity-first** (e.g. `user-account-create`, not `create-user-account`). Group related REQs by primary entity. Refer to existing committed files in `hht_diary/spec/` (e.g. `prd-questionnaire-versioning.md`, `prd-sla.md`) for naming style.

Audience-suffix convention for target files:
- `spec/prd-*.md` — Product (PRD-level) requirements; may include `GUI` REQs that are scoped to one feature.
- `spec/gui-*.md` — Standalone GUI groupings where the surface spans several PRDs (used sparingly).
- For `hht_diary_callisto` repo, the file path is `spec/prd-*.md` (no `hht_diary` prefix).

REQ→file grouping is by primary URS section. PRD and GUI REQs that share a feature scope land in the same `prd-*.md` file. Sponsor-specific overlay (`CAL-*`) REQs land in the corresponding `spec/prd-*.md` of the `hht_diary_callisto` repo, paired one-to-one with the parent REQ via `Refines:`.

## Convention notes (decided 2026-05-16)

The following conventions govern Phase-3 authoring and downstream PDF compilation. Apply uniformly across both repos.

### Filename = section heading

Each spec file's `#` title is the section heading that will appear in the compiled URS-style PDF. Phase 3 authors files with one of:

- `# {Section Title}` (multi-REQ topic files; followed by an optional brief intro, then `## DIARY-PRD-…` / `## CAL-PRD-…` requirement blocks).
- `# DIARY-PRD-{kebab}: {REQ Title}` (single-REQ files where the file IS the requirement; followed by `## Rationale`, `## Assertions`).

This keeps section structure derivable from filename without authoring a separate "section heading" convention. Where a section title and a REQ title happen to coincide verbatim (e.g. URS §6.7 "Mobile Application Navigation and Screens" overlaps with `GUI-p05012` of the same title), that is acceptable — the file remains `prd-mobile-navigation.md` with `GUI-p05012` becoming `DIARY-GUI-mobile-navigation` inside it.

### PDF compilation interleaving

When the compiled URS PDF is regenerated in Phase 5, REQ blocks across files are interleaved by the URS-aligned ordinal of the **REQ ID stripped of its namespace and level prefix** (e.g. `DIARY-PRD-action-inventory` sorts as `action-inventory`; `CAL-PRD-permissions-table` sorts as `permissions-table`). This produces a single document ordered by topic kebab regardless of repo or audience tier, mirroring the URS reading order.

Phase 5 will implement this via a custom elspais pdf template / pandoc filter; for now, capture the rule here as the contract.

### Follow-up subsection: "only option in code today"

Several REQs (specifically `CAL-*` REQs with no platform-side parent, and many `GUI-*` REQs) currently encode the only option implemented in code. There is no configurable seam — but there should be, because future sponsors may need different rules. Phase 3 authors these REQs with an explicit subsection flagging the gap:

```markdown
> **Follow-up — configurability**: This requirement currently encodes the
> only option implemented in code. Future sponsors may require different
> rules; introduce a configurable seam (e.g. a parameter on the CAL-PRD-*
> parent, or a new platform-side template the CAL- REQ Satisfies) when the
> need arises. Until that seam exists, this REQ is normative for the
> Callisto deployment.
```

This applies to (at minimum, per item 10 review):

- `REQ-CAL-p00007` → `CAL-PRD-questionnaire-score-display-prohibition`
- `REQ-CAL-p00088` → `CAL-PRD-audit-log-view-scope`
- `GUI-p03001` → `CAL-GUI-participant-dashboard-configuration` (reclassified item 2)

Phase 3 should add the same follow-up to any other GUI / CAL- REQ that the URS encodes as a single rule with no obvious configuration seam. Capture each addition in the per-file commit message so reviewers can audit the set.

## §7 appendix → REQ image side-map

Built by scanning every `Reference:` line in §7. Each image is then carried into the main mapping row for the REQ it documents. Where an appendix entry has no explicit `Reference:` (the §7.4 notification entries), the image is attached to the §6.8 REQ that defines the notification.

| §7 entry | Title | Image | References (URS REQ ids) |
|---|---|---|---|
| 7.1.1 | Questionnaire Review Screen | image-01.png | GUI-p00001 |
| 7.1.2 | Questionnaire Preamble Screen | image-02.png | REQ-p02065, GUI-p00001 |
| 7.1.3 | Resolve Conflict — Resolution Screen | image-03.png | REQ-p05008, GUI-p05009 |
| 7.1.4 | Troubleshooting Popover | image-04.png | GUI-CAL-p00006 |
| 7.2.1 | User Information Modal | image-05.png | GUI-p00033 |
| 7.2.2 | Show Linking Code | image-06.png, image-07.png | GUI-p03001 |
| 7.2.3 | Manage Questionnaires Modal | image-08.png | GUI-CAL-p00006 |
| 7.3.1 | Deactivate User Account — Reason Dialog | image-09.png | REQ-p20031, GUI-p00031 |
| 7.3.2 | Reactivate User Account — Reason Dialog | image-10.png | REQ-p20032, GUI-p00032 |
| 7.3.3 | Link Participant — Confirmation Dialog | image-11.png | REQ-p70009, GUI-p03001 |
| 7.3.4 | Linking Code Generated — Acknowledgement Dialog | image-12.png | GUI-p03001 |
| 7.3.5 | Start Trial — Confirmation Dialog | image-13.png | REQ-CAL-p00022, GUI-CAL-p00005 |
| 7.3.6 | Disconnect Participant — Reason Dialog | image-14.png | REQ-p70010, REQ-CAL-p00020 |
| 7.3.7 | Reconnect Participant — Reason Dialog | image-15.png | REQ-p70011 |
| 7.3.8 | Mark as Not Participating — Reason Dialog | image-16.png | REQ-p70017, REQ-CAL-p00064 |
| 7.3.9 | Reactivate Participant — Reason Dialog | image-17.png | REQ-p70016 |
| 7.3.10 | Delete Record — Reason Dialog | image-18.jpg | GUI-p00003 |
| 7.3.11 | Post-Submission Acknowledgement Dialog | image-19.png | GUI-p00001 |
| 7.3.12 | Session Expiry Dialog | image-20.png | REQ-p01073, GUI-p00004 |
| 7.3.13 | Questionnaire Finalization Dialog | image-21.png | REQ-CAL-p00023 I–M, GUI-CAL-p00007 A–F |
| 7.3.14 | Terminal Cycle Warning Dialog | image-22.png | GUI-CAL-p00007 |
| 7.3.15 | Call Back Questionnaire — Reason Dialog | image-23.png | REQ-CAL-p00023, GUI-CAL-p00006 |
| 7.3.16 | Call Back Notice | image-24.png | GUI-CAL-p07002 |
| 7.3.17 | Successful Linking Confirmation | image-25.png | GUI-p05015 |
| 7.4.1 | Timeout Warning Notification | image-26.png | (no explicit ref; describes Questionnaire Session Timeout → REQ-p01073) |
| 7.4.2 | Session Expiry Notification | image-27.png | (no explicit ref; pairs with REQ-p01073 / GUI-p00004) |
| 7.4.3 | Disconnection Notification | image-28.png | (no explicit ref; describes REQ-p05004) |
| 7.4.4 | Portal-Sent Questionnaire Notification | image-29.png | (no explicit ref; describes REQ-p05018) |
| 7.4.5 | Yesterday Entry Reminder Notification | image-30.png | (no explicit ref; describes REQ-p05016) |
| 7.4.6 | Ongoing Epistaxis Event Reminder | image-31.png | (no explicit ref; describes REQ-p05017) |
| 7.4.7 | Historical Gap Reminder | image-32.png | (no explicit ref; describes REQ-p05019) |

## Mapping table

### Section 4 — System-wide functional standards and controls

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 4.3.1 | REQ-p70005 | Customizable Role-Based Access Control | DIARY-PRD-rbac-customizable | hht_diary | spec/prd-rbac.md | — | Foundation / template REQ for RBAC. Parent of 4.3.2–4.3.6. |
| 4.3.2 | REQ-p07037 | Action Inventory | DIARY-PRD-action-inventory | hht_diary | spec/prd-rbac.md | — | **Template/registry** of all access-controlled Actions; Refines: REQ-p70005. |
| 4.3.3 | REQ-p03013 | Role Definitions | DIARY-PRD-role-definitions | hht_diary | spec/prd-rbac.md | — | **Template/registry** of platform role templates; Refines: REQ-p70005. |
| 4.3.4 | REQ-CAL-p00016 | Permissions Table | CAL-PRD-permissions-table | hht_diary_callisto | spec/prd-rbac.md | — | Sponsor overlay binding roles → actions; Refines: REQ-p70005, REQ-p07037, REQ-p03013. |
| 4.3.5 | REQ-CAL-p00087 | Site View Scope | CAL-PRD-site-view-scope | hht_diary_callisto | spec/prd-rbac.md | — | Sponsor overlay; Refines: REQ-p03013. |
| 4.3.6 | GUI-p03045 | Role Switching — Interface Behavior | DIARY-GUI-role-switching | hht_diary | spec/prd-rbac.md | — | GUI for multi-role users; Refines: REQ-p70005. |
| 4.4.1 | REQ-CAL-p00007 | Questionnaire Score Display Prohibition | CAL-PRD-questionnaire-score-display-prohibition | hht_diary_callisto | spec/prd-questionnaire-score-display.md | — | Sponsor-level invariant (no score display to any user). **Only option in code today; add follow-up subsection per Convention notes** (no platform-side parent REQ; future sponsors may want a different rule). |
| 4.5.1 | REQ-CAL-p00088 | Audit Log View Scope | CAL-PRD-audit-log-view-scope | hht_diary_callisto | spec/prd-audit-log.md | — | Sponsor overlay defining per-role visibility scope. **Only option in code today; add follow-up subsection per Convention notes** (no platform-side parent REQ; future sponsors may want different scope rules). |
| 4.5.2 | GUI-p20077 | Audit Log View — Common Presentation | DIARY-GUI-audit-log-common | hht_diary | spec/prd-audit-log.md | — | **Template** for audit log presentation; Refines: REQ-CAL-p00088. |
| 4.5.3 | GUI-p20074 | Study Coordinator Audit Log View | DIARY-GUI-audit-log-study-coordinator | hht_diary | spec/prd-audit-log.md | — | Refines: GUI-p20077. |
| 4.5.4 | GUI-p20075 | CRA Audit Log View | DIARY-GUI-audit-log-cra | hht_diary | spec/prd-audit-log.md | — | Refines: GUI-p20077. |
| 4.5.5 | GUI-p20076 | Administrator Audit Log View | DIARY-GUI-audit-log-administrator | hht_diary | spec/prd-audit-log.md | — | Refines: GUI-p20077. |
| 4.6.1 | REQ-p20078 | Notification Behavior | DIARY-PRD-notification-behavior | hht_diary | spec/prd-notification-behavior.md | — | **Template** governing notification semantics platform-wide. |
| 4.7.1 | REQ-p20081 | Help and Resources | DIARY-PRD-help-resources | hht_diary | spec/prd-help-resources.md | — | — |
| 4.8.1 | REQ-p70020 | Configuration Precedence | DIARY-PRD-configuration-precedence | hht_diary | spec/prd-configuration.md | — | **Template** establishing config-overlay precedence rules used by every REQ-CAL-*. |

### Section 5 — Sponsor Portal requirements

#### 5.1 Administration — User account lifecycle

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.1.1 | REQ-p20029 | Create User Account | DIARY-PRD-user-account-create | hht_diary | spec/prd-user-account.md | — | — |
| 5.1.2 | REQ-p20035 | Account Activation Workflow | DIARY-PRD-user-account-activation-workflow | hht_diary | spec/prd-user-account.md | — | Refines: REQ-p20029. |
| 5.1.3 | REQ-p20034 | Site Assignment | DIARY-PRD-user-account-site-assignment | hht_diary | spec/prd-user-account.md | — | Refines: REQ-p20029. |
| 5.1.4 | REQ-p20033 | Resend Activation Email | DIARY-PRD-user-account-activation-resend | hht_diary | spec/prd-user-account.md | — | Refines: REQ-p20035. |
| 5.1.5 | REQ-p20030 | Edit User Account | DIARY-PRD-user-account-edit | hht_diary | spec/prd-user-account.md | — | — |
| 5.1.6 | REQ-p20031 | Deactivate User Account | DIARY-PRD-user-account-deactivate | hht_diary | spec/prd-user-account.md | image-09.png | — |
| 5.1.7 | REQ-p20032 | Reactivate User Account | DIARY-PRD-user-account-reactivate | hht_diary | spec/prd-user-account.md | image-10.png | — |

#### 5.2 User Interface — User-management surfaces

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.2.1 | REQ-p20066 | Reason Field Constraints | DIARY-PRD-reason-field-constraints | hht_diary | spec/prd-user-account.md | — | **Template** for free-text Reason inputs across PRD/GUI Reason Dialogs. |
| 5.2.2 | GUI-p00067 | User Management Tabs | DIARY-GUI-user-management-tabs | hht_diary | spec/prd-user-account.md | — | Refines: REQ-p20029, REQ-p20030. |
| 5.2.3 | GUI-p00031 | Deactivate User Account | DIARY-GUI-user-account-deactivate | hht_diary | spec/prd-user-account.md | image-09.png | Refines: REQ-p20031. |
| 5.2.4 | GUI-p00032 | Reactivate User Account | DIARY-GUI-user-account-reactivate | hht_diary | spec/prd-user-account.md | image-10.png | Refines: REQ-p20032. |
| 5.2.5 | GUI-p00033 | User Information Modal | DIARY-GUI-user-information-modal | hht_diary | spec/prd-user-account.md | image-05.png | Refines: REQ-p20029, REQ-p20030. URS heading is "5.2.5." (with trailing dot) — typo in URS. |
| 5.2.6 | GUI-p20080 | Administrator Dashboard | DIARY-GUI-administrator-dashboard | hht_diary | spec/prd-user-account.md | — | — |

#### 5.3 Questionnaire Management

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.3.1 | REQ-p01065 | Clinical Questionnaire System | DIARY-PRD-questionnaire-system | hht_diary | spec/prd-questionnaire-management.md | — | **Foundation** REQ for all questionnaire handling. |
| 5.3.2 | REQ-p01053 | Sponsor Questionnaire Configuration | DIARY-PRD-questionnaire-sponsor-configuration | hht_diary | spec/prd-questionnaire-management.md | — | Refines: REQ-p01065. URS anchor is placeholder `{#heading=}` — clean during authoring. |
| 5.3.3 | REQ-p01050 | Clinical Data Submission Control | DIARY-PRD-questionnaire-submission-control | hht_diary | spec/prd-questionnaire-management.md | — | Refines: REQ-p01065. URS anchor is placeholder `{#heading=}`. |
| 5.3.4 | REQ-p02047 | Questionnaire Change Control | DIARY-PRD-questionnaire-change-control | hht_diary | spec/prd-questionnaire-management.md | — | Refines: REQ-p01065. |
| 5.3.5 | REQ-CAL-p00022 | Start Trial Workflow | CAL-PRD-trial-start-workflow | hht_diary_callisto | spec/prd-questionnaire-management.md | image-13.png | Sponsor overlay; pairs with 5.3.6 GUI. |
| 5.3.6 | GUI-CAL-p00005 | Start Trial Workflow Interface | CAL-GUI-trial-start-workflow | hht_diary_callisto | spec/prd-questionnaire-management.md | image-13.png | Refines: REQ-CAL-p00022. |
| 5.3.7 | REQ-CAL-p00023 | NOSE HHT and HHT-QoL Questionnaire Workflow | CAL-PRD-nose-hht-qol-workflow | hht_diary_callisto | spec/prd-questionnaire-management.md | image-21.png, image-23.png | Sponsor-specific workflow over the two clinical questionnaires; assertions I–M produce 7.3.13. |
| 5.3.8 | GUI-CAL-p00006 | Manage Questionnaires Modal | CAL-GUI-manage-questionnaires-modal | hht_diary_callisto | spec/prd-questionnaire-management.md | image-04.png, image-08.png, image-23.png | Refines: REQ-CAL-p00023. |
| 5.3.9 | GUI-CAL-p00007 | Questionnaire Finalization Workflow | CAL-GUI-questionnaire-finalization-workflow | hht_diary_callisto | spec/prd-questionnaire-management.md | image-21.png, image-22.png | Refines: REQ-CAL-p00023; assertions A–F produce 7.3.13. |
| 5.3.10 | REQ-CAL-p00080 | Questionnaire Cycle Tracking | CAL-PRD-questionnaire-cycle-tracking | hht_diary_callisto | spec/prd-questionnaire-management.md | — | Refines: REQ-CAL-p00023. |
| 5.3.11 | REQ-CAL-p00085 | Questionnaire Session Resume and Timeout | CAL-PRD-questionnaire-session-resume-timeout | hht_diary_callisto | spec/prd-questionnaire-management.md | — | Sponsor overlay; Refines: REQ-p01073 (mobile-side parent). |

#### 5.4 Participant Workflows

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.4.1 | REQ-p70007 | Linking Code Lifecycle Management | DIARY-PRD-linking-code-lifecycle | hht_diary | spec/prd-participant.md | — | **Foundation** for participant linking. |
| 5.4.2 | REQ-CAL-p70008 | Linking Code Lifecycle Configuration | CAL-PRD-linking-code-lifecycle-configuration | hht_diary_callisto | spec/prd-participant.md | — | Refines: REQ-p70007. URS anchor is `{#heading}` placeholder. |
| 5.4.3 | REQ-p70013 | Participant Registration | DIARY-PRD-participant-registration | hht_diary | spec/prd-participant.md | — | — |
| 5.4.4 | REQ-CAL-p00063 | Participant Registration Configuration | CAL-PRD-participant-registration-configuration | hht_diary_callisto | spec/prd-participant.md | — | Refines: REQ-p70013. |
| 5.4.5 | REQ-p70009 | Link New Participant Workflow | DIARY-PRD-participant-link-new | hht_diary | spec/prd-participant.md | image-11.png | — |
| 5.4.6 | REQ-p70010 | Participant Disconnection Workflow | DIARY-PRD-participant-disconnection | hht_diary | spec/prd-participant.md | image-14.png | — |
| 5.4.7 | REQ-CAL-p00020 | Disconnection Reason Options | CAL-PRD-participant-disconnection-reason-options | hht_diary_callisto | spec/prd-participant.md | image-14.png | Refines: REQ-p70010. Predefined-list overlay. |
| 5.4.8 | REQ-p70011 | Participant Reconnection Workflow | DIARY-PRD-participant-reconnection | hht_diary | spec/prd-participant.md | image-15.png | — |
| 5.4.9 | REQ-p70017 | Mark as Not Participating | DIARY-PRD-participant-mark-not-participating | hht_diary | spec/prd-participant.md | image-16.png | — |
| 5.4.10 | REQ-CAL-p00064 | Mark as Not Participating Reason Options | CAL-PRD-participant-not-participating-reason-options | hht_diary_callisto | spec/prd-participant.md | image-16.png | Refines: REQ-p70017. Predefined-list overlay. |
| 5.4.11 | REQ-p70016 | Reactivate Participant | DIARY-PRD-participant-reactivate | hht_diary | spec/prd-participant.md | image-17.png | — |
| 5.4.12 | GUI-p70001 | Participant Dashboard | DIARY-GUI-participant-dashboard | hht_diary | spec/prd-participant.md | image-06.png, image-07.png, image-11.png, image-12.png | Multiple appendix entries reference GUI-p03001 in conjunction. |
| 5.4.13 | GUI-p03001 | Participant Dashboard Configuration | CAL-GUI-participant-dashboard-configuration | hht_diary_callisto | spec/prd-participant.md | image-06.png, image-07.png, image-11.png, image-12.png | **Reclassified to `GUI-CAL-*`** per user decision (item 2 resolved 2026-05-16). Refines: DIARY-GUI-participant-dashboard. Add follow-up subsection per "only-option" convention (see Convention notes). |

#### 5.5 Sponsor Portal Authentication

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.5.1 | REQ-p20068 | Password Requirements | DIARY-PRD-password-requirements | hht_diary | spec/prd-portal-auth.md | — | — |
| 5.5.2 | REQ-p20069 | Two-Factor Authentication | DIARY-PRD-two-factor-authentication | hht_diary | spec/prd-portal-auth.md | — | URS §4.3 in the TOC pointed here. |
| 5.5.3 | REQ-CAL-p00089 | Two-Factor Authentication Configuration | CAL-PRD-two-factor-authentication-configuration | hht_diary_callisto | spec/prd-portal-auth.md | — | Refines: REQ-p20069. |
| 5.5.4 | REQ-p20070 | Forgot Password | DIARY-PRD-password-forgot | hht_diary | spec/prd-portal-auth.md | — | — |
| 5.5.5 | GUI-p20072 | Forgot Password Workflow Interface | DIARY-GUI-password-forgot-workflow | hht_diary | spec/prd-portal-auth.md | — | Refines: REQ-p20070. |
| 5.5.6 | REQ-p20071 | Session Management | DIARY-PRD-session-management | hht_diary | spec/prd-portal-auth.md | — | — |
| 5.5.7 | REQ-CAL-p00090 | Login Attempt Rate Limiting Configuration | CAL-PRD-login-rate-limiting-configuration | hht_diary_callisto | spec/prd-portal-auth.md | — | Refines: REQ-p20071. |

#### 5.6 Administrator Settings

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 5.6.1 | REQ-p20082 | Administrator Settings Surface | DIARY-PRD-administrator-settings | hht_diary | spec/prd-administrator-settings.md | — | — |
| 5.6.2 | GUI-p20083 | Administrator Settings Interface | DIARY-GUI-administrator-settings | hht_diary | spec/prd-administrator-settings.md | — | Refines: REQ-p20082. |
| 5.6.3 | REQ-CAL-p00094 | Administrator Settings Configuration Inventory | CAL-PRD-administrator-settings-inventory | hht_diary_callisto | spec/prd-administrator-settings.md | — | **Template/inventory** of all sponsor-configurable settings; Refines: REQ-p20082, REQ-p70020. |

### Section 6 — Mobile Application requirements

#### 6.1 Mobile Application Foundation

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.1.1 | REQ-p00043 | Diary Mobile Application | DIARY-PRD-mobile-application | hht_diary | spec/prd-mobile-app.md | — | **Foundation** REQ for the mobile diary. |
| 6.1.2 | REQ-p00006 | Offline-First Data Entry | DIARY-PRD-mobile-offline-first | hht_diary | spec/prd-mobile-app.md | — | Refines: REQ-p00043. |
| 6.1.3 | REQ-p01039 | Diary Start Day Definition | DIARY-PRD-diary-start-day | hht_diary | spec/prd-mobile-app.md | — | — |
| 6.1.4 | REQ-p00045 | Clinical Trial Privacy Policy | DIARY-PRD-privacy-policy | hht_diary | spec/prd-mobile-app.md | — | — |
| 6.1.5 | REQ-CAL-p00045 | Clinical Trial Privacy Policy Configuration | CAL-PRD-privacy-policy-configuration | hht_diary_callisto | spec/prd-mobile-app.md | — | Refines: REQ-p00045. Shares numeric suffix with parent — distinguished by `CAL-` prefix. |
| 6.1.6 | REQ-p20079 | Application Lock | DIARY-PRD-application-lock | hht_diary | spec/prd-mobile-app.md | — | — |
| 6.1.7 | REQ-CAL-p00092 | Application Lock Configuration | CAL-PRD-application-lock-configuration | hht_diary_callisto | spec/prd-mobile-app.md | — | Refines: REQ-p20079. |

#### 6.2 Questionnaires Overview

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.2.1 | REQ-p01066 | Daily Epistaxis Record Questionnaire | DIARY-PRD-questionnaire-daily-epistaxis | hht_diary | spec/prd-questionnaire-overview.md | — | Distinct from REQ-p00042 (data capture standard). |
| 6.2.2 | REQ-p01067 | NOSE HHT Questionnaire | DIARY-PRD-questionnaire-nose-hht | hht_diary | spec/prd-questionnaire-overview.md | — | — |
| 6.2.3 | REQ-p01068 | HHT-QoL Questionnaire | DIARY-PRD-questionnaire-hht-qol | hht_diary | spec/prd-questionnaire-overview.md | — | — |

#### 6.3 Participant Questionnaire Workflow

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.3.1 | REQ-p02065 | Portal-Sent Questionnaire Rules | DIARY-PRD-questionnaire-portal-sent-rules | hht_diary | spec/prd-questionnaire-participant-workflow.md | image-02.png | — |
| 6.3.2 | GUI-p00001 | Portal-Sent Questionnaire Workflow | DIARY-GUI-questionnaire-portal-sent-workflow | hht_diary | spec/prd-questionnaire-participant-workflow.md | image-01.png, image-02.png, image-19.png | Refines: REQ-p02065. |
| 6.3.3 | REQ-p01073 | Questionnaire Session Timeout | DIARY-PRD-questionnaire-session-timeout | hht_diary | spec/prd-questionnaire-participant-workflow.md | image-20.png, image-26.png, image-27.png | Refines: REQ-p02065. Drives §7.4.1 / §7.4.2 notifications. |
| 6.3.4 | GUI-p00004 | Questionnaire Session Expiry | DIARY-GUI-questionnaire-session-expiry | hht_diary | spec/prd-questionnaire-participant-workflow.md | image-20.png | Refines: REQ-p01073. |
| 6.3.5 | GUI-CAL-p07002 | Portal-Sent Questionnaire Call-Back — Participant Experience | CAL-GUI-questionnaire-call-back-participant | hht_diary_callisto | spec/prd-questionnaire-participant-workflow.md | image-24.png | Sponsor-specific call-back UX; Refines: REQ-CAL-p00023, REQ-p02065. |

#### 6.4 Daily eDiary: HHT Epistaxis Data Capture

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.4.1 | REQ-p00042 | HHT Epistaxis Data Capture Standard | DIARY-PRD-epistaxis-capture-standard | hht_diary | spec/prd-epistaxis.md | — | **Foundation** for the daily eDiary entry. Distinct from REQ-p01066. |
| 6.4.2 | GUI-p00002 | Record Nosebleed Event | DIARY-GUI-epistaxis-record | hht_diary | spec/prd-epistaxis.md | — | Refines: REQ-p00042. |
| 6.4.3 | GUI-p00003 | Nosebleed Event Delete | DIARY-GUI-epistaxis-delete | hht_diary | spec/prd-epistaxis.md | image-18.jpg | Refines: REQ-p00042. |

#### 6.5 Score Calculation

URS body uses duplicate section numbering (`6.4.1`, `6.4.2`, `6.4.3` repeated inside §6.5). Treat as §6.5.1–§6.5.3 conceptually.

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.5.1 | REQ-p02075 | Questionnaire Score Calculation | DIARY-PRD-questionnaire-score-calculation | hht_diary | spec/prd-score-calculation.md | — | **Foundation** REQ for all score algorithms. |
| 6.5.2 | REQ-p02008 | HHT-QoL Score Calculation | DIARY-PRD-score-hht-qol | hht_diary | spec/prd-score-calculation.md | — | Refines: REQ-p02075. |
| 6.5.3 | REQ-p02009 | NOSE HHT Score Calculation | DIARY-PRD-score-nose-hht | hht_diary | spec/prd-score-calculation.md | — | Refines: REQ-p02075. |

#### 6.6 Diary Entry Rules

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.6.1 | REQ-p05000 | Time-Based Entry Restrictions | DIARY-PRD-entry-time-restrictions | hht_diary | spec/prd-diary-entry-rules.md | — | — |
| 6.6.2 | REQ-CAL-p05001 | Time-Based Entry Restrictions Configuration | CAL-PRD-entry-time-restrictions-configuration | hht_diary_callisto | spec/prd-diary-entry-rules.md | — | Refines: REQ-p05000. |
| 6.6.3 | REQ-p05002 | Duration Reasonableness Check | DIARY-PRD-entry-duration-check | hht_diary | spec/prd-diary-entry-rules.md | — | — |
| 6.6.4 | REQ-CAL-p05003 | Duration Reasonableness Check Configuration | CAL-PRD-entry-duration-check-configuration | hht_diary_callisto | spec/prd-diary-entry-rules.md | — | Refines: REQ-p05002. |
| 6.6.5 | REQ-p05008 | Overlapping Event Detection and Resolution | DIARY-PRD-entry-overlap-resolution | hht_diary | spec/prd-diary-entry-rules.md | image-03.png | — |
| 6.6.6 | GUI-p05009 | Overlapping Event Resolution Flow | DIARY-GUI-entry-overlap-resolution | hht_diary | spec/prd-diary-entry-rules.md | image-03.png | Refines: REQ-p05008. |

#### 6.7 Mobile Application Navigation and Screens

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.7.1 | GUI-p05007 | Main Screen Layout | DIARY-GUI-main-screen-layout | hht_diary | spec/prd-mobile-navigation.md | — | — |
| 6.7.2 | GUI-p05012 | Mobile Application Navigation and Screens | DIARY-GUI-mobile-navigation | hht_diary | spec/prd-mobile-navigation.md | — | **Foundation** of navigation; possible duplicate-of-section-title; verify scope. |
| 6.7.3 | GUI-p05014 | Calendar and Day View | DIARY-GUI-calendar-day-view | hht_diary | spec/prd-mobile-navigation.md | — | — |

#### 6.8 Participant Tasks and Notifications

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.8.1 | GUI-p05005 | Participant Task List | DIARY-GUI-participant-task-list | hht_diary | spec/prd-mobile-notifications.md | — | — |
| 6.8.2 | REQ-p05004 | Disconnection Notification | DIARY-PRD-notification-disconnection | hht_diary | spec/prd-mobile-notifications.md | image-28.png | — |
| 6.8.3 | GUI-p00076 | Participation Status Badge | DIARY-GUI-participation-status-badge | hht_diary | spec/prd-mobile-notifications.md | — | Refines: REQ-p05004. |
| 6.8.4 | REQ-p05015 | Incomplete Record Lock Warning Notification | DIARY-PRD-notification-incomplete-record-lock | hht_diary | spec/prd-mobile-notifications.md | — | — |
| 6.8.5 | REQ-CAL-p00091 | Incomplete Record Lock Warning Notification Configuration | CAL-PRD-notification-incomplete-record-lock-configuration | hht_diary_callisto | spec/prd-mobile-notifications.md | — | Refines: REQ-p05015. |
| 6.8.6 | REQ-p05018 | Portal-Sent Questionnaire Notification | DIARY-PRD-notification-portal-sent-questionnaire | hht_diary | spec/prd-mobile-notifications.md | image-29.png | — |
| 6.8.7 | REQ-p05016 | Yesterday Entry Reminder Notification | DIARY-PRD-notification-yesterday-entry | hht_diary | spec/prd-mobile-notifications.md | image-30.png | — |
| 6.8.8 | REQ-p05017 | Ongoing Epistaxis Event Reminder | DIARY-PRD-notification-ongoing-epistaxis | hht_diary | spec/prd-mobile-notifications.md | image-31.png | — |
| 6.8.9 | REQ-CAL-p00093 | Notification & Reminder Configuration | CAL-PRD-notification-reminder-configuration | hht_diary_callisto | spec/prd-mobile-notifications.md | — | Refines: REQ-p05015, REQ-p05016, REQ-p05017, REQ-p05018. **ID-collision with §6.8.11**: see Open questions. |
| 6.8.10 | REQ-p05019 | Historical Gap Reminder | DIARY-PRD-notification-historical-gap | hht_diary | spec/prd-mobile-notifications.md | image-32.png | — |
| 6.8.11 | REQ-CAL-p00093 | Historical Gap Reminder Configuration | CAL-PRD-notification-historical-gap-configuration | hht_diary_callisto | spec/prd-mobile-notifications.md | — | Refines: REQ-p05019. **URS id REQ-CAL-p00093 is duplicated** (also used at §6.8.9). Phase 3 must reassign one of them a fresh sponsor REQ id; mapping presented here splits them by scope. |

#### 6.9 Device Linking

| URS § | URS old id | URS title | New id | Repo | Target file | Image refs | Notes |
|---|---|---|---|---|---|---|---|
| 6.9.1 | REQ-p05010 | Linking Code Entry Error Handling | DIARY-PRD-linking-code-entry-errors | hht_diary | spec/prd-device-linking.md | — | — |
| 6.9.2 | REQ-CAL-p05011 | Linking Code Entry Error Handling Configuration | CAL-PRD-linking-code-entry-errors-configuration | hht_diary_callisto | spec/prd-device-linking.md | — | Refines: REQ-p05010. |
| 6.9.3 | GUI-p05013 | Join the Study Screen | DIARY-GUI-join-study-screen | hht_diary | spec/prd-device-linking.md | — | Refines: REQ-p05010. |
| 6.9.4 | GUI-p05015 | Successful Linking Confirmation | DIARY-GUI-linking-confirmation | hht_diary | spec/prd-device-linking.md | image-25.png | Refines: REQ-p05010. |

## Cross-cutting "template" REQs

The following REQs are explicit **templates / registries / inventories** — they define vocabularies or precedence rules consumed by every other REQ, not concrete behaviour. Phase 3 should author them first and reference them via `Refines:` from every consumer.

| New id | Template purpose |
|---|---|
| DIARY-PRD-rbac-customizable | Foundation REQ that the Action Inventory + Role Definitions + Permissions Table satisfy. |
| DIARY-PRD-action-inventory | Master registry of every controlled Action. |
| DIARY-PRD-role-definitions | Master registry of generic platform Roles. |
| DIARY-PRD-notification-behavior | Notification semantics consumed by §6.8 REQs and all `*-notification` REQs. |
| DIARY-PRD-configuration-precedence | Establishes precedence used by every `CAL-PRD-*` overlay. |
| DIARY-PRD-reason-field-constraints | Constraints for free-text Reason inputs used by Reason Dialog (Free Text) appendix entries. |
| CAL-PRD-permissions-table | Sponsor binding of roles ↔ actions ↔ scope. |
| CAL-PRD-administrator-settings-inventory | Inventory of all sponsor-configurable knobs across the Callisto deployment. |

Section 4.1 (Common UI Elements and Actions) and Section 4.2 (Status Registry) are **non-REQ template tables** in the URS. Phase 3 should fold them into the front of `spec/prd-common-ui.md` (or similar) as authoritative vocabulary tables referenced by every PRD/GUI REQ.

## Proposed target file inventory

### hht_diary repo

| File | REQ count | Sections |
|---|---|---|
| spec/prd-common-ui.md | 0 (template tables only) | §4.1, §4.2 |
| spec/prd-rbac.md | 4 | §4.3 |
| spec/prd-audit-log.md | 4 | §4.5 |
| spec/prd-notification-behavior.md | 1 | §4.6 |
| spec/prd-help-resources.md | 1 | §4.7 |
| spec/prd-configuration.md | 1 | §4.8 |
| spec/prd-user-account.md | 13 | §5.1, §5.2 |
| spec/prd-questionnaire-management.md | 4 | §5.3 |
| spec/prd-participant.md | 8 | §5.4 |
| spec/prd-portal-auth.md | 5 | §5.5 |
| spec/prd-administrator-settings.md | 2 | §5.6 |
| spec/prd-mobile-app.md | 5 | §6.1 |
| spec/prd-questionnaire-overview.md | 3 | §6.2 |
| spec/prd-questionnaire-participant-workflow.md | 4 | §6.3 |
| spec/prd-epistaxis.md | 3 | §6.4 |
| spec/prd-score-calculation.md | 3 | §6.5 |
| spec/prd-diary-entry-rules.md | 4 | §6.6 |
| spec/prd-mobile-navigation.md | 3 | §6.7 |
| spec/prd-mobile-notifications.md | 8 | §6.8 |
| spec/prd-device-linking.md | 3 | §6.9 |
| **subtotal (hht_diary)** | **79** | |

### hht_diary_callisto repo

| File | REQ count | Sections |
|---|---|---|
| spec/prd-rbac.md | 2 | §4.3 |
| spec/prd-questionnaire-score-display.md | 1 | §4.4 |
| spec/prd-audit-log.md | 1 | §4.5 |
| spec/prd-questionnaire-management.md | 7 | §5.3 |
| spec/prd-participant.md | 5 | §5.4 |
| spec/prd-portal-auth.md | 2 | §5.5 |
| spec/prd-administrator-settings.md | 1 | §5.6 |
| spec/prd-mobile-app.md | 2 | §6.1 |
| spec/prd-questionnaire-participant-workflow.md | 1 | §6.3 |
| spec/prd-diary-entry-rules.md | 2 | §6.6 |
| spec/prd-mobile-notifications.md | 3 | §6.8 |
| spec/prd-device-linking.md | 1 | §6.9 |
| **subtotal (hht_diary_callisto)** | **28** | |

Total: 20 files in `hht_diary` (covering 79 REQs), 12 files in `hht_diary_callisto` (covering 28 REQs) → **32 spec files, 107 REQs**.

## REQ counts by prefix

Counted by URS heading occurrence in §4–§6 (so the duplicate-id `REQ-CAL-p00093` is counted twice; the unique-id count is one lower).

| Prefix | Heading count | Unique ids | After 2026-05-16 reclass |
|---|---|---|---|
| REQ-p… → DIARY-PRD-* | 54 | 54 | 54 |
| GUI-p… → DIARY-GUI-* | 26 | 26 | 25 (GUI-p03001 moved to CAL-GUI-*) |
| REQ-CAL-p… → CAL-PRD-* | 23 | 22 (one duplicate) | 22 |
| GUI-CAL-p… → CAL-GUI-* | 4 | 4 | 5 (gained GUI-p03001) |
| **Total** | **107** | **106** | **106 unique** |

## Open questions / decisions (2026-05-16 review)

All ten items raised in the Phase-1.2 first draft were reviewed; each is now decided. Recorded here so Phase 3 authoring has the audit trail.

1. **DECIDED** — Duplicate URS id `REQ-CAL-p00093` (§6.8.9 vs §6.8.11). Old IDs are not preserved post-migration, so the duplication is harmless: the §6.8.9 row maps to `CAL-PRD-notification-reminder-configuration` and the §6.8.11 row to `CAL-PRD-notification-historical-gap-configuration` — distinct slugs, distinct REQs. No "fresh sponsor REQ id" needed.

2. **DECIDED** — `GUI-p03001` misclassified; moved to callisto as `CAL-GUI-participant-dashboard-configuration`. Row updated; also flagged for the **"only option in code today"** follow-up (see Convention notes).

3. **DECIDED** — `GUI-p05012` title duplicates §6.7 section heading. Acceptable: one is a section title, one is a REQ inside it. Bigger implication captured as new convention: **filename = section heading**, with PDF compile interleaving by REQ ID sans namespace+level (see Convention notes).

4. **DECIDED** — §6.5 sub-numbering `6.4.1/6.4.2/6.4.3` (copy-paste defect from §6.4). Cleaned during authoring; Phase 3 uses §6.5.1–§6.5.3.

5. **DECIDED** — Placeholder anchors `{#heading=}` / `{#heading}` on §5.3.2, §5.3.3, §5.4.2. Cleaned during authoring; new elspais files have proper headings.

6. **DECIDED** — §5.2.5 "5.2.5." trailing dot. Cosmetic; stripped during authoring.

7. **DECIDED** — §4.3 TOC stale 2FA anchor (`h.zbsv94awcp47`). 2FA REQs live in §5.5.2 / §5.5.3 (correctly placed in mapping). TOC artifact ignored.

8. **DECIDED** — §4 TOC vs body numbering drift. Body numbers are authoritative; mapping uses body numbers.

9. **DECIDED** — §7.4.1–§7.4.7 notification appendix entries have no explicit `Reference:` line; image-to-REQ binding inferred from prose. Acknowledged as inference; Phase 3 authoring carries the binding forward and reviewers can correct.

10. **DECIDED** — `REQ-CAL-*` REQs without a platform-side parent (`REQ-CAL-p00007`, `REQ-CAL-p00088`, plus the reclassified `GUI-p03001`). Phase 3 authors these with the **"only option in code today"** follow-up subsection (see Convention notes). The rationale: these are currently single-rule encodings but should become sponsor-configurable in principle; the subsection makes the gap visible so future sponsor onboarding doesn't blindly inherit Callisto's choices. Apply the same flag to other GUI / CAL- REQs as Phase 3 encounters them.
