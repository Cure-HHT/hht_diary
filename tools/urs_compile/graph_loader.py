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

    def requirements_for_source_file(self, relpath: str) -> list[GraphNode]:
        """Return REQUIREMENT nodes whose `source_file` matches `relpath`.

        elspais federation merges FILE nodes that share a relative_path
        (only one FILE node survives, biased to one repo). The REQUIREMENT
        nodes themselves carry their own `source_file` field, so when we
        need cross-repo REQ lookups for a section we go through this method
        instead of `files_for_relative_path` -> children.
        """
        return [
            n for n in self._nodes.values()
            if n.kind == "REQUIREMENT" and n.content.get("source_file") == relpath
        ]

    def remainders_for_source_file(self, relpath: str) -> list[GraphNode]:
        """Return REMAINDER nodes attached to FILE nodes for `relpath`.

        REMAINDERs are accessible only via FILE node children today; there
        is no `source_file` on REMAINDER content. Callers that need both
        REQs and REMAINDERs combine this with `files_for_relative_path` to
        get the surviving FILE's REMAINDERs.
        """
        out: list[GraphNode] = []
        for n in self._nodes.values():
            if n.kind != "FILE" or n.content.get("relative_path") != relpath:
                continue
            for cid in n.children:
                child = self._nodes.get(cid)
                if child and child.kind == "REMAINDER":
                    out.append(child)
        return out
