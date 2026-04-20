# Questionnaire Approval User Journeys

> **Source**: prd-questionnaire-approval.md

---

## Study Coordinator / Investigator Journey

1. **Initiate Questionnaire Request**

   - Investigator logs into Sponsor Portal
   - Navigates to patient record
   - Selects questionnaire type to send (e.g., EQ, Nose HHT, Quality of Life)
   - Triggers push notification to patient's device

2. **Monitor Completion**

   - Portal updates status as patient progresses through the questionnaire
   - Questionnaire status changes to "Ready for Review" when patient submits

3. **Review and Finalize**

   - Investigator verifies with patient that the questionnaire is complete
   - Select "Finalize and Score" to calculate score, store permanently, and lock questionnaire

4. **Delete (if applicable)**

   - Study coordinator may delete the questionnaire at any step after it was sent (Sent, In Progress, or Ready to Review)
   - A deletion reason is recorded in the audit trail
   - Deletion is NOT permitted after finalization

## Patient Journey

1. **Receive Notification**

   - Patient receives push notification on mobile device
   - Notification indicates specific questionnaire to complete
   - Patient opens Diary app

2. **Complete Questionnaire**

   - Patient answers all questions in the questionnaire
   - Progress is saved locally during completion
   - All questions must be answered before submission

3. **Review Before Submission (Scored Questionnaires)**

   - For questionnaires with calculated scores, patient sees review screen
   - Patient can navigate back to modify any answers
   - Score is NOT calculated until after investigator approval

4. **Submit Questionnaire**

   - Patient selects "Complete and Submit"
   - Answers sync to study database
   - Status visible as "Submitted - Awaiting Review"

5. **Edit Before Finalization (if applicable)**

   - Patient may edit their answers at any time before the investigator finalizes the questionnaire
   - Edits are permitted during Sent, In Progress, and Ready to Review statuses
   - If the patient edits after submission, the questionnaire returns to "In Progress" status
