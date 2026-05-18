#!/usr/bin/env python3
"""Compile the URS PDF via a single pandoc pass.

Pipeline:
  1. Read elspais graph JSON (build/graph.json by default).
  2. Read tools/urs-section-map.yaml manifest.
  3. Assemble markdown chapter-by-chapter, section-by-section.
     - Emit URS chapter and section headings from manifest.
     - For each section, walk FILE nodes whose relative_path matches; interleave
       DIARY + CAL REQs by kebab-stripped name (DIARY first, then CAL pair).
  4. Prepend frontmatter, append appendices + glossary.
  5. Invoke pandoc once with the URS LaTeX template + cover + resource path.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# Allow `python tools/compile-urs.py` from repo root
sys.path.insert(0, str(Path(__file__).parent))

from urs_compile.graph_loader import Graph  # noqa: E402
from urs_compile.interleave import interleave_section_by_path  # noqa: E402
from urs_compile.manifest import Manifest  # noqa: E402
from urs_compile.render import render_node  # noqa: E402


_HEADING_RE = re.compile(r"^(#{1,5})(\s+)", re.MULTILINE)
_LEADING_H1_RE = re.compile(r"\A\s*#\s+[^\n]*(\n+|\Z)")


def demote_headings(md: str, levels: int = 1) -> str:
    """Demote every ATX heading in `md` by `levels` (capped at H6)."""
    def repl(match: re.Match) -> str:
        hashes = match.group(1)
        new = "#" * min(6, len(hashes) + levels)
        return new + match.group(2)
    return _HEADING_RE.sub(repl, md)


def strip_leading_h1(md: str) -> str:
    """Remove the first top-level (`# ...`) heading from `md`.

    Spec files start with a `# File Title` that the URS manifest already
    surfaces as `## X.Y Section Title`. Drop the redundant heading before
    demoting so the section flows straight from URS heading into content.
    """
    return _LEADING_H1_RE.sub("", md, count=1)


def assemble_markdown(graph: Graph, manifest: Manifest) -> str:
    """Build the full assembled markdown document body (no frontmatter / appendices)."""
    parts: list[str] = []
    for chapter in manifest.chapters:
        # LaTeX adds the chapter/section numbers; we just emit titles.
        parts.append(f"\n\n# {chapter.title}\n")
        prev_section_num: int | None = None
        for section in chapter.sections:
            # Parse the manifest section number ("5.3" -> 3) and inject a raw
            # \setcounter when the manifest skips a slot (e.g. 5.1 -> 5.3 to
            # preserve a deliberate "User Interface" gap). LaTeX numbers
            # sections sequentially otherwise, which would silently re-number
            # 5.3+ to 5.2+ and confuse reviewers comparing to the manifest.
            try:
                section_idx = int(section.number.split(".")[-1])
            except (ValueError, IndexError):
                section_idx = None
            if (
                section_idx is not None
                and prev_section_num is not None
                and section_idx > prev_section_num + 1
            ):
                parts.append(
                    f"\n```{{=latex}}\n\\setcounter{{section}}{{{section_idx - 1}}}\n```\n"
                )
            prev_section_num = section_idx
            parts.append(f"\n## {section.title}\n")
            # Run interleave per manifest path: source_file-based lookup
            # surfaces CAL siblings even when federation collapsed FILE nodes.
            # We collect (kind, rendered_text) so we can demote only REMAINDER
            # output — REQ output is already at the final heading level
            # (### title / #### subsections) and must not be demoted.
            rendered_chunks: list[tuple[str, str]] = []
            emitted_any = False
            for relpath in section.files:
                for _kind, node in interleave_section_by_path(graph, relpath):
                    rendered_chunks.append((node.kind, render_node(node, graph)))
                    rendered_chunks.append(("SEP", "\n"))
                    emitted_any = True
            if not emitted_any:
                parts.append(
                    f"\n*(No content found for {section.number} — manifest references {section.files})*\n"
                )
                continue
            # Drop the redundant `# File Title` heading the first REMAINDER
            # carries from the spec file; URS section heading already labels it.
            first_rem_idx = next(
                (i for i, (k, _) in enumerate(rendered_chunks) if k == "REMAINDER"),
                None,
            )
            if first_rem_idx is not None:
                kind, text = rendered_chunks[first_rem_idx]
                rendered_chunks[first_rem_idx] = (kind, strip_leading_h1(text))
            # Demote spec-file REMAINDER headings by one level so spec H1 ->
            # H2 subsections under the URS section. REQ chunks are already
            # at the correct level (### / ####) and pass through unchanged.
            final_chunks: list[str] = []
            for kind, text in rendered_chunks:
                if kind == "REMAINDER":
                    text = demote_headings(text, levels=1)
                final_chunks.append(text)
            parts.append("".join(final_chunks))
    return "".join(parts)


def _rewrite_image_paths(text: str) -> str:
    """Rewrite spec-relative image paths so pandoc resolves them from repo root.

    Spec files at `spec/prd-*.md` reference images via `../docs/urs-extracted-images/`,
    which is correct relative to the spec file but wrong when pandoc reads the
    assembled markdown from `build/`. Strip the `../` prefix so the path is
    relative to the repo root (which is on `--resource-path`).
    """
    return text.replace("../docs/urs-extracted-images/", "docs/urs-extracted-images/")


def assemble_full_document(
    graph: Graph,
    manifest: Manifest,
    repo_root: Path,
) -> str:
    """Assemble the full markdown including frontmatter, body, appendices, glossary."""
    chunks: list[str] = []
    if manifest.frontmatter:
        path = repo_root / manifest.frontmatter
        if path.exists():
            chunks.append(path.read_text())
    chunks.append(assemble_markdown(graph, manifest))
    for key in ("appendices", "glossary"):
        path_str = getattr(manifest, key)
        if path_str:
            full = repo_root / path_str
            if full.exists():
                text = full.read_text()
                # Only inject a chapter heading when the file doesn't already
                # provide one; appendices and glossary commonly start with
                # `# Appendices` / `# Glossary`.
                if not _LEADING_H1_RE.match(text):
                    chunks.append(f"\n\n# {key.title()}\n\n")
                chunks.append(text)
    return _rewrite_image_paths("\n\n".join(chunks))


def run_pandoc(
    markdown_path: Path,
    output_path: Path,
    template: Path,
    cover: Path,
    resource_paths: list[Path],
    engine: str = "xelatex",
) -> None:
    cmd = [
        "pandoc",
        str(markdown_path),
        "-o", str(output_path),
        "--pdf-engine", engine,
        "--template", str(template),
        # Cover is consumed by the template's `$cover-tex$` slot, which
        # places it before the TOC and applies `\thispagestyle{empty}`.
        # `--include-before-body` would land it BETWEEN TOC and body, hiding
        # the cover behind the contents page; use `--variable` instead.
        f"--variable=cover-tex:{cover}",
        "--toc",
        "--toc-depth=3",
        # report class: map `#` -> \chapter so URS chapter numbering (4, 5, 6)
        # survives. pandoc 2.x defaults to \section without this flag, which
        # collapses our chapter headings down a level and yields 0.x numbering.
        "--top-level-division=chapter",
        "--resource-path=" + ":".join(str(p) for p in resource_paths),
    ]
    subprocess.run(cmd, check=True)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--graph", type=Path, default=Path("build/graph.json"))
    p.add_argument("--manifest", type=Path, default=Path("tools/urs-section-map.yaml"))
    p.add_argument("--output-md", type=Path, default=Path("build/urs-assembled.md"))
    p.add_argument("--output-pdf", type=Path, default=Path("docs/urs-compiled.pdf"))
    p.add_argument("--template", type=Path, default=Path("docs/urs-template.latex"))
    p.add_argument("--cover", type=Path, default=Path("docs/urs-cover.tex"))
    p.add_argument(
        "--cal-root", type=Path,
        default=Path("../../hht_diary_callisto-worktrees/URS-1"),
        help="Path to callisto worktree (for image resource paths)",
    )
    p.add_argument(
        "--skip-pdf", action="store_true",
        help="Stop after markdown assembly (useful for tests)",
    )
    args = p.parse_args()

    repo_root = Path(".").resolve()
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_pdf.parent.mkdir(parents=True, exist_ok=True)

    graph = Graph.from_json_path(args.graph)
    manifest = Manifest.from_yaml_path(args.manifest)

    md = assemble_full_document(graph, manifest, repo_root)
    args.output_md.write_text(md)
    print(f"Assembled markdown: {args.output_md} ({len(md):,} chars)", file=sys.stderr)

    if args.skip_pdf:
        return 0

    cal_root = args.cal_root.resolve() if args.cal_root.exists() else None
    resource_paths = [repo_root, repo_root / "docs" / "urs-extracted-images"]
    if cal_root:
        resource_paths.append(cal_root)
        cal_images = cal_root / "docs" / "urs-extracted-images"
        if cal_images.exists():
            resource_paths.append(cal_images)

    run_pandoc(
        markdown_path=args.output_md,
        output_path=args.output_pdf,
        template=args.template,
        cover=args.cover,
        resource_paths=resource_paths,
    )
    print(f"Compiled PDF: {args.output_pdf}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
