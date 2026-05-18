"""Interleave DIARY + CAL FILE-node children per the URS pair rule."""

from __future__ import annotations

import re
from typing import Iterator

from .graph_loader import Graph, GraphNode


_ID_PREFIX_RE = re.compile(r"^(DIARY|CAL)-(PRD|GUI|OPS|DEV)-", re.IGNORECASE)


def kebab_stripped_name(req_id: str) -> str:
    """Return the namespace-stripped kebab name of a REQ id.

    DIARY-PRD-role-definitions -> role-definitions
    CAL-GUI-foo                -> foo
    """
    return _ID_PREFIX_RE.sub("", req_id, count=1)


def _is_diary(file_node: GraphNode) -> bool:
    return file_node.content.get("repo") in (None, "")


def _split_diary_cal(file_nodes: list[GraphNode]) -> tuple[GraphNode | None, GraphNode | None]:
    diary = next((f for f in file_nodes if _is_diary(f)), None)
    cal = next((f for f in file_nodes if not _is_diary(f)), None)
    return diary, cal


def interleave_section(
    graph: Graph,
    file_nodes: list[GraphNode],
) -> Iterator[tuple[str, GraphNode]]:
    """Yield (emission_kind, node) tuples for a section.

    emission_kind: "diary-rem" | "cal-rem" | "diary-req" | "cal-req" |
                   "trailing-cal-req".
    """
    diary, cal = _split_diary_cal(file_nodes)

    cal_reqs_by_name: dict[str, GraphNode] = {}
    cal_emitted: set[str] = set()

    if cal:
        for child in graph.iter_children(cal):
            if child.kind == "REQUIREMENT":
                cal_reqs_by_name[kebab_stripped_name(child.id)] = child

    # Collect leading CAL REMAINDERs (chapter-intro prose) to emit
    # immediately after the first DIARY REMAINDER.
    leading_cal_remainders: list[GraphNode] = []
    if cal:
        for child in graph.iter_children(cal):
            if child.kind == "REQUIREMENT":
                break
            if child.kind == "REMAINDER":
                leading_cal_remainders.append(child)

    first_diary_remainder_emitted = False
    if diary:
        for child in graph.iter_children(diary):
            if child.kind == "REMAINDER":
                yield ("diary-rem", child)
                if not first_diary_remainder_emitted:
                    first_diary_remainder_emitted = True
                    for cal_rem in leading_cal_remainders:
                        yield ("cal-rem", cal_rem)
            elif child.kind == "REQUIREMENT":
                yield ("diary-req", child)
                key = kebab_stripped_name(child.id)
                if key in cal_reqs_by_name and key not in cal_emitted:
                    yield ("cal-req", cal_reqs_by_name[key])
                    cal_emitted.add(key)

    # Trailing unpaired CAL REQs in CAL source order
    if cal:
        for child in graph.iter_children(cal):
            if child.kind != "REQUIREMENT":
                continue
            key = kebab_stripped_name(child.id)
            if key not in cal_emitted:
                yield ("trailing-cal-req", child)
                cal_emitted.add(key)
