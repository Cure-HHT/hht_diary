"""Render GraphNodes to markdown for the URS PDF compile."""

from __future__ import annotations

from pathlib import Path

import jinja2

from .graph_loader import GraphNode


_TEMPLATE_DIR = Path(__file__).parent / "templates"
_env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(_TEMPLATE_DIR),
    autoescape=False,
    trim_blocks=True,
    lstrip_blocks=True,
)


def render_remainder(node: GraphNode) -> str:
    return node.content.get("text", "")


def render_requirement(node: GraphNode) -> str:
    template = _env.get_template("req.md.j2")
    return template.render(node=node).rstrip() + "\n"


def render_node(node: GraphNode) -> str:
    if node.kind == "REMAINDER":
        return render_remainder(node)
    if node.kind == "REQUIREMENT":
        return render_requirement(node)
    raise ValueError(f"Cannot render node kind {node.kind!r}")
