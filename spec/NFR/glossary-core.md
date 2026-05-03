<!-- markdownlint-disable MD050 -->
<!-- This file uses both __term__ (Reference-Document terms) and **term**
     (System-Glossary terms). See glossary-example.md for the entry syntax. -->

# System Glossary

This file is the **System Glossary** — every domain-specific term used in
a normative requirement MUST appear here with a single, canonical
definition. Authors mark System-Glossary terms in requirement text using
`**term**`; Reference-Document terms (defined in an external standard)
use `__term__`.

For order of precedence between this glossary and external Reference
Documents, see `glossary-precedence.md`. For the syntax of an individual
glossary entry, see `glossary-example.md`. Authoring rules for
glossary-term enforcement live in `style-guide.md` (REQ-CAL-o00002 and
REQ-CAL-o00005-C).

## Conventions

- An assertion that uses a domain-specific term unbolded triggers an
  automated health-check failure (`style-guide.md` REQ-CAL-o00002-B).
- Any acronym used within a requirements document SHALL be a defined
  term in this glossary (`style-guide.md` REQ-CAL-o00005-C).
- Terms are listed alphabetically.
- A term that exists in a Reference Document SHALL be defined here as a
  Reference Term that points at the external source (see the
  `Email Address` example in `glossary-example.md`).

## Terms

Audit Trail
: A computer-generated, time-stamped record that captures the who, what,
  when, and why of every modification to an Electronic Record, satisfying
  21 CFR Part 11 §11.10(e).

Electronic Record
: Any combination of text, graphics, data, or other digital information
  created, modified, maintained, or distributed by the platform that is
  subject to 21 CFR Part 11.

Electronic Signature
: A computer-implemented signing event that, under 21 CFR Part 11 §11.50,
  is legally equivalent to a handwritten signature.

Investigator
: A clinical-trial role authorized by the Sponsor to view patient data,
  review safety triggers, and unlock individual questionnaires within
  the Investigator's assigned site.

Patient
: A human subject enrolled in a clinical trial who interacts with the
  platform via the diary application to record protocol-defined
  Electronic Records.

Role
: A named set of authorities granted to a User Account that determines
  which Electronic Records the account may read, write, or modify.

Sponsor
: The regulated entity that holds the IND or IDE and contracts the
  vendor to operate the platform for a specific clinical trial.

Sponsor Portal
: The web application used by Investigators and Sponsor staff to
  administer trials, review patient data, and manage User Accounts.

User Account
: The platform's representation of an individual authorized to interact
  with the system, identified by a unique Email Address and bound to one
  or more Roles.

User Session
: A bounded period of authenticated activity for a User Account,
  terminated by explicit sign-out or by the inactivity timeout
  configured per Role.

## External References

The Reference Documents that supply `__term__` definitions and govern
conflicts between definitions are listed in `glossary-precedence.md`.
Individual reference entries (with title, version, effective date, and
URL) follow the format demonstrated in `glossary-example.md`.
