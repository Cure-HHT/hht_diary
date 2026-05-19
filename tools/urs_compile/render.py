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
    saw_rationale_remainder = False

    def _is_subgroup(child: GraphNode) -> bool:
        """Bold-paragraph subgroup heading inside the Assertions block.

        elspais parses `**Trigger**` style bold paragraphs (no markdown
        heading marker) as REMAINDERs with `heading` set, `heading_level`
        unset, and empty body text. These are subgroup labels for the
        lettered assertions that follow them.
        """
        if child.kind != "REMAINDER":
            return False
        if child.content.get("heading_level") is not None:
            return False
        if not (child.content.get("heading") or "").strip():
            return False
        if (child.content.get("text") or "").strip():
            return False
        return True

    # Pre-scan to locate where the Assertions block starts. The block
    # begins at the first ASSERTION OR the first subgroup-style REMAINDER
    # (whichever comes first). Source authors put `### Assertions` before
    # `**Trigger**` etc., but elspais flattens that heading away — emit an
    # implicit `#### Assertions` here so subgroup H5s sit under it.
    assertions_start_idx: int | None = None
    for idx, child_id in enumerate(node.children):
        if not graph.has_node(child_id):
            continue
        child = graph.get_node(child_id)
        if child.kind == "ASSERTION" or _is_subgroup(child):
            assertions_start_idx = idx
            break
    emitted_assertions_header = assertions_start_idx is None

    for idx, child_id in enumerate(node.children):
        if not graph.has_node(child_id):
            continue
        child = graph.get_node(child_id)

        if idx == assertions_start_idx and not emitted_assertions_header:
            body_parts.append("\n\n#### Assertions\n")
            emitted_assertions_header = True

        if child.kind == "REMAINDER":
            heading = (child.content.get("heading") or "").strip()
            text = (child.content.get("text") or "").strip()
            heading_level = child.content.get("heading_level")
            heading_lower = heading.lower()
            if heading_lower == "assertions":
                emitted_assertions_header = True
            if heading_lower == "rationale":
                saw_rationale_remainder = True
            if heading:
                # `heading_level == 3` -> source `### Heading` -> emit at H4
                # (one deeper than the REQ's H3 title).
                # `heading_level is None` -> source bold-paragraph subgroup
                # (e.g. `**Trigger**` inside an Assertions block) -> emit at
                # H5 so it sits visually under the `#### Assertions` we
                # injected above, and stays out of the H3-capped TOC.
                prefix = "####" if heading_level == 3 else "#####"
                body_parts.append(f"\n\n{prefix} {heading}\n")
            if text:
                body_parts.append(f"\n{text}\n")

        elif child.kind == "ASSERTION":
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
