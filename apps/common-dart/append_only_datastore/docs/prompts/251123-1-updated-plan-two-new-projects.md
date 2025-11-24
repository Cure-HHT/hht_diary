OK, now, we accept your recommendations: sqllite for the client and Postgresql for the server.

You can update the architecture status from DRAFT.

I made a new flutter package project:
apps/common-dart/trial_data_types
and this new flutter app for the clinical diary that will depend on the type and append libraries:
apps/clinical_diary

Let's put the common types in this project that can be shared between the client and dart code that run in Supabase.  They can also be the basis for PostgreSQL tables.

Then in the PLAN.md
/Users/mbushe/dev/anspar/hht_diary/apps/common-dart/append_only_datastore/PLAN.md
Mark the architecture as reviewed and approved.

Let's hold off on the other preimplementation gates:

* Development environment setup validated
* CI/CD pipeline configured

Let's work on the project setup.  I checked off the dart pub add's.

Next is: linting rules.  Should we change the default?
Then: Set up dependency injection structure - what do you recommend?  (get_it?  what other options?  I want to use Signals.  Ignore Riverpod if you see it in the doc)

Then:
does the application/ code belong in the append_only_datastore or in clinical_diary?

* [ ] Create folder structure:
Let's update the plan. domain can move to the new project:
apps/common-dart/trial_data_types

Infrastructure seems like it should be in a new project now that we separated client and server, correct?

Does application belong in append_only_datastore, the new
