# URS-v1 Migration — Handoff Prompt for Next Session

Paste the block below into a new Claude Code session in this worktree. It's
self-contained: pointers to files, current state, open decisions, and
relevant memories. Bypass the early discovery step — go straight to the
open question.

---

## Begin handoff prompt

```text
Picking up the URS-v1 migration on the URS-1 branch in both worktrees.
Current state: spec/ trees are authoritative (Phases 0-6 done in earlier
sessions); a single compiled URS PDF lives at docs/urs-compiled.pdf
(302 pages, 32 images, ~843 hyperlinks). The migration plan and project
memories are already in your context — load them at start.

Working directories
- hht_diary side:  /home/metagamer/cure-hht/hht_diary-worktrees/URS-1
- callisto side:   /home/metagamer/cure-hht/hht_diary_callisto-worktrees/URS-1

Both worktrees are on branch URS-1, pushed, with open draft PRs:
- github.com/Cure-HHT/hht_diary/pull/new/URS-1
- github.com/Cure-HHT/hht_diary_callisto/pull/new/URS-1

Key files (hht_diary side unless noted)
- docs/urs-compiled.pdf            current compile (review side-by-side
                                    against docs/archive/URS-v1.0.pdf)
- tools/compile-urs.sh             multi-stage compile orchestrator
- tools/pdf-merge-with-links.py    pypdf merge (preserves named dests;
                                    pdfunite + gs strip them)
- docs/urs-cover.tex               LaTeX cover (Sponsor/Protocol/Version)
- docs/urs-template.latex          customized pandoc LaTeX template
- docs/urs-frontmatter.md          §1 Intro / §2 Revision / §3 Signatures
- docs/urs-appendices.md           §7 Appendices (32 image refs)
- docs/urs-migration-mapping.md    the 107-row Phase-1.2 mapping (locked)
- docs/event-sourcing-gap-analysis.md  EVS upstream gaps (defer)
- docs/archive/URS-v1.0.{md,pdf}   archived legacy source
- ~/elspais/FEATURE_REQUEST.md     5 features filed upstream

Federation convention (do NOT change)
- Only hht_diary_callisto declares .elspais.local.toml (associate
  -> hht_diary). hht_diary has NO .elspais.local.toml. Symmetric
  config breaks with "nested associates" error. Documented in both
  repos' spec/README.md.

Open decision (what blocked the last session)
- "Track 3": single-pandoc-compile to fix the remaining URS-parity
  gaps. The multi-stage compile that produces docs/urs-compiled.pdf
  today has three separate TOCs, body chapters numbered "1. Product
  Requirements" instead of "4. SYSTEM-WIDE STANDARDS", and section
  sort-order alphabetical-by-filename rather than URS section order
  (4.1, 4.2, 4.3, ...). Quick fixes (table borders, page header,
  appendix numbering) are in commit 909d7a0b. The remaining gaps
  cannot be patched in place; they require a different compile
  pipeline.

Track 3 plan (proposed; user has not approved)
1. Author tools/urs-section-map.yaml — manifest mapping each spec
   file to its URS chapter + section (e.g.
       spec/prd-common-ui.md -> "4.1"
       spec/prd-user-account.md -> "5.1"
       callisto/spec/prd-rbac.md -> "4.3 (CAL overlays)"
       ... )
2. Build tools/compile-urs.py replacing the .sh:
   a. Load the manifest
   b. For each spec file (in URS-section order), run `elspais render`
      to get per-REQ markdown OR just cat the raw spec file
   c. Inject URS chapter/section headings ("## 4.1 Common UI Elements")
   d. Prepend urs-frontmatter.md, append urs-appendices.md
   e. Run pandoc ONCE on the assembled markdown with the URS template
      + cover -> single PDF
3. Output: one TOC (tocdepth=3), continuous page numbering, URS-correct
   chapter numbering, ordered sections. No pypdf-merge needed.
4. Risk: bypasses elspais's pdf assembler entirely. We'd lose its
   auto-generated Topic Index unless we synthesize one ourselves.

Other queued follow-ups (not blocking Track 3)
- Code-annotation sweep: `// Implements: REQ-pNNNNN/A` -> new IDs.
  Defer until Phase-3 IDs are stable.
- URS-Phase-3 reconciliation: walk every TODO block in retained
  legacy REQs and re-parent its Refines target.
- Definitions blocks: rewrite from `**Term:**` bold-prefix to
  pandoc def-list syntax (`Term\n: definition`) so elspais's
  terms feature can auto-generate the glossary + cross-link
  defined terms. FEATURE_REQUEST item #4.

Recent commits (last in each repo)
- hht_diary:
    909d7a0b PDF parity round 2: bordered tables, signature spacing, headers
    334f3f81 Track 1+2B: URS chapter intros + frontmatter/appendices
    aa6bd0f6 PDF: preserve hyperlinks across merge + switch to Arial
    f34c2fee PDF formatting parity: URS-style cover, header/footer, 12pt
- callisto:
    a84c006  gitignore err_daemon.log
    a3bf36d  Untrack err_daemon.log
    10b0d0b  Track 1: URS chapter-intro prose in callisto overlay files
    7668cc6  Document asymmetric federation convention

Don't reflex-push after every commit. Wait for explicit cue.

Start by:
1. Re-reading the user's last screenshots / feedback in this file if
   needed for context — the four images are referenced in the spec
   README. The PDF parity issues they highlighted are:
     - Tables in §2 / §3 need vertical borders + shaded header   [fixed in 909d7a0b]
     - Signature block: more room for sigs, wider table          [fixed in 909d7a0b]
     - Page header missing first 8 pages                         [fixed in 909d7a0b]
     - TOC has only top-level chapters in first TOC              [needs Track 3]
     - Two more TOCs (diary body, callisto body)                 [needs Track 3]
     - Appendix entries: "1.4.10 7.3.7..." double-numbering      [fixed in 909d7a0b]
     - Original URS chapter has non-REQ prose                    [fixed in 334f3f81]

2. Ask the user whether to implement Track 3 now or defer.
   The user previously declined Track 3 in favor of quick fixes,
   then changed their mind after seeing the round-2 result.
```

## End handoff prompt

---

## Optional: short version

If the longer prompt feels excessive, the minimum context to start is:

```text
Continuing URS-v1 migration on URS-1 branch. Both worktrees pushed,
draft PRs open. PDF compiles at docs/urs-compiled.pdf (302 pp). Last
work: round-2 PDF parity fixes in commit 909d7a0b (hht_diary side).
Open decision: implement "Track 3" (single-pandoc-compile to fix
three-TOC and chapter-numbering issues) or defer. Read
docs/urs-migration-next-session.md for full context.
```
