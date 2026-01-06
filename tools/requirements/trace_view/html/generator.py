"""
HTML Generator for trace-view.

This module contains all HTML, CSS, and JavaScript generation for the
interactive traceability matrix report. It was extracted from the original
generate_traceability.py as a monolithic module to support the trace_view
package refactoring.

Contains:
- HTMLGenerator class with all HTML rendering methods
- CSS styles for the interactive report
- JavaScript for interactivity (expand/collapse, side panel, code viewer)
- Modal dialogs (legend, file picker)
- Edit mode functionality
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set

from jinja2 import Environment, FileSystemLoader, select_autoescape

from ..models import Requirement
from ..coverage import count_by_level, find_orphaned_requirements, calculate_coverage, get_implementation_status


class HTMLGenerator:
    """Generates interactive HTML traceability matrix.

    This class contains all the HTML, CSS, and JavaScript generation logic
    for the trace-view interactive report.

    Args:
        requirements: Dict mapping requirement ID to Requirement object
        base_path: Relative path from output file to repo root (for links)
        mode: Report mode ('core', 'sponsor', 'combined')
        sponsor: Sponsor name if in sponsor mode
        version: Version number for display
        repo_root: Repository root path for absolute links
    """

    def __init__(
        self,
        requirements: Dict[str, Requirement],
        base_path: str = '',
        mode: str = 'core',
        sponsor: Optional[str] = None,
        version: int = 16,
        repo_root: Optional[Path] = None
    ):
        self.requirements = requirements
        self._base_path = base_path
        self.mode = mode
        self.sponsor = sponsor
        self.VERSION = version
        self.repo_root = repo_root
        # Instance tracking for flat list building
        self._instance_counter = 0
        self._visited_req_ids: Set[str] = set()

        # Jinja2 template environment
        template_dir = Path(__file__).parent / "templates"
        self.env = Environment(
            loader=FileSystemLoader(template_dir),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )

        # Register custom filters for templates
        self.env.filters['status_class'] = lambda s: s.lower() if s else ''
        self.env.filters['level_class'] = lambda s: s.lower() if s else ''

    def generate(
        self,
        embed_content: bool = False,
        edit_mode: bool = False,
        review_mode: bool = False
    ) -> str:
        """Generate the complete HTML report using Jinja2 templates.

        Args:
            embed_content: If True, embed full requirement content as JSON
            edit_mode: If True, include edit mode UI elements
            review_mode: If True, include review mode UI and scripts

        Returns:
            Complete HTML document as string

        Raises:
            jinja2.TemplateError: If template rendering fails
        """
        context = self._build_render_context(embed_content, edit_mode, review_mode)
        template = self.env.get_template('base.html')
        return template.render(**context)

    def _count_by_level(self) -> Dict[str, Dict[str, int]]:
        """Count requirements by level, with and without deprecated."""
        return count_by_level(self.requirements)

    def _find_orphaned_requirements(self) -> List[Requirement]:
        """Find requirements with missing parents."""
        return find_orphaned_requirements(self.requirements)

    def _calculate_coverage(self, req_id: str) -> dict:
        """Calculate coverage for a requirement."""
        return calculate_coverage(self.requirements, req_id)

    def _get_implementation_status(self, req_id: str) -> str:
        """Get implementation status for a requirement."""
        return get_implementation_status(self.requirements, req_id)

    def _load_css(self) -> str:
        """Load CSS content from external stylesheet.

        Loads styles from templates/partials/styles.css for embedding
        in the HTML output.

        Returns:
            CSS content as string, or empty string if file not found.
        """
        css_path = Path(__file__).parent / "templates" / "partials" / "styles.css"
        if css_path.exists():
            return css_path.read_text()
        return ""

    def _load_js(self) -> str:
        """Load JavaScript content from external script file.

        Loads scripts from templates/partials/scripts.js for embedding
        in the HTML output.

        Returns:
            JavaScript content as string, or empty string if file not found.
        """
        js_path = Path(__file__).parent / "templates" / "partials" / "scripts.js"
        if js_path.exists():
            return js_path.read_text()
        return ""

    def _load_review_css(self) -> str:
        """Load review system CSS.

        Returns:
            CSS content as string, or empty string if file not found.
        """
        css_path = Path(__file__).parent / "templates" / "partials" / "review-styles.css"
        if css_path.exists():
            return css_path.read_text()
        return ""

    def _load_review_js(self) -> str:
        """Load review system JavaScript modules.

        Concatenates all review JS modules in the correct dependency order.

        Returns:
            JavaScript content as string, or empty string if files not found.
        """
        review_dir = Path(__file__).parent / "templates" / "partials" / "review"
        if not review_dir.exists():
            return ""

        # Load modules in dependency order
        module_order = [
            "review-data.js",      # Data models and state (no deps)
            "review-position.js",  # Position resolution (depends on data)
            "review-sync.js",      # Sync operations (depends on data)
            "review-packages.js",  # Package management (depends on sync)
            "review-comments.js",  # Comments UI (depends on position, sync)
            "review-status.js",    # Status UI (depends on sync)
            "review-help.js",      # Help system (depends on data)
        ]

        js_parts = []
        for module_name in module_order:
            module_path = review_dir / module_name
            if module_path.exists():
                js_parts.append(f"// === {module_name} ===")
                js_parts.append(module_path.read_text())

        return "\n".join(js_parts)

    def _build_render_context(
        self,
        embed_content: bool = False,
        edit_mode: bool = False,
        review_mode: bool = False
    ) -> dict:
        """Build the template render context.

        Creates a dictionary with all data needed by Jinja2 templates.

        Args:
            embed_content: If True, embed full requirement content
            edit_mode: If True, include edit mode UI
            review_mode: If True, include review mode UI and scripts

        Returns:
            Dictionary containing template context variables
        """
        by_level = self._count_by_level()

        # Collect topics
        all_topics = set()
        for req in self.requirements.values():
            topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem
            all_topics.add(topic)
        sorted_topics = sorted(all_topics)

        # Build requirements HTML using existing method
        requirements_html = self._generate_requirements_html(embed_content, edit_mode)

        # Build JSON data for embedded mode
        req_json_data = ""
        if embed_content:
            req_json_data = self._generate_req_json_data()

        return {
            # Configuration flags
            'embed_content': embed_content,
            'edit_mode': edit_mode,
            'review_mode': review_mode,
            'version': self.VERSION,

            # Statistics
            'stats': {
                'prd': {
                    'active': by_level['active']['PRD'],
                    'all': by_level['all']['PRD']
                },
                'ops': {
                    'active': by_level['active']['OPS'],
                    'all': by_level['all']['OPS']
                },
                'dev': {
                    'active': by_level['active']['DEV'],
                    'all': by_level['all']['DEV']
                }
            },

            # Requirements data
            'topics': sorted_topics,
            'requirements_html': requirements_html,
            'req_json_data': req_json_data,

            # Asset content (CSS/JS loaded from external files)
            'css': self._load_css(),
            'js': self._load_js(),

            # Review mode assets (loaded conditionally)
            'review_css': self._load_review_css() if review_mode else '',
            'review_js': self._load_review_js() if review_mode else '',

            # Metadata
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M'),
            'repo_root': str(self.repo_root) if self.repo_root else '',
        }

    def _generate_requirements_html(
        self,
        embed_content: bool = False,
        edit_mode: bool = False
    ) -> str:
        """Generate the HTML for all requirements.

        This extracts the requirement tree generation logic to be used
        by both the legacy _generate_html() method and the template-based
        rendering.

        Args:
            embed_content: If True, embed full requirement content
            edit_mode: If True, include edit mode UI

        Returns:
            HTML string with all requirement rows
        """
        # Build flat list for rendering
        flat_list = self._build_flat_requirement_list()

        html_parts = []
        for item_data in flat_list:
            html_parts.append(
                self._format_item_flat_html(
                    item_data,
                    embed_content=embed_content,
                    edit_mode=edit_mode
                )
            )

        return '\n'.join(html_parts)

    def _generate_legend_html(self) -> str:
        """Generate HTML legend section"""
        return """
        <div style="background: #f8f9fa; padding: 15px; border-radius: 4px; margin: 20px 0;">
            <h2 style="margin-top: 0;">Legend</h2>
            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 15px;">
                <div>
                    <h3 style="font-size: 13px; margin-bottom: 8px;">Requirement Status:</h3>
                    <ul style="list-style: none; padding: 0; font-size: 12px;">
                        <li style="margin: 4px 0;">✅ Active requirement</li>
                        <li style="margin: 4px 0;">🚧 Draft requirement</li>
                        <li style="margin: 4px 0;">⚠️ Deprecated requirement</li>
                        <li style="margin: 4px 0;"><span style="color: #28a745; font-weight: bold;">+</span> NEW (in untracked file)</li>
                        <li style="margin: 4px 0;"><span style="color: #fd7e14; font-weight: bold;">*</span> MODIFIED (content changed)</li>
                        <li style="margin: 4px 0;">🗺️ Roadmap (spec/roadmap/) - hidden by default</li>
                    </ul>
                </div>
                <div>
                    <h3 style="font-size: 13px; margin-bottom: 8px;">Traceability:</h3>
                    <ul style="list-style: none; padding: 0; font-size: 12px;">
                        <li style="margin: 4px 0;">🔗 Has implementation file(s)</li>
                        <li style="margin: 4px 0;">○ No implementation found</li>
                    </ul>
                </div>
                <div>
                    <h3 style="font-size: 13px; margin-bottom: 8px;">Implementation Coverage:</h3>
                    <ul style="list-style: none; padding: 0; font-size: 12px;">
                        <li style="margin: 4px 0;">● Full coverage</li>
                        <li style="margin: 4px 0;">◐ Partial coverage</li>
                        <li style="margin: 4px 0;">○ Unimplemented</li>
                    </ul>
                </div>
            </div>
            <div style="margin-top: 10px;">
                <h3 style="font-size: 13px; margin-bottom: 8px;">Interactive Controls:</h3>
                <ul style="list-style: none; padding: 0; font-size: 12px;">
                    <li style="margin: 4px 0;">▼ Expandable (has child requirements)</li>
                    <li style="margin: 4px 0;">▶ Collapsed (click to expand)</li>
                </ul>
            </div>
        </div>
"""

    def _generate_req_json_data(self) -> str:
        """Generate JSON data containing all requirement content for embedded mode"""
        req_data = {}
        for req_id, req in self.requirements.items():
            # Use correct spec subdirectory for roadmap items
            spec_subpath = 'spec/roadmap' if req.is_roadmap else 'spec'
            req_data[req_id] = {
                'title': req.title,
                'status': req.status,
                'level': req.level,
                'body': req.body.strip(),
                'rationale': req.rationale.strip(),
                'file': req.file_path.name,
                'filePath': f"{self._base_path}{spec_subpath}/{req.file_path.name}",
                'line': req.line_number,
                'implements': list(req.implements) if req.implements else [],
                'isRoadmap': req.is_roadmap,
                'isConflict': req.is_conflict,
                'conflictWith': req.conflict_with if req.is_conflict else None,
                'isCycle': req.is_cycle,
                'cyclePath': req.cycle_path if req.is_cycle else None
            }
        json_str = json.dumps(req_data, indent=2)
        # Escape </script> to prevent premature closing of the script tag
        # This is safe because JSON strings already escape the backslash
        json_str = json_str.replace('</script>', '<\\/script>')
        return json_str

    def _build_flat_requirement_list(self) -> List[dict]:
        """Build a flat list of requirements with hierarchy information"""
        flat_list = []
        self._instance_counter = 0  # Track unique instance IDs
        self._visited_req_ids = set()  # Track visited requirements to avoid cycles and duplicates

        # Start with all root requirements (those with no implements/parent)
        # Root requirements can be PRD, OPS, or DEV - any req that doesn't implement another
        root_reqs = [req for req in self.requirements.values() if not req.implements]
        root_reqs.sort(key=lambda r: r.id)

        for root_req in root_reqs:
            self._add_requirement_and_children(root_req, flat_list, indent=0, parent_instance_id='', ancestor_path=[])

        # Add any orphaned requirements that weren't included in the tree
        # (requirements that have implements pointing to non-existent parents)
        all_req_ids = set(self.requirements.keys())
        included_req_ids = self._visited_req_ids
        orphaned_ids = all_req_ids - included_req_ids

        if orphaned_ids:
            orphaned_reqs = [self.requirements[rid] for rid in orphaned_ids]
            orphaned_reqs.sort(key=lambda r: r.id)
            for orphan in orphaned_reqs:
                self._add_requirement_and_children(orphan, flat_list, indent=0, parent_instance_id='', ancestor_path=[], is_orphan=True)

        return flat_list

    def _add_requirement_and_children(self, req: Requirement, flat_list: List[dict], indent: int, parent_instance_id: str, ancestor_path: list[str], is_orphan: bool = False):
        """Recursively add requirement and its children to flat list

        Args:
            req: The requirement to add
            flat_list: List to append items to
            indent: Current indentation level
            parent_instance_id: Instance ID of parent item
            ancestor_path: List of requirement IDs in current traversal path (for cycle detection)
            is_orphan: Whether this requirement is an orphan (has missing parent)
        """
        # Cycle detection: check if this requirement is already in our traversal path
        if req.id in ancestor_path:
            cycle_path = ancestor_path + [req.id]
            cycle_str = " -> ".join([f"REQ-{rid}" for rid in cycle_path])
            print(f"⚠️  CYCLE DETECTED in flat list build: {cycle_str}", file=sys.stderr)
            return  # Don't add cyclic requirement again

        # Track that we've visited this requirement
        self._visited_req_ids.add(req.id)

        # Generate unique instance ID for this occurrence
        instance_id = f"inst_{self._instance_counter}"
        self._instance_counter += 1

        # Find child requirements
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        # Check if this requirement has children (either child reqs or implementation files)
        has_children = len(children) > 0 or len(req.implementation_files) > 0

        # Add this requirement
        flat_list.append({
            'req': req,
            'indent': indent,
            'instance_id': instance_id,
            'parent_instance_id': parent_instance_id,
            'has_children': has_children,
            'item_type': 'requirement'
        })

        # Add implementation files as child items
        for file_path, line_num in req.implementation_files:
            impl_instance_id = f"inst_{self._instance_counter}"
            self._instance_counter += 1
            flat_list.append({
                'file_path': file_path,
                'line_num': line_num,
                'indent': indent + 1,
                'instance_id': impl_instance_id,
                'parent_instance_id': instance_id,
                'has_children': False,
                'item_type': 'implementation'
            })

        # Recursively add child requirements (with updated ancestor path for cycle detection)
        current_path = ancestor_path + [req.id]
        for child in children:
            self._add_requirement_and_children(child, flat_list, indent + 1, instance_id, current_path)

    def _format_item_flat_html(self, item_data: dict, embed_content: bool = False, edit_mode: bool = False) -> str:
        """Format a single item (requirement or implementation file) as flat HTML row

        Args:
            item_data: Dictionary containing item data
            embed_content: If True, use onclick handlers instead of href links for portability
            edit_mode: If True, include edit mode UI elements
        """
        item_type = item_data.get('item_type', 'requirement')

        if item_type == 'implementation':
            return self._format_impl_file_html(item_data, embed_content, edit_mode)
        else:
            return self._format_req_html(item_data, embed_content, edit_mode)

    def _format_impl_file_html(self, item_data: dict, embed_content: bool = False, edit_mode: bool = False) -> str:
        """Format an implementation file as a child row"""
        file_path = item_data['file_path']
        line_num = item_data['line_num']
        indent = item_data['indent']
        instance_id = item_data['instance_id']
        parent_instance_id = item_data['parent_instance_id']

        # Create link or onclick handler
        if embed_content:
            file_url = f"{self._base_path}{file_path}"
            file_link = f'<a href="#" onclick="openCodeViewer(\'{file_url}\', {line_num}); return false;" style="color: #0066cc;">{file_path}:{line_num}</a>'
        else:
            link = f"{self._base_path}{file_path}#L{line_num}"
            file_link = f'<a href="{link}" style="color: #0066cc;">{file_path}:{line_num}</a>'

        # Add VS Code link for opening in editor (always uses vscode:// protocol)
        # Note: VS Code links only work on the machine where this file was generated
        abs_file_path = self.repo_root / file_path
        vscode_url = f"vscode://file/{abs_file_path}:{line_num}"
        vscode_link = f'<a href="{vscode_url}" title="Open in VS Code" class="vscode-link">🔧</a>'
        file_link = f'{file_link}{vscode_link}'

        # Edit mode destination column (only if edit mode enabled)
        edit_column = '<div class="req-destination edit-mode-column"></div>' if edit_mode else ''

        # Build HTML for implementation file row
        html = f"""
        <div class="req-item impl-file" data-instance-id="{instance_id}" data-indent="{indent}" data-parent-instance-id="{parent_instance_id}">
            <div class="req-header-container">
                <span class="collapse-icon"></span>
                <div class="req-content">
                    <div class="req-id" style="color: #6c757d;">📄</div>
                    <div class="req-header" style="font-family: 'Consolas', 'Monaco', monospace; font-size: 12px;">{file_link}</div>
                    <div class="req-level"></div>
                    <div class="req-badges"></div>
                    <div class="req-coverage"></div>
                    <div class="req-status"></div>
                    <div class="req-location"></div>
                    {edit_column}
                </div>
            </div>
        </div>
"""
        return html

    def _format_req_html(self, req_data: dict, embed_content: bool = False, edit_mode: bool = False) -> str:
        """Format a single requirement as flat HTML row

        Args:
            req_data: Dictionary containing requirement data
            embed_content: If True, use onclick handlers instead of href links for portability
            edit_mode: If True, include edit mode UI elements
        """
        req = req_data['req']
        indent = req_data['indent']
        instance_id = req_data['instance_id']
        parent_instance_id = req_data['parent_instance_id']
        has_children = req_data['has_children']

        status_class = req.status.lower()
        level_class = req.level.lower()

        # Only show collapse icon if there are children
        collapse_icon = '▼' if has_children else ''

        # Determine implementation coverage status
        impl_status = self._get_implementation_status(req.id)
        if impl_status == 'Full':
            coverage_icon = '●'  # Filled circle
            coverage_title = 'Full implementation coverage'
        elif impl_status == 'Partial':
            coverage_icon = '◐'  # Half-filled circle
            coverage_title = 'Partial implementation coverage'
        else:  # Unimplemented
            coverage_icon = '○'  # Empty circle
            coverage_title = 'Unimplemented'

        # Determine test status
        test_badge = ''
        if req.test_info:
            test_status = req.test_info.test_status
            test_count = req.test_info.test_count + req.test_info.manual_test_count

            if test_status == 'passed':
                test_badge = f'<span class="test-badge test-passed" title="{test_count} tests passed">✅ {test_count}</span>'
            elif test_status == 'failed':
                test_badge = f'<span class="test-badge test-failed" title="{test_count} tests, some failed">❌ {test_count}</span>'
            elif test_status == 'not_tested':
                test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'
        else:
            test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'

        # Extract topic from filename
        topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem

        # Create link to source file with REQ anchor
        # In embedded mode, use onclick to open side panel instead of navigating away
        # event.stopPropagation() prevents the parent toggle handler from firing
        # Display ID without "REQ-" prefix for cleaner tree view
        # Determine the correct spec path (spec/ or spec/roadmap/)
        spec_subpath = 'spec/roadmap' if req.is_roadmap else 'spec'
        spec_rel_path = f'{spec_subpath}/{req.file_path.name}'

        # Display filename without .md extension and without line number
        display_filename = req.file_path.stem  # removes .md extension

        if embed_content:
            req_link = f'<a href="#" onclick="event.stopPropagation(); openReqPanel(\'{req.id}\'); return false;" style="color: inherit; text-decoration: none; cursor: pointer;">{req.id}</a>'
            file_line_link = f'<span style="color: inherit;">{display_filename}</span>'
        else:
            req_link = f'<a href="{self._base_path}{spec_rel_path}#REQ-{req.id}" style="color: inherit; text-decoration: none;">{req.id}</a>'
            file_line_link = f'<a href="{self._base_path}{spec_rel_path}#L{req.line_number}" style="color: inherit; text-decoration: none;">{display_filename}</a>'

        # Determine status indicators using distinctive Unicode symbols
        # ★ (star) = NEW, ◆ (diamond) = MODIFIED, ↝ (wave arrow) = MOVED
        status_suffix = ''
        status_suffix_class = ''
        status_title = ''

        is_moved = req.is_moved
        is_new_not_moved = req.is_new and not is_moved
        is_modified = req.is_modified

        if is_moved and is_modified:
            # Moved AND modified - show both indicators
            status_suffix = '↝◆'
            status_suffix_class = 'status-moved-modified'
            status_title = 'MOVED and MODIFIED'
        elif is_moved:
            # Just moved (might be in new file)
            status_suffix = '↝'
            status_suffix_class = 'status-moved'
            status_title = 'MOVED from another file'
        elif is_new_not_moved:
            # Truly new (in new file, not moved)
            status_suffix = '★'
            status_suffix_class = 'status-new'
            status_title = 'NEW requirement'
        elif is_modified:
            # Modified in place
            status_suffix = '◆'
            status_suffix_class = 'status-modified'
            status_title = 'MODIFIED content'

        # VS Code link for use in side panel (not in topic column)
        abs_spec_path = self.repo_root / spec_subpath / req.file_path.name
        vscode_url = f"vscode://file/{abs_spec_path}:{req.line_number}"

        # Check if this is a root requirement (no parents)
        is_root = not req.implements or len(req.implements) == 0
        is_root_attr = 'data-is-root="true"' if is_root else 'data-is-root="false"'
        # Two separate modified attributes: uncommitted (since last commit) and branch (vs main)
        uncommitted_attr = 'data-uncommitted="true"' if req.is_uncommitted else 'data-uncommitted="false"'
        branch_attr = 'data-branch-changed="true"' if req.is_branch_changed else 'data-branch-changed="false"'

        # Data attribute for has-children (for leaf-only filtering)
        has_children_attr = 'data-has-children="true"' if has_children else 'data-has-children="false"'

        # Data attribute for test status (for test filter)
        test_status_value = 'not-tested'
        if req.test_info:
            if req.test_info.test_status == 'passed':
                test_status_value = 'tested'
            elif req.test_info.test_status == 'failed':
                test_status_value = 'failed'
        test_status_attr = f'data-test-status="{test_status_value}"'

        # Data attribute for coverage (for coverage filter)
        coverage_value = 'none'
        if impl_status == 'Full':
            coverage_value = 'full'
        elif impl_status == 'Partial':
            coverage_value = 'partial'
        coverage_attr = f'data-coverage="{coverage_value}"'

        # Data attribute for roadmap (for roadmap filtering)
        roadmap_attr = 'data-roadmap="true"' if req.is_roadmap else 'data-roadmap="false"'

        # Edit mode buttons - only generated if edit_mode is enabled
        if edit_mode:
            if req.is_roadmap:
                edit_buttons = f'''<span class="edit-actions" onclick="event.stopPropagation();">
                    <button class="edit-btn from-roadmap" onclick="addPendingMove('{req.id}', '{req.file_path.name}', 'from-roadmap')" title="Move out of roadmap">↩ From Roadmap</button>
                    <button class="edit-btn move-file" onclick="showMoveToFile('{req.id}', '{req.file_path.name}')" title="Move to different file">📁 Move</button>
                </span>'''
            else:
                edit_buttons = f'''<span class="edit-actions" onclick="event.stopPropagation();">
                    <button class="edit-btn to-roadmap" onclick="addPendingMove('{req.id}', '{req.file_path.name}', 'to-roadmap')" title="Move to roadmap">🗺️ To Roadmap</button>
                    <button class="edit-btn move-file" onclick="showMoveToFile('{req.id}', '{req.file_path.name}')" title="Move to different file">📁 Move</button>
                </span>'''
        else:
            edit_buttons = ''

        # Roadmap indicator icon (shown after REQ ID)
        roadmap_icon = '<span class="roadmap-icon" title="In roadmap">🛤️</span>' if req.is_roadmap else ''

        # Conflict indicator icon (shown for roadmap REQs that conflict with existing REQs)
        conflict_icon = f'<span class="conflict-icon" title="Conflicts with REQ-{req.conflict_with}">⚠️</span>' if req.is_conflict else ''
        conflict_attr = f'data-conflict="true" data-conflict-with="{req.conflict_with}"' if req.is_conflict else 'data-conflict="false"'

        # Cycle indicator icon (shown for REQs involved in dependency cycles)
        cycle_icon = f'<span class="cycle-icon" title="Cycle: {req.cycle_path}">🔄</span>' if req.is_cycle else ''
        cycle_attr = f'data-cycle="true" data-cycle-path="{req.cycle_path}"' if req.is_cycle else 'data-cycle="false"'

        # Determine item class based on status
        item_class = 'conflict-item' if req.is_conflict else ('cycle-item' if req.is_cycle else '')

        # Build HTML for single flat row with unique instance ID
        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''} {item_class}" data-req-id="{req.id}" data-instance-id="{instance_id}" data-level="{req.level}" data-indent="{indent}" data-parent-instance-id="{parent_instance_id}" data-topic="{topic}" data-status="{req.status}" data-title="{req.title.lower()}" data-file="{req.file_path.name}" {is_root_attr} {uncommitted_attr} {branch_attr} {has_children_attr} {test_status_attr} {coverage_attr} {roadmap_attr} {conflict_attr} {cycle_attr}>
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-id">{conflict_icon}{cycle_icon}{req_link}{roadmap_icon}</div>
                    <div class="req-header">{req.title}</div>
                    <div class="req-level">{req.level}</div>
                    <div class="req-badges">
                        <span class="status-badge status-{status_class}">{req.status}</span><span class="status-suffix {status_suffix_class}" title="{status_title}">{status_suffix}</span>
                    </div>
                    <div class="req-coverage" title="{coverage_title}">{coverage_icon}</div>
                    <div class="req-status">{test_badge}</div>
                    <div class="req-location">{file_line_link}</div>
                    {'<div class="req-destination edit-mode-column" data-req-id="' + req.id + '">' + edit_buttons + '<span class="dest-text"></span></div>' if edit_mode else ''}
                </div>
            </div>
        </div>
"""
        return html

    def _format_req_tree_html(self, req: Requirement, ancestor_path: list[str] | None = None) -> str:
        """Format requirement and children as HTML tree (legacy non-collapsible).

        Args:
            req: The requirement to format
            ancestor_path: List of requirement IDs in the current traversal path (for cycle detection)

        Returns:
            Formatted HTML string
        """
        if ancestor_path is None:
            ancestor_path = []

        # Cycle detection: check if this requirement is already in our traversal path
        if req.id in ancestor_path:
            cycle_path = ancestor_path + [req.id]
            cycle_str = " -> ".join([f"REQ-{rid}" for rid in cycle_path])
            print(f"⚠️  CYCLE DETECTED: {cycle_str}", file=sys.stderr)
            return f'        <div class="req-item cycle-detected"><strong>⚠️ CYCLE DETECTED:</strong> REQ-{req.id} (path: {cycle_str})</div>\n'

        # Safety depth limit
        MAX_DEPTH = 50
        if len(ancestor_path) > MAX_DEPTH:
            print(f"⚠️  MAX DEPTH ({MAX_DEPTH}) exceeded at REQ-{req.id}", file=sys.stderr)
            return f'        <div class="req-item depth-exceeded"><strong>⚠️ MAX DEPTH EXCEEDED:</strong> REQ-{req.id}</div>\n'

        status_class = req.status.lower()
        level_class = req.level.lower()

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}">
            <div class="req-header">
                {req.id}: {req.title}
            </div>
            <div class="req-meta">
                <span class="status-badge status-{status_class}">{req.status}</span>
                Level: {req.level} |
                File: {req.file_path.name}:{req.line_number}
            </div>
"""

        # Find children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        if children:
            # Add current req to path before recursing into children
            current_path = ancestor_path + [req.id]
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html(child, current_path)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

    def _format_req_tree_html_collapsible(self, req: Requirement, ancestor_path: list[str] | None = None) -> str:
        """Format requirement and children as collapsible HTML tree.

        Args:
            req: The requirement to format
            ancestor_path: List of requirement IDs in the current traversal path (for cycle detection)

        Returns:
            Formatted HTML string
        """
        if ancestor_path is None:
            ancestor_path = []

        # Cycle detection: check if this requirement is already in our traversal path
        if req.id in ancestor_path:
            cycle_path = ancestor_path + [req.id]
            cycle_str = " -> ".join([f"REQ-{rid}" for rid in cycle_path])
            print(f"⚠️  CYCLE DETECTED: {cycle_str}", file=sys.stderr)
            return f'''
        <div class="req-item cycle-detected" data-req-id="{req.id}">
            <div class="req-header-container">
                <span class="collapse-icon"></span>
                <div class="req-content">
                    <div class="req-id">⚠️ CYCLE</div>
                    <div class="req-header">Circular dependency detected at REQ-{req.id}</div>
                    <div class="req-level">ERROR</div>
                    <div class="req-badges">
                        <span class="status-badge status-deprecated">Cycle</span>
                    </div>
                    <div class="req-location">Path: {cycle_str}</div>
                </div>
            </div>
        </div>
'''

        # Safety depth limit
        MAX_DEPTH = 50
        if len(ancestor_path) > MAX_DEPTH:
            print(f"⚠️  MAX DEPTH ({MAX_DEPTH}) exceeded at REQ-{req.id}", file=sys.stderr)
            return f'''
        <div class="req-item depth-exceeded" data-req-id="{req.id}">
            <div class="req-header-container">
                <span class="collapse-icon"></span>
                <div class="req-content">
                    <div class="req-id">⚠️ DEPTH</div>
                    <div class="req-header">Maximum depth exceeded at REQ-{req.id}</div>
                    <div class="req-level">ERROR</div>
                    <div class="req-badges">
                        <span class="status-badge status-deprecated">Overflow</span>
                    </div>
                </div>
            </div>
        </div>
'''

        status_class = req.status.lower()
        level_class = req.level.lower()

        # Find children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        # Only show collapse icon if there are children
        collapse_icon = '▼' if children else ''

        # Determine test status
        test_badge = ''
        if req.test_info:
            test_status = req.test_info.test_status
            test_count = req.test_info.test_count + req.test_info.manual_test_count

            if test_status == 'passed':
                test_badge = f'<span class="test-badge test-passed" title="{test_count} tests passed">✅ {test_count}</span>'
            elif test_status == 'failed':
                test_badge = f'<span class="test-badge test-failed" title="{test_count} tests, some failed">❌ {test_count}</span>'
            elif test_status == 'not_tested':
                test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'
        else:
            test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'

        # Extract topic from filename (e.g., prd-security.md -> security)
        topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}" data-req-id="{req.id}" data-level="{req.level}" data-topic="{topic}" data-status="{req.status}" data-title="{req.title.lower()}">
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-id">REQ-{req.id}</div>
                    <div class="req-header">{req.title}</div>
                    <div class="req-level">{req.level}</div>
                    <div class="req-badges">
                        <span class="status-badge status-{status_class}">{req.status}</span>
                    </div>
                    <div class="req-status">{test_badge}</div>
                    <div class="req-location">{req.file_path.name}:{req.line_number}</div>
                </div>
            </div>
"""

        if children:
            # Add current req to path before recursing into children
            current_path = ancestor_path + [req.id]
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html_collapsible(child, current_path)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

