# REQ-tv-d00005: Elspais Test Output Format

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00001

## Assertions

A. Test runs SHALL produce a JSON output file at `tests/results/trace_results.json`.

B. The JSON output SHALL conform to format version "1.0" as specified in this requirement.

C. Each test result entry SHALL include: `requirement_id`, `assertion_id`, `full_id`, `test_name`, `test_file`, `test_line`, `status`, `duration_ms`, `error_message`, and `timestamp`.

D. The `requirement_id` field SHALL contain the base requirement ID without assertion suffix (e.g., `REQ-tv-d00001`).

E. The `assertion_id` field SHALL contain only the assertion letter (e.g., `A`) or null if the test covers the entire requirement.

F. The `full_id` field SHALL contain the complete reference including assertion suffix if applicable (e.g., `REQ-tv-d00001-A`).

G. The `status` field SHALL be one of: `passed`, `failed`, or `skipped`.

H. The output SHALL include a `summary` object with: `total`, `passed`, `failed`, `skipped`, and `coverage_percentage` fields.

I. Test functions SHALL include the requirement ID in their docstring for extraction by the reporter.

J. A pytest plugin SHALL be implemented in `conftest.py` to generate the output automatically.

K. The reporter SHALL extract requirement IDs from test docstrings using the pattern `REQ-tv-[pdo]\d{5}(?:-[A-Z])?`.

L. The output file SHALL be generated at the end of the pytest session via `pytest_sessionfinish` hook.

M. The `generated_at` field SHALL contain an ISO 8601 formatted timestamp.

## Rationale

Elspais requires structured test results to incorporate into the traceability matrix. The JSON format enables:
- Automated parsing and integration
- Bidirectional traceability (requirements to tests, tests to requirements)
- Coverage reporting at the assertion level
- Historical tracking of test results

The pytest plugin approach ensures:
- Automatic generation without manual steps
- Consistent format across all test runs
- Integration with existing pytest workflows
- No changes required to test execution commands

## Format Example

```json
{
  "format_version": "1.0",
  "generated_at": "2026-01-03T12:34:56Z",
  "test_run_id": "abc123",
  "results": [
    {
      "requirement_id": "REQ-tv-d00001",
      "assertion_id": "A",
      "full_id": "REQ-tv-d00001-A",
      "test_name": "test_jinja2_environment_used",
      "test_file": "test_template_architecture.py",
      "test_line": 15,
      "status": "passed",
      "duration_ms": 12,
      "error_message": null,
      "timestamp": "2026-01-03T12:34:56.123Z"
    }
  ],
  "summary": {
    "total": 26,
    "passed": 24,
    "failed": 2,
    "skipped": 0,
    "coverage_percentage": 92.3
  }
}
```

*End* *Elspais Test Output Format* | **Hash**: 5219f9e0
