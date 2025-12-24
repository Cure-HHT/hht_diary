# Objective
Whenever a new defect is create, we should have failing test created for the defect in this Integration_test folder.  Test code shoould be submitted for review prioe to merged into the repo.  In addition, the test code should follow the team guidelines.

For the integration test, we would like to use the following guidelines:
1. Use the template that is provided in this document below
2. Ensure that the test use ClinicalDiaryApp() and not using the general material app.  
3. The team wants to minimize the number of test files.  Therefore, newly created test should be added to existing test file.
4. Test description should be self-descriptive and test flow should be documented.
5. Claude would attempt to use Mock, if the implementation is not as expected, ask claude to revise it.  
6. Claude will try to fix the bug, specifically tell claude NOT to do so.
7. If claude try to fix the library, hit Esc to interrupt claude.  You might have to remind claude to not add "Fix lib code..." on the plan
8. Verify that the test failed where it is supposed to fail.  
9. Set the Skip flag = true (skip: true) on the test as part of test signature
10. Review test code that claude implemented


## Sample Claud prompt template:
I am working on Linear ticket CUR-999.
Using a TDD approach, create a failing integration test. 
First, ensure all test pass.
Add new code to this file:  < selected test file >   
Use the actual ClinicalDiaryApp()
Use testTimezoneOverride in the TimezoneService to set the timezone to PST 
On the homepage, click on the calendar button
On the calendar widget, select a date in the past.  
Verify that the title of the page is the selected date on the calendar and the subtitle is: "What happened on this day?"
Verify that there are 3 options: "Add nosebleed event", "No nosebleed events", and "I don't recall / unknown"
Click on "Add nosebleed event"
Verify that the date above of the event summary is the same date as the one on the date picker and is the same as the date selected on the calendar widget
On the Time zone picker, select EST (US)
Verify that the date above of the event summary is the same date as the one on the date picker.  This is where the defect is.
Document the test code with the tested user flow. 
Ensure dart analyzer has no error, warnings or info in test code nor lib code.
Do not fix lib code to get the test to pass. Let a human review failed tests first.


