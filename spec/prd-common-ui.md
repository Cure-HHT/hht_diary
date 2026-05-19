# Common UI Elements, Actions, and Interaction Patterns

The system shall use a consistent set of commonly displayed elements, buttons, and interaction patterns across the Sponsor Portal and Mobile Application. Where these terms are used in subsequent requirements, their behavior shall be interpreted according to the definitions provided in this section, unless specified otherwise.

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
