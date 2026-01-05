# TODO: Re-implement q_and_a Features with Jinja2

Features from the `q_and_a` branch (CUR-549) that need to be re-implemented
using the new Jinja2 template architecture in `extract-tools`.

## Data Model Changes

### 1. VERSION Constant
- Add `VERSION` constant to `HTMLGenerator` class
- Increment with each change for cache-busting and debugging
- Current version in q_and_a: `VERSION = 9`

### 2. Conflict Detection Fields
Add to `TraceabilityRequirement` dataclass:
```python
is_conflict: bool = False  # True if this roadmap REQ conflicts with an existing REQ
conflict_with: str = ''    # ID of the existing REQ this conflicts with
```

### 3. Cycle Detection Fields
Add to `TraceabilityRequirement` dataclass:
```python
is_cycle: bool = False  # True if this REQ is part of a dependency cycle
cycle_path: str = ''    # The cycle path string for display (e.g., "p00001 -> p00002 -> p00001")
```

## Core Logic

### 4. Pre-detect Dependency Cycles
Implement `_detect_and_mark_cycles()` method:
- DFS traversal to find all cycles reachable from each requirement
- Mark affected requirements with `is_cycle=True`
- Clear `implements` list so they appear as orphaned top-level items
- Print cycle paths for debugging: `🔄 CYCLE DETECTED: REQ-p00001 -> REQ-p00002 -> REQ-p00001`

### 5. Roadmap REQ Conflict Handling
When loading roadmap requirements:
- If REQ ID already exists in main spec, create conflict entry
- Use modified key: `{req_id}__conflict`
- Set `is_conflict=True`, `conflict_with={existing_id}`
- Clear `implements` list to treat as orphaned top-level item
- Print warning: `⚠️ Roadmap REQ-{id} conflicts with existing REQ-{id}`

### 6. Cycle Detection in Tree Traversal
Update tree formatting methods with `ancestor_path` parameter:
- `_format_req_tree_md(req, indent, ancestor_path=[])`
- `_format_req_tree_html(req, ancestor_path=[])`
- `_format_req_tree_html_collapsible(req, ancestor_path=[])`
- `_add_requirement_and_children(req, flat_list, indent, parent_instance_id, ancestor_path, is_orphan=False)`

Check for cycles before recursing:
```python
if req.id in ancestor_path:
    cycle_path = ancestor_path + [req.id]
    cycle_str = " -> ".join([f"REQ-{rid}" for rid in cycle_path])
    # Return cycle indicator instead of recursing
```

### 7. MAX_DEPTH Safety Limit
Add depth limit to prevent infinite recursion:
```python
MAX_DEPTH = 50
if indent > MAX_DEPTH:
    return "⚠️ MAX DEPTH EXCEEDED"
```

## Flat View Improvements

### 8. Show All Requirements Including Orphans
After building tree from root PRD requirements:
- Track visited requirement IDs in `_visited_req_ids`
- Find orphaned requirements: `all_req_ids - _visited_req_ids`
- Add orphans to flat list at indent 0 with `is_orphan=True`

### 9. Sort by REQ ID, Hide Implementation Files
- Sort flat view by REQ ID for consistent ordering
- Option to hide implementation file rows in flat view

## HTML/UI (Jinja2 Templates)

### 10. Conflict/Cycle Icons
Add icons to requirement display:
- Conflict: `<span class="conflict-icon" title="Conflicts with REQ-{id}">⚠️</span>`
- Cycle: `<span class="cycle-icon" title="Cycle: {path}">🔄</span>`

### 11. Conflict/Cycle Data Attributes
Add data attributes to HTML elements for filtering/styling:
```html
data-conflict="true" data-conflict-with="{id}"
data-cycle="true" data-cycle-path="{path}"
```

### 12. Legend Modal Updates
Add new symbols to legend:
- ⚠️ Conflict - Roadmap REQ conflicts with existing REQ
- 🔄 Cycle - Requirement is part of a dependency cycle

### 13. Version Badge in Title Bar
- Display version number left of Legend button
- Format: `v{VERSION}`
- Helps identify which version of the report is being viewed

### 14. Fix Roadmap Spec Path
In `_generate_req_json_data()`:
```python
spec_subpath = 'spec/roadmap' if req.is_roadmap else 'spec'
'filePath': f"{self._base_path}{spec_subpath}/{req.file_path.name}"
```

## Tests

### 15. Cycle Detection Tests
- Test simple A -> B -> A cycle
- Test multi-node cycles
- Test that cycles are marked as orphaned items
- Test MAX_DEPTH limit

### 16. Conflict Detection Tests
- Test loading roadmap REQ that conflicts with existing REQ
- Verify conflict entry has correct key (`{id}__conflict`)
- Verify conflict appears as orphaned item
- Test conflict icons in HTML output

## Files to Modify

- `tools/requirements/trace_view/html/generator.py` - Main generator class
- `tools/requirements/trace_view/html/templates/` - Jinja2 templates
- `tools/requirements/trace_view/html/static/styles.css` - CSS for new classes
- `tools/requirements/trace_view/html/static/scripts.js` - JS for new features
- `tools/requirements/generate_traceability.py` - TraceabilityRequirement dataclass
- `tools/requirements/tests/test_generate_traceability.py` - Tests

## Reference

Original commits from `q_and_a` branch:
- `5348aa3` Add conflict/cycle symbols to legend modal, fix test (v9)
- `94f9321` Pre-detect cycles and treat as orphaned items (v8)
- `2f50681` Make conflict items always visible (v7)
- `0b128ec` Load conflicting roadmap REQs as orphaned items with conflict indicators
- `8babcf3` Fix version badge visibility in title bar (v3)
- `8d7b3d5` Move version badge to left of Legend button (v2)
- `22d86f0` Add version number to traceability report
- `22303b5` Remove duplicate-hiding logic from flat view
- `2167fd0` Sort flat view by REQ ID and hide implementation files
- `44e7fce` Fix flat view to show all unique requirements at indent 0
- `80e5f76` Fix flat view to show all requirements including orphans
- `cc239f5` Add recursion detection to traceability generation script
