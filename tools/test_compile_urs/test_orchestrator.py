import importlib.util
from pathlib import Path


def _load_orchestrator():
    """Load compile-urs.py (which has a hyphen, so it isn't a normal import)."""
    spec_path = Path(__file__).parents[1] / "compile-urs.py"
    spec = importlib.util.spec_from_file_location("compile_urs", spec_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_assemble_markdown_emits_chapter_section_headings_and_content(
    sample_graph_dict, sample_manifest_dict
):
    from urs_compile.graph_loader import Graph
    from urs_compile.manifest import Manifest

    mod = _load_orchestrator()
    graph = Graph.from_dict(sample_graph_dict)
    manifest = Manifest.from_dict(sample_manifest_dict)

    out = mod.assemble_markdown(graph, manifest)

    # Chapter heading
    assert "# 4. SYSTEM-WIDE STANDARDS" in out
    # Section heading
    assert "## 4.3 User Roles and Permissions" in out
    # DIARY content
    assert "Customizable Role-Based Access Control" in out
    # CAL content (interleaved after DIARY pair)
    assert "Role Definitions (Callisto Permissions Table)" in out
    # Order check: DIARY role-definitions comes before CAL role-definitions
    diary_pos = out.find("DIARY-PRD-role-definitions")
    cal_pos = out.find("CAL-PRD-role-definitions")
    assert 0 < diary_pos < cal_pos
