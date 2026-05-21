# Status Registry

The system maintains defined sets of status values for the principal entities tracked across the Sponsor Portal and Mobile Application. The values and transitions in this section are authoritative; subsequent requirements that refer to a status by name shall be interpreted according to the definitions here.

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
