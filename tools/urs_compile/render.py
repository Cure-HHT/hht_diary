"""Render GraphNodes to markdown for the URS PDF compile."""

from __future__ import annotations

from pathlib import Path

import jinja2

from .graph_loader import Graph, GraphNode


_TEMPLATE_DIR = Path(__file__).parent / "templates"
_env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(_TEMPLATE_DIR),
    autoescape=False,
    trim_blocks=True,
    lstrip_blocks=True,
)


def render_remainder(node: GraphNode) -> str:
    return node.content.get("text", "")


def render_requirement(node: GraphNode, graph: Graph) -> str:
    """Render a REQUIREMENT node to markdown.

    Walks `node.children` once in source order so each ASSERTION lands
    immediately under whichever REMAINDER subheading preceded it. This
    preserves the source author's grouping (e.g. `**Trigger**` / `**Suppression**`
    bold paragraphs inside an Assertions block keep their lettered
    assertions adjacent rather than collapsing all assertions into one
    flat list).

    Output layout (when children are interleaved):
      ### Title  {#req-id}
      **REQ ID:** `req-id`
      **Refines:** `...`
      #### Overview
      <text>
      #### Assertions
      #### Trigger
      **A.** <text>
      **B.** <text>
      #### Suppression
      **C.** <text>
      #### Rationale
      <rationale>

    If an ASSERTION appears before any "Assertions"-labelled REMAINDER,
    an implicit `#### Assertions` heading is emitted to anchor it. If no
    Rationale REMAINDER is present in the children, the REQ's
    `content.rationale` is emitted at the end as a fallback (elspais
    surfaces some rationale prose only via that field).
    """
    # Header (heading + REQ ID + Refines/Satisfies edges) — Jinja handles these.
    template = _env.get_template("req.md.j2")
    header = template.render(node=node).rstrip()

    body_parts: list[str] = [header]
    emitted_assertions_header = False
    saw_rationale_remainder = False

    for child_id in node.children:
        if not graph.has_node(child_id):
            continue
        child = graph.get_node(child_id)

        if child.kind == "REMAINDER":
            heading = (child.content.get("heading") or child.label or "").strip()
            text = (child.content.get("text") or "").strip()
            heading_lower = heading.lower()
            if heading_lower == "assertions":
                emitted_assertions_header = True
            if heading_lower == "rationale":
                saw_rationale_remainder = True
            if heading:
                body_parts.append(f"\n\n#### {heading}\n")
            if text:
                body_parts.append(f"\n{text}\n")

        elif child.kind == "ASSERTION":
            if not emitted_assertions_header:
                body_parts.append("\n\n#### Assertions\n")
                emitted_assertions_header = True
            label = child.content.get("label") or "?"
            text = (child.label or "").strip()
            body_parts.append(f"\n**{label}.** {text}\n")

    # Fallback: emit content.rationale only when the children didn't
    # already supply a Rationale REMAINDER (avoids duplicate sections).
    if not saw_rationale_remainder:
        rationale = (node.content.get("rationale") or "").strip()
        if rationale:
            body_parts.append("\n\n#### Rationale\n")
            body_parts.append(f"\n{rationale}\n")

    return "".join(body_parts).rstrip() + "\n"


def render_node(node: GraphNode, graph: Graph | None = None) -> str:
    if node.kind == "REMAINDER":
        return render_remainder(node)
    if node.kind == "REQUIREMENT":
        if graph is None:
            raise ValueError("render_node requires a Graph for REQUIREMENT nodes")
        return render_requirement(node, graph)
    raise ValueError(f"Cannot render node kind {node.kind!r}")
