# Requirement-annotation sweep tooling (CUR-1451)

Scripts that drive the migration of code/CI annotations onto the URS-v1
convention: remove file-header `IMPLEMENTS REQUIREMENTS:` blocks and replace
legacy `REQ-{p|o|d}NNNNN` / `GUI-pNNNNN` ids with per-unit `// Implements:` /
`// Verifies:` annotations citing current `DIARY-*` ids and assertion labels.

elspais does not scan shell/yaml/ruby/tf annotations, so the requirement graph
cannot flag this debt. **These scripts are the source of truth for the sweep.**

## Scope

Code + CI + IaC only — `.dart`, `.yml`, `.yaml`, `.sh`, `.bash`, `.tf`,
`.tfvars`, `.rb`, `.py`, `.gradle`, `.kts`, and `Dockerfile`s. Excluded:
`spec/`, `spec-archive/`, `docs/` (prose, handled separately), generated Dart
(`*.g.dart`, `*.freezed.dart`, …), and build/vendor trees.

## `build_inventory.py`

Scans the in-scope tree and writes `inventory.json` — the Phase-1 work-list.
One row per unique legacy id with its citation sites, level, repo, and (where
the URS-v1 mapping resolves it) the new `DIARY-*` target.

```bash
python3 tools/requirements/build_inventory.py
```

Reruns are safe: human-entered `disposition` / `notes` (and any `source:manual`
`target`) are carried forward. During Phase 1 each id gets a disposition:
`port` | `rewrite` | `parent-cite` | `drop` | `cross-repo`.

## `verify_annotations.py`

The definition of done. Exits non-zero while any of these remain in scope:

1. legacy ids (`REQ-{p|o|d}NNNNN` / `GUI-pNNNNN`, incl. `CAL-`)
2. `IMPLEMENTS REQUIREMENTS:` file-header blocks
3. dangling annotations — `// Implements:` / `// Verifies:` citing a `DIARY-*`
   id or assertion label absent from the current `spec/` tree

```bash
python3 tools/requirements/verify_annotations.py   # 0 = clean, 1 = violations
```

Cross-repo citations (`HHT-*`, `EVS-*`, `CAL-*`) are syntax-checked only.
Wire into `.githooks/pre-push` once green so the debt cannot regress.
