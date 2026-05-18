import pytest

from urs_compile.graph_loader import Graph, GraphNode


def test_load_from_dict(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    assert g.get_node("DIARY-PRD-rbac").kind == "REQUIREMENT"
    assert g.get_node("rem:spec/prd-rbac.md:1").kind == "REMAINDER"


def test_files_for_relative_path_returns_both_repos(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    files = g.files_for_relative_path("spec/prd-rbac.md")
    assert len(files) == 2
    repos = {f.content.get("repo") for f in files}
    assert repos == {None, "callisto"}


def test_iter_children_yields_in_order(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    file_node = g.get_node("file:spec/prd-rbac.md")
    child_ids = [c.id for c in g.iter_children(file_node)]
    assert child_ids == [
        "rem:spec/prd-rbac.md:1",
        "DIARY-PRD-rbac",
        "DIARY-PRD-action-inventory",
        "DIARY-PRD-role-definitions",
        "rem:spec/prd-rbac.md:2",
        "DIARY-GUI-role-switching",
    ]


def test_get_node_missing_raises():
    g = Graph.from_dict({"nodes": {}, "roots": [], "metadata": {}})
    with pytest.raises(KeyError):
        g.get_node("nonexistent")
