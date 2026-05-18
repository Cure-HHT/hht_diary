import json
from pathlib import Path

import pytest
import yaml

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def sample_graph_dict():
    return json.loads((FIXTURES / "sample-graph.json").read_text())


@pytest.fixture
def sample_manifest_dict():
    return yaml.safe_load((FIXTURES / "sample-manifest.yaml").read_text())
