# Git Hooks Setup

Enable the repo's git hooks:

```bash
./tools/setup-repo.sh        # or: git config core.hooksPath .githooks
```

The hooks live in `.githooks/` and enforce commit-message format (`[CUR-NNN]`), requirement
traceability, the Phase Design Spec rule, and secret scanning (gitleaks). See **CLAUDE.md** §1
(Requirement Traceability) and §7 (Phase Design Spec Requirements) for what they enforce.
