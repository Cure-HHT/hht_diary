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


def _collect_req_children(node: GraphNode, graph: Graph) -> tuple[list[GraphNode], list[GraphNode]]:
    """Return (remainder_children, assertion_children) for a REQUIREMENT node.

    Walks `node.children` in declaration order and partitions by kind. The
    children carry the original source-file order, so REMAINDERs appear in
    the order they were authored (Overview, Definitions, Examples, etc.).
    """
    remainders: list[GraphNode] = []
    assertions: list[GraphNode] = []
    for child_id in node.children:
        if not graph.has_node(child_id):
            continue
        child = graph.get_node(child_id)
        if child.kind == "REMAINDER":
            remainders.append(child)
        elif child.kind == "ASSERTION":
            assertions.append(child)
    return remainders, assertions


def render_requirement(node: GraphNode, graph: Graph) -> str:
    """Render a REQUIREMENT node to markdown.

    Output layout:
      ### Title  {#req-id}
      **REQ ID:** `req-id`
      **Refines:** `...`
      #### <Remainder heading>     (one block per REMAINDER child, in order)
      <text>
      #### Rationale               (only if content.rationale present)
      <rationale>
      #### Assertions              (only if any ASSERTION children)
      **A.** <text>
      **B.** <text>
    """
    # Header (heading + REQ ID + Refines/Satisfies edges) — Jinja handles these.
    template = _env.get_template("req.md.j2")
    header = template.render(node=node).rstrip()

    remainders, assertions = _collect_req_children(node, graph)

    body_parts: list[str] = [header]

    # REMAINDER sub-sections (Overview, Definitions, Examples, ...) appear
    # in source order. Elspais surfaces the body Rationale section BOTH as
    # a REMAINDER child (heading "Rationale") AND as `content.rationale`;
    # render only the REMAINDER side when present to avoid duplication.
    has_rationale_section = any(
        (r.content.get("heading") or "").strip().lower() == "rationale"
        for r in remainders
    )
    for rem in remainders:
        heading = rem.content.get("heading") or rem.label or ""
        text = rem.content.get("text") or ""
        if heading:
            body_parts.append(f"\n\n#### {heading}\n")
        if text:
            body_parts.append(f"\n{text}\n")

    if not has_rationale_section:
        rationale = (node.content.get("rationale") or "").strip()
        if rationale:
            body_parts.append("\n\n#### Rationale\n")
            body_parts.append(f"\n{rationale}\n")

    if assertions:
        body_parts.append("\n\n#### Assertions\n\n")
        for a in assertions:
            label = a.content.get("label") or "?"
            text = (a.label or "").strip()
            body_parts.append(f"**{label}.** {text}\n\n")

    return "".join(body_parts).rstrip() + "\n"


def render_node(node: GraphNode, graph: Graph | None = None) -> str:
    if node.kind == "REMAINDER":
        return render_remainder(node)
    if node.kind == "REQUIREMENT":
        if graph is None:
            raise ValueError("render_node requires a Graph for REQUIREMENT nodes")
        return render_requirement(node, graph)
    raise ValueError(f"Cannot render node kind {node.kind!r}")
