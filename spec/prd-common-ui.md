# Common UI Elements, Actions, and Interaction Patterns

The system shall use a consistent set of commonly displayed elements, buttons, and interaction patterns across the *Sponsor* Portal and *Mobile Application*. Where these terms are used in subsequent requirements, their behavior shall be interpreted according to the definitions provided in this section, unless specified otherwise.

## Buttons

| Element | Behavior |
| :---- | :---- |
| Confirm | Confirms a pending *Action* displayed in a dialog. Proceeds with the *Action* upon click. |
| Cancel  | Discards any unsaved changes and returns the *User* to the previous state. No data is modified. |
| OK | Acknowledges a system message or notification and dismisses it. No *Action* is confirmed or cancelled. |
| Submit | Finalizes and sends the current form or *Questionnaire* data. Once submitted, the *Action* cannot be undone unless explicitly permitted by the relevant requirement. |
| Next | Advances to the next step in a sequence. Data entered in the current step is preserved. |
| Back | Returns to the previous step in a sequence. Previously entered data is preserved. |
| Continue | Resumes a flow that was interrupted or paused. Returns the *User* to the point where they left off. |
| More details | Opens a detailed view displaying the full record associated with the current row. Represented as a button or link affordance on the row. |
| Close | Dismisses a modal or dialog without performing any *Action*. No data is modified. |

## UI Elements

| Element | Behavior |
| :---- | :---- |
| Tab | A navigation element that filters a list by a category. |
| Search Input | A single text input that filters a list in real time across specified fields. |
| Status Badge | An inline label displaying the current status of a record. |

## Actions

| Element | Behavior |
| :---- | :---- |
| Edit | Opens an existing record for modification. Changes are not applied until confirmed or submitted. Represented by a pencil icon. |

## Interaction Patterns

| Element | Behavior |
| :---- | :---- |
| Real-time Filtering | A list updates as the *User* types without requiring explicit *Submission*. |
| Preserved Search State | The search input is retained when the *User* navigates between tabs. |

## Dialog Patterns

| Element | Behavior |
| :---- | :---- |
| Acknowledgement Dialog | Displays a message informing the *User* of a system event or outcome. Requires the *User* to click OK to dismiss. No *Action* is cancelled or confirmed. |
| Confirmation Dialog | Displays the consequence of a pending *Action*. Requires the *User* to either confirm or cancel before the *Action* is applied. |
| Reason Dialog — Free Text | Displayed before a high-impact *Action*. Requires the *User* to enter a free text reason of up to 100 characters before proceeding. The *Action* SHALL NOT proceed until a reason is provided. |
| Reason Dialog — Predefined List | Displayed before a high-impact *Action*. Requires the *User* to select a reason from a *Sponsor*-defined list before proceeding. The *Action* SHALL NOT proceed until a reason is selected. |

## DIARY-GUI-portal-transport-status: Portal Transport Status Banner

**Level**: GUI | **Status**: Draft | **Implements**: -

<!-- satisfied-by: EVS-PRD-reaction-scope -->

The *Sponsor Portal* presents its list data over a live reactive transport. When that transport is degraded, the *User* needs a clear signal that the data on screen reflects the last update received rather than a live feed.

### Assertions

A. The *Sponsor Portal* SHALL display a non-dismissible banner above the data table on list pages whenever the reactive transport is reconnecting or disconnected, indicating that the data shown reflects the last update received.

B. List pages SHALL continue to display the last-received rows while the transport is reconnecting, rather than blanking or showing an empty state, and SHALL resume live updates and remove the banner when the transport reconnects.

### Rationale

The portal's lists are fed by a live subscription; a dropped transport otherwise leaves the *User* viewing data frozen at the moment of the drop with no indication it is no longer live. The banner mirrors the staleness signal of the Rave-pause banner but for the transport itself, so the two share a consistent "this is not a fresh feed" affordance. Retaining the last rows (rather than blanking) keeps the *User*'s context intact across a transient drop, since the underlying client reconnects automatically and re-replays a fresh snapshot on success; persisted data is unaffected because *Actions* are validated server-side against authoritative state regardless of what the stale view shows.

*End* *Portal Transport Status Banner* | **Hash**: 20c55120

## DIARY-GUI-portal-stale-client-reload: Portal Stale-Client Reload Prompt

**Level**: GUI | **Status**: Draft | **Implements**: -

The *Sponsor Portal* is a long-lived single-page client: once loaded, a tab keeps running its compiled bundle and never re-fetches the document on its own, so after a deploy it can run an older build than the deployed server indefinitely. The *User* needs to be brought onto the current build without losing in-progress work.

### Assertions

A. When the deployed server reports a portal UI version different from the running bundle's compiled version, the *Sponsor Portal* SHALL surface a non-blocking banner offering the *User* a control to reload onto the new version.

B. When the *User* is unauthenticated (on the login screen), the *Sponsor Portal* SHALL reload onto the new version automatically rather than prompting.

C. The *Sponsor Portal* SHALL NOT automatically reload an authenticated *User*; the reload SHALL be initiated by the *User* via the banner control.

### Rationale

Server and client ship from the same build, which stamps the identical version into both the bundle and the server's health report, so an inequality is a definitive "this tab is on an old build" signal — no separate update channel is needed. Prompting rather than silently reloading protects an authenticated *User* mid-form from losing work; on the login screen there is nothing to lose, so an automatic reload is the least-friction way to guarantee sign-in happens on the current build. The check is event-driven (on load, on transport reconnect after a deploy drains the old server, and on a login attempt) rather than polled, because those are exactly the moments the running build can first diverge from the deployed one.

*End* *Portal Stale-Client Reload Prompt* | **Hash**: 375e8009
