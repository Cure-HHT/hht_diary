We are going to implement the initial important submodule for capturing clinical trial data (in the first use, nosebleed incidents).  You will act as an expert in FDA clinical trial software architecture and development, especially in Dart and Flutter.

This is production software and will be used in a government regulated FDA studies in the uS (and also in the EU).   No shortcuts.

The entire app is explained here:
/Users/mbushe/dev/anspar/hht_diary/spec/prd-app.md

We'll consider this module to be for a flutter client only but perhaps it could be used on the server as well. (I don't think so the server has different requirements.)

The client and server system is explained in this prd:
/Users/mbushe/dev/anspar/hht_diary/spec/prd-event-sourcing-system.md

A newly created dart package exists for you to write into:
/Users/mbushe/dev/anspar/hht_diary/apps/common-dart/append_only_datastore

The client requirements:
REQ-p01001: Offline Event Queue with Automatic Synchronization
These requirements, though describe for the server, must also be true of the client (except "via database constraints" and "Materialized views...")
REQ-p01003: Immutable Event Storage with Audit Trail

Since a user can use two clients (two phones) the store can be loaded from the server via this server requirement:
REQ-p01005: Real-time Event Subscription

It should also support:
REQ-p01007: Error Handling and Diagnostics
REQ-p01008: Event Replay and Time Travel Debugging
REQ-p01009: Encryption at Rest for Offline Queue
REQ-p01012: Batch Event Operations
REQ-p01013: GraphQL or gRPC Transport Option (Let's just do REST)
REQ-p01014: Observability and Monitoring (via Dartastic OpenTelemetry)
REQ-p01015: Automated Testing Support
REQ-p01016: Performance Benchmarking
REQ-p01018: Security Audit and Compliance
FDA 21 CFR Part 11 Compliance Considerations - is very important

REQ-p01019: Phased Implementation

And we'll follow a phased implementation, starting with the MVP.

First, let's update the README.md with an explanation of what this module does.
Then create an ARCHITECTURE.md with a reasonable list architectural choices for this client module with tradeoffs. I'll read it an make a choice later.  Specifically, Hive/Isar/sqllite and any other dart databases.  Consider other open source options that may fit the requirements especially those listed in "Open Source Ecosystem"

Then create a PLAN.md with a checklist of steps that you will checkoff as you go along.

We also need to follow the dev principles in this document:
/Users/mbushe/dev/anspar/hht_diary/.claude/instructions.md

You have MCPs available for JetBrains (the project is opened), dart/flutter, git (let humans commit after review, only use git for history when needed), filesystem and shell.  All code must pass dart analyze.  All code must compile.  Tests must pass once code is available to make them pass. They can fail first, as per the instructions.md but this is not a tight requirement.

Write files to disk.  Avoid writing to your containerized filesystem.  Add dart roots to help you find files.