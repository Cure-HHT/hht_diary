"""Interleave DIARY + CAL REQs per the URS pair rule."""

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


def _id_namespace(req_id: str) -> str:
    """Return the REQ ID's repo namespace ("DIARY" or "CAL")."""
    m = _ID_PREFIX_RE.match(req_id)
    if not m:
        return "DIARY"
    return m.group(1).upper()


def interleave_section_by_path(
    graph: Graph,
    relpath: str,
) -> Iterator[tuple[str, GraphNode]]:
    """Yield (emission_kind, node) tuples for a section given a spec path.

    Walks the surviving FILE node (whichever repo won the federation
    collision) for REMAINDER ordering, then layers in CAL REQs sourced
    from `source_file == relpath` so that cross-repo siblings appear
    even when federation collapsed the FILE nodes.

    emission_kind: "diary-rem" | "cal-rem" | "diary-req" | "cal-req" |
                   "trailing-cal-req".
    """
    # Bucket every REQ that names `relpath` as source_file, by namespace.
    diary_reqs_in_order: list[GraphNode] = []
    cal_reqs_in_order: list[GraphNode] = []
    for req in graph.requirements_for_source_file(relpath):
        ns = _id_namespace(req.id)
        if ns == "CAL":
            cal_reqs_in_order.append(req)
        else:
            diary_reqs_in_order.append(req)
    # Sort by parse_line for deterministic in-file ordering.
    diary_reqs_in_order.sort(key=lambda n: n.content.get("parse_line") or 0)
    cal_reqs_in_order.sort(key=lambda n: n.content.get("parse_line") or 0)

    # Pre-compute each CAL REQ's anchor DIARY REQ id.
    # Priority: kebab-name match (canonical URS pair signal) > first
    # refines_refs target that is a DIARY REQ in this section. Each CAL
    # REQ pairs at most once, at its canonical anchor.
    diary_ids_in_section: set[str] = {r.id for r in diary_reqs_in_order}
    diary_by_name: dict[str, GraphNode] = {
        kebab_stripped_name(r.id): r for r in diary_reqs_in_order
    }
    cal_by_anchor: dict[str, list[GraphNode]] = {}
    for cal_req in cal_reqs_in_order:
        key = kebab_stripped_name(cal_req.id)
        anchor_id: str | None = None
        if key in diary_by_name:
            anchor_id = diary_by_name[key].id
        else:
            for ref in (cal_req.content.get("refines_refs") or []):
                if ref in diary_ids_in_section:
                    anchor_id = ref
                    break
        if anchor_id is not None:
            cal_by_anchor.setdefault(anchor_id, []).append(cal_req)

    # REMAINDERs: walk the surviving FILE node's children in original order.
    # FILE nodes from federation collisions may point to either repo; using
    # their children order matches the source file's textual ordering.
    file_nodes = graph.files_for_relative_path(relpath)
    # Track emitted CAL REQs by full id (kebab may collide across
    # PRD/GUI siblings — e.g. CAL-PRD-foo and CAL-GUI-foo).
    cal_emitted: set[str] = set()

    def _emit_cal_pair(diary_req: GraphNode) -> Iterator[tuple[str, GraphNode]]:
        """Yield CAL REQs anchored to `diary_req` (precomputed map)."""
        for cal_req in cal_by_anchor.get(diary_req.id, []):
            if cal_req.id in cal_emitted:
                continue
            yield ("cal-req", cal_req)
            cal_emitted.add(cal_req.id)

    if not file_nodes:
        # No surviving FILE node — emit REQs in parse_line order.
        for req in diary_reqs_in_order:
            yield ("diary-req", req)
            yield from _emit_cal_pair(req)
        for req in cal_reqs_in_order:
            if req.id not in cal_emitted:
                yield ("trailing-cal-req", req)
                cal_emitted.add(req.id)
        return

    file_node = file_nodes[0]
    surviving_is_cal = (
        "hht_diary_callisto" in (file_node.content.get("absolute_path") or "")
    )

    ordered_children: list[GraphNode] = list(graph.iter_children(file_node))
    diary_reqs_by_id: dict[str, GraphNode] = {r.id: r for r in diary_reqs_in_order}
    # Reverse-index: each CAL id -> its precomputed anchor (or None).
    cal_anchor_by_id: dict[str, str] = {
        cal.id: anchor
        for anchor, cals in cal_by_anchor.items()
        for cal in cals
    }

    seen_diary_ids: set[str] = set()
    for child in ordered_children:
        if child.kind == "REMAINDER":
            kind = "cal-rem" if surviving_is_cal else "diary-rem"
            yield (kind, child)
        elif child.kind == "REQUIREMENT":
            ns = _id_namespace(child.id)
            if ns == "DIARY":
                yield ("diary-req", child)
                seen_diary_ids.add(child.id)
                yield from _emit_cal_pair(child)
            elif ns == "CAL":
                # Surviving FILE was CAL: emit its REQs in source order,
                # prepending the precomputed anchor DIARY REQ if unseen
                # (kebab match wins over refines target).
                anchor_id = cal_anchor_by_id.get(child.id)
                paired_diary = (
                    diary_reqs_by_id.get(anchor_id) if anchor_id else None
                )
                if paired_diary and paired_diary.id not in seen_diary_ids:
                    yield ("diary-req", paired_diary)
                    seen_diary_ids.add(paired_diary.id)
                if child.id not in cal_emitted:
                    yield ("cal-req", child)
                    cal_emitted.add(child.id)

    # Catch any DIARY REQs whose FILE walk didn't surface them (defensive).
    for req in diary_reqs_in_order:
        if req.id in seen_diary_ids:
            continue
        yield ("diary-req", req)
        seen_diary_ids.add(req.id)
        yield from _emit_cal_pair(req)

    # Trailing CAL REQs: anything not already emitted, in parse_line order.
    for req in cal_reqs_in_order:
        if req.id in cal_emitted:
            continue
        yield ("trailing-cal-req", req)
        cal_emitted.add(req.id)


# Backwards-compatible wrapper for existing callers that pass FILE nodes.
def interleave_section(
    graph: Graph,
    file_nodes: list[GraphNode],
) -> Iterator[tuple[str, GraphNode]]:
    """Legacy entry point — delegates to `interleave_section_by_path`."""
    if not file_nodes:
        return iter(())
    relpath = file_nodes[0].content.get("relative_path") or ""
    return interleave_section_by_path(graph, relpath)
