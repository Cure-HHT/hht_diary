# Agent Naming System

## Overview

Agents are named after **inanimate mechanical objects** for easy identification. The name is deterministically derived from the product branch session ID.

## Naming List

Mechanical objects (alphabetically sorted):

1. anvil
2. axle
3. bearing
4. bellows
5. bolt
6. cam
7. clamp
8. clutch
9. crank
10. drill
11. flywheel
12. forge
13. fulcrum
14. gear
15. hammer
16. hinge
17. hoist
18. jack
19. lathe
20. lever
21. motor
22. piston
23. pulley
24. pump
25. ratchet
26. rivet
27. rotor
28. saw
29. spindle
30. spring
31. sprocket
32. turbine
33. valve
34. vise
35. wedge
36. wheel
37. winch
38. wrench

## Name Generation Algorithm

```bash
# Extract session ID from product branch
PRODUCT_BRANCH=$(git branch --show-current)
# Example: claude/refactor-tool-docs-011CUamedUhto5wQEfRLSKTQ
SESSION_ID=$(echo $PRODUCT_BRANCH | grep -oP '\d+[A-Za-z]+$')

# Generate hash and map to name list
NAMES=(anvil axle bearing bellows bolt cam clamp clutch crank drill flywheel forge fulcrum gear hammer hinge hoist jack lathe lever motor piston pulley pump ratchet rivet rotor saw spindle spring sprocket turbine valve vise wedge wheel winch wrench)
HASH=$(echo -n "$SESSION_ID" | md5sum | grep -oP '^[0-9a-f]+')
INDEX=$((0x${HASH:0:8} % ${#NAMES[@]}))
AGENT_NAME=${NAMES[$INDEX]}

echo "Agent name: $AGENT_NAME"
# Example output: "Agent name: wrench"
```

## Usage Examples

**Product branch**: `claude/refactor-tool-docs-011CUamedUhto5wQEfRLSKTQ`
**Session ID**: `011CUamedUhto5wQEfRLSKTQ`
**Agent name**: `wrench` (deterministic hash)
**Agent branch**: `claude/wrench`
**Worktree path**: `/home/user/diary_prep-wrench/`

## Benefits

- ✅ Human-friendly memorable names
- ✅ Deterministic (same session ID = same name)
- ✅ Easy to reference in conversation ("wrench agent")
- ✅ Fits agent/automation theme
- ✅ No collisions (different session IDs = different names)

## Implementation

All agent-ops scripts and documentation use `$AGENT_NAME` instead of `$AGENT_ID`.

**Before**: `claude/ai-agent-011CUamedUhto5wQEfRLSKTQ`
**After**: `claude/wrench`

**Before**: `/home/user/diary_prep-agent-011CUamedUhto5wQEfRLSKTQ/`
**After**: `/home/user/diary_prep-wrench/`
