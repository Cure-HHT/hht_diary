# Agent Ops File Guide

**Purpose**: Quick reference for what each file does.

---

## Directory Structure

```
agent-ops/
├── docs/                           # System documentation
│   ├── concepts.md                 # Core concepts (read first!)
│   ├── two-branch-system.md        # Product vs agent branches
│   ├── file-guide.md               # This file
│   ├── quick-ref.md                # Command cheat sheet
│   └── workflows/                  # Workflow guides
│       ├── start-session.md
│       ├── during-session.md
│       ├── end-session.md
│       └── resume.md
│
├── ai/                             # AI assistant resources
│   ├── AGENT_GUIDE.md              # Concise AI workflow
│   └── templates/                  # Session templates
│       ├── plan.md
│       ├── diary.md
│       └── results.md
│
├── scripts/                        # Automation tools
│   ├── new-session.sh              # Create session
│   ├── end-session.sh              # End and archive session
│   ├── resume.sh                   # Show current state
│   ├── show-agents.sh              # Discover other agents
│   ├── sync-agents.sh              # Update agent cache
│   └── sync-context.sh             # Update CONTEXT.md
│
├── sessions/                       # Active sessions (GITIGNORED)
│   └── YYYYMMDD_HHMMSS/            # Timestamped session
│       ├── plan.md                 # Goals and tasks
│       ├── diary.md                # Chronological log
│       ├── results.md              # Summary (at end)
│       └── notes.md                # Scratch space
│
└── (On agent branches only):
    ├── agents/                     # Agent state
    │   └── {agent-id}/
    │       ├── CONTEXT.md          # Current work
    │       ├── STATUS.md           # Last active time
    │       └── CURRENT_SESSION.md  # Active session link
    └── archive/                    # Completed sessions
        └── YYYYMMDD_HHMMSS_name/
            ├── plan.md
            ├── diary.md
            └── results.md
```

---

## File Purposes

### Documentation (docs/)

| File | Purpose | Who Reads |
|------|---------|-----------|
| `concepts.md` | Core concepts defined once | Everyone (start here) |
| `two-branch-system.md` | Product vs agent branch architecture | Setup, advanced users |
| `file-guide.md` | This file - what everything does | Quick reference |
| `quick-ref.md` | Command cheat sheet | Daily use |
| `workflows/*.md` | Step-by-step workflow guides | As needed |

### AI Resources (ai/)

| File | Purpose | Who Reads |
|------|---------|-----------|
| `AGENT_GUIDE.md` | Concise AI workflow with links | AI assistants (primary) |
| `templates/*.md` | Session file templates | Scripts, manual creation |

### Session Files (sessions/YYYYMMDD_HHMMSS/)

| File | Purpose | When Written | Gitignored? |
|------|---------|--------------|-------------|
| `plan.md` | Goals, tasks, success criteria | Session start | Yes (until archived) |
| `diary.md` | Chronological action log | During (append-only) | Yes (until archived) |
| `results.md` | Summary of outcomes | Session end | Yes (until archived) |
| `notes.md` | Scratch space | As needed | Yes (always) |

### Agent State (agents/{agent-id}/, on agent branch)

| File | Purpose | Who Writes |
|------|---------|------------|
| `CONTEXT.md` | Current work, status, tickets | Agent (updates periodically) |
| `STATUS.md` | Last active timestamp | Scripts (automatic) |
| `CURRENT_SESSION.md` | Link to active session | Scripts (optional) |

### Archive (archive/, on agent branch)

Contains completed sessions moved from `sessions/`. Committed to git for permanent record.

---

## File Lifecycle

### Session Files

1. **Created**: `./scripts/new-session.sh` creates `sessions/YYYYMMDD_HHMMSS/`
2. **Work**: Maintain `plan.md` and `diary.md` during session
3. **End**: Write `results.md`
4. **Archive** (optional): Move to agent branch `archive/`
5. **Commit**: Commit archive to git for permanent record

### Agent State Files

1. **Created**: First time setup on agent branch
2. **Updated**: Periodically during work
3. **Read**: By other agents via `git show origin/ai-agent-X:path`
4. **Never deleted**: Agent branches persist indefinitely

---

## Git Strategy

### Gitignored (Local)

```
agent-ops/sessions/           # Active work
agent-ops/sessions/*/notes.md # Scratch files
```

**Why**: In-progress work is local until archived.

### Committed (Shared)

```
agent-ops/docs/               # Documentation
agent-ops/ai/                 # AI resources
agent-ops/scripts/            # Tools

# On agent branches only:
agent-ops/agents/             # Agent state
agent-ops/archive/            # Completed sessions
```

**Why**: Docs and tools are shared. Agent state enables coordination.

---

## Which File Should I Edit?

| Task | File | Location |
|------|------|----------|
| Plan new session | `plan.md` | Current session |
| Log actions during work | `diary.md` | Current session |
| Summarize completed work | `results.md` | Current session |
| Scratch notes | `notes.md` | Current session |
| Update agent status | `CONTEXT.md` | Agent branch |
| Learn the system | `concepts.md` | docs/ |
| AI workflow | `AGENT_GUIDE.md` | ai/ |

---

## Read More

- **Core Concepts**: [concepts.md](concepts.md)
- **AI Workflow**: [ai/AGENT_GUIDE.md](../ai/AGENT_GUIDE.md)
- **Quick Commands**: [quick-ref.md](quick-ref.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/file-guide.md
