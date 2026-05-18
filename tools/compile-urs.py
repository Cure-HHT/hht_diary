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
import subprocess
import sys
from pathlib import Path

# Allow `python tools/compile-urs.py` from repo root
sys.path.insert(0, str(Path(__file__).parent))

from urs_compile.graph_loader import Graph  # noqa: E402
from urs_compile.interleave import interleave_section  # noqa: E402
from urs_compile.manifest import Manifest  # noqa: E402
from urs_compile.render import render_node  # noqa: E402


def assemble_markdown(graph: Graph, manifest: Manifest) -> str:
    """Build the full assembled markdown document body (no frontmatter / appendices)."""
    parts: list[str] = []
    for chapter in manifest.chapters:
        parts.append(f"\n\n# {chapter.number}. {chapter.title}\n")
        for section in chapter.sections:
            parts.append(f"\n## {section.number} {section.title}\n")
            file_nodes: list = []
            for relpath in section.files:
                file_nodes.extend(graph.files_for_relative_path(relpath))
            if not file_nodes:
                parts.append(
                    f"\n*(No content found for {section.number} — manifest references {section.files})*\n"
                )
                continue
            for _kind, node in interleave_section(graph, file_nodes):
                parts.append(render_node(node))
                parts.append("\n")
    return "".join(parts)


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
                chunks.append(f"\n\n# {key.title()}\n\n")
                chunks.append(full.read_text())
    return "\n\n".join(chunks)


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
        "--include-before-body", str(cover),
        "--toc",
        "--toc-depth=3",
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
    resource_paths = [repo_root]
    if cal_root:
        resource_paths.append(cal_root)

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
