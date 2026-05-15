# Requirement Peer-Review Checklist

This checklist is the human-in-the-loop gate before the requirement
extraction tool hashes a requirement into the validation suite. A peer
(a developer other than the author) MUST complete the checklist for
every new or modified requirement.

## Checklist

| Category | Item | Pass / Fail |
| --- | --- | --- |
| Identity | Does the requirement have a unique hash and ID? | [ ] |
| Terminology | Are all defined terms bolded and mapped to the System Glossary? | [ ] |
| Terminology | Are external references marked as Reference Terms? | [ ] |
| Clarity | Does it use SHALL for mandatory actions? | [ ] |
| Clarity | Is it free of ambiguous adjectives (e.g., "fast", "secure", "easy")? | [ ] |
| Clarity | Is it written in the active voice ("The System SHALL ...")? | [ ] |
| Atomicity | Does it contain only one testable assertion (no "and", no "also")? | [ ] |
| Testability | Can a tester record a discrete pass / fail result? | [ ] |
| Testability | Is the expected result clear from the assertion text alone? | [ ] |
| Traceability | Does the header list the parent requirement under `Implements:`? | [ ] |
| Traceability | Does it link to a Risk ID in the Risk Assessment (`risks.md`)? | [ ] |
| Compliance | Does it satisfy 21 CFR Part 11 controls (audit trail, authority checks)? | [ ] |

## How to Use

- **Peer Review**: a developer other than the author completes the
  checklist for every new requirement.
- **Health Check**: any item marked "Fail" marks the requirement Dirty;
  it MUST be revised before reaching the Traceability Matrix.
- **Audit Evidence**: the completed checklist is the documented Quality
  Control record cited during an audit.

## Tooling Hook

Authors MAY add a `Reviewed By: <name>` metadata line to the spec file.
The extraction tool blocks any requirement from the Traceability Matrix
when the flag is missing or when a Dirty flag is still active.

## Reference

The NASA Systems Engineering Handbook is a recognized source for
requirement-quality standards and is suitable to cite as the authority
backing this checklist during an audit.
