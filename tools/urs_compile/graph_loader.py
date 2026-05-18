"""Load elspais `graph` JSON into a typed Graph object."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True)
class GraphNode:
    id: str
    kind: str
    label: str
    content: dict[str, Any]
    children: tuple[str, ...]
    edges: tuple[dict[str, Any], ...]


class Graph:
    def __init__(self, nodes: dict[str, GraphNode], metadata: dict[str, Any]):
        self._nodes = nodes
        self.metadata = metadata

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Graph":
        nodes: dict[str, GraphNode] = {}
        for node_id, raw in d.get("nodes", {}).items():
            nodes[node_id] = GraphNode(
                id=raw["id"],
                kind=raw["kind"],
                label=raw.get("label", ""),
                content=raw.get("content", {}),
                children=tuple(raw.get("children", [])),
                edges=tuple(raw.get("edges", [])),
            )
        return cls(nodes, d.get("metadata", {}))

    @classmethod
    def from_json_path(cls, path: Path) -> "Graph":
        return cls.from_dict(json.loads(path.read_text()))

    def get_node(self, node_id: str) -> GraphNode:
        return self._nodes[node_id]

    def has_node(self, node_id: str) -> bool:
        return node_id in self._nodes

    def files_for_relative_path(self, relpath: str) -> list[GraphNode]:
        return [
            n for n in self._nodes.values()
            if n.kind == "FILE" and n.content.get("relative_path") == relpath
        ]

    def iter_children(self, file_node: GraphNode) -> Iterable[GraphNode]:
        for cid in file_node.children:
            if cid in self._nodes:
                yield self._nodes[cid]
