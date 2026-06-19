# Git Workflow

The development workflow is defined authoritatively in **CLAUDE.md**:

- **§1 Requirement Traceability** — `DIARY-{PRD|GUI|OPS|DEV}-{kebab}` requirement ids,
  `[CUR-NNN]` commit messages, and `// Implements:` / `// Verifies:` assertion annotations.
- **§2 Workflow Enforcement** — claim, update, and close tickets via the Linear MCP.
- **§5 Branch Protection** — branch from `main` as `CUR-NNNN-{kebab-slug}`; never commit to `main`.

Git hooks in `.githooks/` (enabled via `./tools/setup-repo.sh`) enforce these — see
`docs/git-hooks-setup.md`.
