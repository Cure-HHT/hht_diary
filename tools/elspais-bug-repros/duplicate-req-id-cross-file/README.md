# Bug Repro: Cross-File REQ ID Collision Silently Merged

Tested against elspais 0.115.17 / 0.115.18 / 0.115.19. Likely affects earlier
0.114.x as well — was first observed when hht_diary bumped CI from 0.114.41 to
0.115.17.

## Summary

When two spec files in the same scan path define the same REQ ID:

1. `spec.no_duplicates` passes (reports "No duplicate requirement IDs") — should
   flag the collision.
2. The graph picks one definition as the canonical node (apparently last-wins
   by file order: title, body, source, and `implements_refs` come from the last
   file scanned).
3. But parent edges are **merged** across all definitions — the canonical node
   inherits `Refines:` / `Implements:` claims from the losing file(s).
4. `elspais fix` then **writes those inherited claims back into the canonical
   file's frontmatter**, materializing the merge on disk even though no human
   wrote that claim there.

The combined effect: a spec file with `Implements: -` quietly gains
`Implements: REQ-X, REQ-Y` after an unrelated `elspais fix` run, sourced from a
different file that happened to use the same REQ ID.

## How to reproduce

```sh
./reproduce.sh
```

The script copies the spec dir to a temp location, initializes a git repo,
runs `elspais checks` and `elspais fix`, and prints what changed.

## Manual reproduction

```sh
cp -r . /tmp/elspais-bug && cd /tmp/elspais-bug && git init -q \
  && git add . && git commit -qm init

# Step 1: spec.no_duplicates passes despite the collision
elspais checks 2>&1 | grep -E "no_duplicates|SPEC \("
#   → ✓ spec.no_duplicates: No duplicate requirement IDs

# Step 2: graph shows REQ-d00001 with merged parents
elspais graph | python3 -c '
import json, sys
g = json.load(sys.stdin)
n = g["nodes"]["REQ-d00001"]
print("label:", n["label"])
print("source:", n["source"])
print("content.implements_refs:", n["content"]["implements_refs"])
print("content.refines_refs:", n["content"]["refines_refs"])
print("parents:", n["parents"])
'
#   → label: 'Notifications Table Schema (file B definition)'   (B won)
#     content.implements_refs: ['REQ-p00002']                    (from B)
#     content.refines_refs: []                                    (B has none)
#     parents: [..., 'REQ-p00001', 'REQ-p00002']                  (A's Refines + B's Implements MERGED)

# Step 3: elspais fix materializes the merge on disk
elspais fix
grep -A2 "REQ-d00001:" spec/dev-file-b.md
#   → **Level**: dev | **Status**: Active | **Implements**: REQ-p00002
#     **Refines**: REQ-p00001       <-- NEW, copied from spec/dev-file-a.md
```

## Repo layout

```text
.elspais.toml         minimal config; spec/ scanned, code/test/docs disabled
spec/
  prd-targets.md      defines REQ-p00001 and REQ-p00002 (Implements targets)
  dev-file-a.md       defines REQ-d00001 with h2 (##), Implements: -, Refines: REQ-p00001
  dev-file-b.md       defines REQ-d00001 with h1 (#),  Implements: REQ-p00002
```

Both files claim the same ID (`REQ-d00001`) with different titles, bodies, and
metadata. The collision is deliberate and minimal — nothing else is wrong.

## Expected behavior

`spec.no_duplicates` should fire on cross-file REQ ID collisions. Two reasonable
implementations:

- **Strict**: any second definition of an existing REQ ID is an error,
  regardless of file. (Matches the spirit of the existing check name.)
- **Merge with warning**: if elspais intentionally supports merging across
  files (e.g. for cross-repo composition), at minimum surface a `~`/`⚠`
  diagnostic listing each file participating in the merge so the merge isn't
  silent. `elspais fix` should not synthesize new `Implements:` / `Refines:`
  claims from a different file into the canonical file's frontmatter.

## Observed in production

In `hht_diary` at commit `3f360a85` (origin/main 2026-05-13), the file
`spec/dev-notifications.md` (v1, superseded by `spec/dev-notifications-v2.md`
but never deleted) defined REQs `# REQ-d00166` through `# REQ-d00175` for the
notification platform. The file `spec/dev-portal-api.md` later added new
`## REQ-d00166` through `## REQ-d00170` for portal activation. Two unrelated
features, same REQ IDs.

When CI was bumped from elspais 0.114.41 to 0.115.17, `elspais fix` rewrote
`spec/dev-portal-api.md` and silently added `Implements: REQ-p20078,
REQ-p01018, REQ-p00016, REQ-p00017` to the five portal REQs — none of which
were authored by a human, all sourced from the colliding entries in
`spec/dev-notifications.md`. Spec hashes were not invalidated by the change
(elspais treats `Implements:` as derived metadata outside the hash), so
`spec.hash_integrity` didn't catch it either.

The data fix was to renumber the notification-semantic code/SQL references
from the v1 IDs (d00166–d00175) to the v2 IDs (d00192–d00201) and delete
`spec/dev-notifications.md`. That removed the collision in the data; this
repro stands separately so the underlying elspais behavior can be addressed.
