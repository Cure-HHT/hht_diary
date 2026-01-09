# REQ-tv-d00010: Review Data Models

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. CommentPosition, Comment, Thread, ReviewFlag, StatusRequest, Approval, ReviewSession, ReviewConfig, and ReviewPackage SHALL be implemented as dataclasses.

B. PositionType, RequestState, and ApprovalDecision SHALL be implemented as string enums for JSON compatibility.

C. Each dataclass SHALL implement a `to_dict()` method returning a JSON-serializable dictionary.

D. Each dataclass SHALL implement a `from_dict(data)` class method for deserialization from dictionaries.

E. Each dataclass SHALL implement a `validate()` method returning a tuple of `(is_valid: bool, errors: List[str])`.

F. Thread, Comment, StatusRequest, and ReviewPackage SHALL implement factory methods (`create()`) that auto-generate IDs and timestamps.

G. ThreadsFile, StatusFile, and PackagesFile container classes SHALL manage file-level JSON structure with version tracking.

H. CommentPosition SHALL support four anchor types: LINE (specific line), BLOCK (line range), WORD (keyword occurrence), and GENERAL (whole requirement).

I. StatusRequest SHALL automatically calculate its state based on approval votes and configured approval rules.

J. All dataclasses SHALL use UTC timestamps in ISO 8601 format.

## Rationale

Dataclasses provide immutable-by-default data structures with auto-generated `__init__`, `__repr__`, and comparison methods. The `to_dict`/`from_dict` pattern enables clean JSON serialization without requiring JSON encoder customization. The `validate()` method enables explicit validation at boundaries rather than relying on exceptions during construction.

The factory methods hide ID generation and timestamp creation from callers, ensuring consistent data creation patterns across the codebase.

*End* *Review Data Models* | **Hash**: 00000000
