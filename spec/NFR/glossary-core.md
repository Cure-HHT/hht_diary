This checklist is designed to be the final "human-in-the-loop" gate before your extraction tool hashes a requirement into the Validation Suite.
Requirement Peer-Review Checklist (One-Page)
Category    Item to Verify    Pass/Fail
Identity    Does the requirement have a unique Hash or ID?    [ ]
Terminology    Are all defined terms bolded and mapped to the Glossary?    [ ]
Are external references marked as Reference Terms?    [ ]
Clarity    Does it use the word SHALL for mandatory actions?    [ ]
Is it free of ambiguous adjectives (e.g., "fast", "secure", "easy")?    [ ]
Is it written in the Active Voice (The System SHALL...)?    [ ]
Atomicity    Does it contain only one testable assertion (no "and" or "also")?    [ ]
Testability    Can a tester provide a discrete Pass/Fail result for this item?    [ ]
Is there a clear Expected Result for the assertion?    [ ]
Traceability    Does it list the parent requirement it Implements?    [ ]
Does it link to a identified Risk ID in the Risk Assessment?    [ ]
Compliance    Does it meet 21 CFR Part 11 rules (Audit Trail, Authority Checks)?    [ ]
Instructions for Use:
Peer Review: A developer other than the author must complete this checklist for every new PRD entry.
Health Check: If any item is marked "Fail," the requirement is marked "Dirty" and must be revised.
Audit Evidence: In a high-stakes audit, you can point to this process as your Quality Control (QC) mechanism for documentation.
Why this works for your tool:
Since you are "dogfooding" your extraction tool, you can add a metadata flag like : Reviewed By: [Name] to your spec file. Your tool can then block any requirement from the Traceability Matrix if that flag is missing or if the "Dirty" flag is still active.
Pro-tip: You can reference the NASA Systems Engineering Handbook as the source for your requirement quality standards to give the checklist extra "regulatory weight" during an audit.
NASA Standards (.gov)
NASA Standards (.gov)
