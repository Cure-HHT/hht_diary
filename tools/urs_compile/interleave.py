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
    # Two indices for pairing CAL -> DIARY:
    #   - by_name: kebab-stripped name match (e.g. role-definitions)
    #   - by_refines: CAL's refines_refs target id
    diary_reqs_in_order: list[GraphNode] = []
    cal_reqs_by_name: dict[str, list[GraphNode]] = {}
    cal_reqs_by_refines: dict[str, list[GraphNode]] = {}
    cal_reqs_in_order: list[GraphNode] = []
    for req in graph.requirements_for_source_file(relpath):
        ns = _id_namespace(req.id)
        if ns == "CAL":
            cal_reqs_by_name.setdefault(kebab_stripped_name(req.id), []).append(req)
            for ref in (req.content.get("refines_refs") or []):
                cal_reqs_by_refines.setdefault(ref, []).append(req)
            cal_reqs_in_order.append(req)
        else:
            diary_reqs_in_order.append(req)
    # Sort by parse_line for deterministic in-file ordering.
    diary_reqs_in_order.sort(key=lambda n: n.content.get("parse_line") or 0)
    cal_reqs_in_order.sort(key=lambda n: n.content.get("parse_line") or 0)

    # REMAINDERs: walk the surviving FILE node's children in original order.
    # FILE nodes from federation collisions may point to either repo; using
    # their children order matches the source file's textual ordering.
    file_nodes = graph.files_for_relative_path(relpath)
    # Track emitted CAL REQs by full id (kebab may collide across
    # PRD/GUI siblings — e.g. CAL-PRD-foo and CAL-GUI-foo).
    cal_emitted: set[str] = set()

    def _emit_cal_pair(diary_req: GraphNode) -> Iterator[tuple[str, GraphNode]]:
        """Yield CAL siblings paired with `diary_req` (REFINES > kebab name)."""
        candidates: list[GraphNode] = list(cal_reqs_by_refines.get(diary_req.id, []))
        key = kebab_stripped_name(diary_req.id)
        for cand in cal_reqs_by_name.get(key, []):
            if cand not in candidates:
                candidates.append(cand)
        for cal_req in candidates:
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
                # prepending the DIARY refines target if present and unseen.
                refines = child.content.get("refines_refs") or []
                paired_diary = next(
                    (diary_reqs_by_id[r] for r in refines if r in diary_reqs_by_id),
                    None,
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
