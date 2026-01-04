# Requirements Traceability Tools

Tools for validating and tracking requirements across PRD, Operations, and Development specifications.

## Prerequisites

- **elspais CLI**: `pip install elspais` (version pinned in `.github/versions.env`)
- **Python 3.11+**: For supplementary scripts

See also: [spec/README.md](../../spec/README.md) for requirement format details.

## elspais CLI (Primary)

The `elspais` CLI handles validation, traceability, hashes, and editing. Configuration: `.elspais.toml`.

```bash
elspais --help              # Full command list
elspais <command> --help    # Command-specific help
```

## Local Scripts (Supplementary)

Scripts providing features beyond elspais core functionality.

| Script                 | Purpose                                                  |
| ---------------------- | -------------------------------------------------------- |
| `trace_view.py`        | Extended traceability with HTML edit mode, git detection |
| `analyze_hierarchy.py` | Domain classification and parent proposals for REQs      |
| `serve_trace_view.sh`  | Local dev server for interactive traceability viewing    |

### trace_view.py

```bash
python3 tools/requirements/trace_view.py --format both
python3 tools/requirements/trace_view.py --format html --embed-content --edit-mode
python3 tools/requirements/trace_view.py --coverage-report
```

### analyze_hierarchy.py

```bash
python3 tools/requirements/analyze_hierarchy.py --report
python3 tools/requirements/analyze_hierarchy.py --elspais  # Output for elspais edit --from-json
python3 tools/requirements/analyze_hierarchy.py --apply    # Apply changes via elspais
```

### serve_trace_view.sh

```bash
./tools/requirements/serve_trace_view.sh [port]  # Default: 8080
```

## Git Hooks

Pre-push runs `elspais validate` and `elspais index validate`. See `.githooks/README.md`.
