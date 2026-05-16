# Common UI Elements, Actions, and Status Registry

This file holds the named element, action, interaction, dialog, and status registries used as shorthand throughout the rest of the spec. It contains no requirement blocks of its own; every entry below is an authoritative vocabulary table referenced by other PRD/GUI requirements. Where subsequent requirements name a *Button*, *UI Element*, *Action*, *Interaction Pattern*, *Dialog Pattern*, or *Status* value, the behavior shall be interpreted according to the definition provided here unless that requirement explicitly states otherwise.

The tables transcribe the URS §4.1 (Common User Interface Elements and Actions) and §4.2 (Status Registry) content verbatim.

## Buttons

| Element | Behavior |
| :---- | :---- |
| Confirm | Confirms a pending action displayed in a dialog. Proceeds with the action upon click. |
| Cancel  | Discards any unsaved changes and returns the user to the previous state. No data is modified. |
| OK | Acknowledges a system message or notification and dismisses it. No action is confirmed or cancelled. |
| Submit | Finalizes and sends the current form or questionnaire data. Once submitted, the action cannot be undone unless explicitly permitted by the relevant requirement. |
| Next | Advances to the next step in a sequence. Data entered in the current step is preserved. |
| Back | Returns to the previous step in a sequence. Previously entered data is preserved. |
| Continue | Resumes a flow that was interrupted or paused. Returns the user to the point where they left off. |
| More details | Opens a detailed view displaying the full record associated with the current row. Represented as a button or link affordance on the row. |
| Close | Dismisses a modal or dialog without performing any action. No data is modified. |

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
| Real-time Filtering | A list updates as the user types without requiring explicit submission. |
| Preserved Search State | The search input is retained when the user navigates between tabs. |

## Dialog Patterns

| Element | Behavior |
| :---- | :---- |
| Acknowledgement Dialog | Displays a message informing the user of a system event or outcome. Requires the user to click OK to dismiss. No action is cancelled or confirmed. |
| Confirmation Dialog | Displays the consequence of a pending action. Requires the user to either confirm or cancel before the action is applied. |
| Reason Dialog — Free Text | Displayed before a high-impact action. Requires the user to enter a free text reason of up to 100 characters before proceeding. The action SHALL NOT proceed until a reason is provided. |
| Reason Dialog — Predefined List | Displayed before a high-impact action. Requires the user to select a reason from a sponsor-defined list before proceeding. The action SHALL NOT proceed until a reason is selected. |

## Sponsor Portal User Status

The system maintains a defined set of status values for Sponsor Portal user accounts.

| Status | Description |
| :---- | :---- |
| Pending Activation | The account has been created but the user has not yet accepted the invitation or set up their credentials. |
| Active | The account has been created and the user can log in and perform actions per their role and permissions. |
| Inactive | The account has been deactivated and the user can no longer log in. |

## Participant Status

The system maintains a defined set of status values representing the participant's linking, trial participation, device, and data synchronization state.

| Status | Description |
| :---- | :---- |
| Not Connected | The participant record has been synced from Rave EDC to the Sponsor Portal but the mobile application has not been linked to the Sponsor Portal. |
| Pending | An invitation has been sent to the participant but the participant has not yet linked their device. |
| Expired | An invitation has been sent to the participant but expired before the participant linked their device. |
| Linked - Awaiting Start | The participant's device is linked to the Sponsor Portal but Diary Data Synchronization has not yet been activated. |
| Trial Active | Diary Data Synchronization has been activated and diary entries are being transmitted to the Sponsor Portal and Rave EDC. |
| Disconnected | A Study Coordinator has manually disconnected the participant in the Sponsor Portal. Sponsor-specific rules remain applied to the mobile application but data is not syncing. Data will resume syncing when the participant is reconnected. |
| Not Participating | The participant has been marked as not participating following disconnection. Sponsor-specific rules are no longer applied to the mobile application. |

## Participant Status Transitions

The following transitions are valid. All other transitions are prohibited.

| From | To | Trigger |
| :---- | :---- | :---- |
| Not Connected | Pending | Study Coordinator generates linking code |
| Pending | Linked - Awaiting Start | Participant successfully enters linking code for the first time |
| Pending | Expired | The linking code expires as the participant did not use it |
| Expired | Pending | Study Coordinator regenerates linking code |
| Linked - Awaiting Start | Trial Active | Study Coordinator starts trial |
| Linked - Awaiting Start | Disconnected | Study Coordinator disconnects participant |
| Trial Active | Disconnected | Study Coordinator disconnects participant |
| Disconnected | Pending | Study Coordinator initiates reconnection |
| Disconnected | Not Participating | Study Coordinator marks participant as not participating |
| Not Participating | Disconnected | Study Coordinator reactivates participant |

## Questionnaire Status

The system maintains a defined set of status values for Questionnaire instances.

| Status | Description |
| :---- | :---- |
| Not Sent | No active Questionnaire exists for the current Cycle and a new one may be sent. |
| Sent | The Questionnaire has been transmitted to the participant's mobile application and is awaiting participant completion. |
| Delivery Failed | Transmission of the Questionnaire to the participant's mobile application was unsuccessful and the participant has not received it. |
| Ready to Review | The participant has submitted answers and the Study Coordinator may finalize. |
| Closed | The Questionnaire for that cycle has been completed by the participant and is finalized by the Study Coordinator. Subsequent Questionnaires for that cycle cannot be generated. |
