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
        version: int = 9,
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
        review_mode: bool = False,
        use_templates: bool = True
    ) -> str:
        """Generate the complete HTML report.

        Args:
            embed_content: If True, embed full requirement content as JSON
            edit_mode: If True, include edit mode UI elements
            review_mode: If True, include review mode UI elements
            use_templates: If True, use Jinja2 templates (default: True)

        Returns:
            Complete HTML document as string
        """
        if use_templates:
            try:
                context = self._build_render_context(embed_content, edit_mode, review_mode)
                template = self.env.get_template('base.html')
                return template.render(**context)
            except Exception as e:
                # Fall back to legacy method on template errors
                import sys
                print(f"Template rendering failed: {e}, using legacy method", file=sys.stderr)
                return self._generate_html(embed_content=embed_content, edit_mode=edit_mode)
        else:
            return self._generate_html(embed_content=embed_content, edit_mode=edit_mode)

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
        """Load review mode CSS content.

        Loads styles from templates/partials/review-styles.css for embedding
        in the HTML output when review mode is enabled.

        Returns:
            CSS content as string, or empty string if file not found.
        """
        css_path = Path(__file__).parent / "templates" / "partials" / "review-styles.css"
        if css_path.exists():
            return css_path.read_text()
        return ""

    def _load_review_js(self) -> str:
        """Load review mode JavaScript content.

        Loads all JS modules from templates/partials/review/ and concatenates them.

        Returns:
            Combined JavaScript content as string.
        """
        js_dir = Path(__file__).parent / "templates" / "partials" / "review"
        if not js_dir.exists():
            return ""

        js_parts = []
        # Load JS files in specific order for dependencies
        js_files = [
            "review-data.js",
            "review-position.js",
            "review-comments.js",
            "review-status.js",
            "review-packages.js",
            "review-sync.js",
            "review-help.js",
            "review-resize.js",
        ]
        for filename in js_files:
            js_path = js_dir / filename
            if js_path.exists():
                js_parts.append(f"// ========== {filename} ==========")
                js_parts.append(js_path.read_text())

        return "\n\n".join(js_parts)

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
            review_mode: If True, include review mode UI

        Returns:
            Dictionary containing template context variables
        """
        import json as json_module
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

        # Build review data for review mode
        review_json_data = ""
        review_css = ""
        review_js = ""
        if review_mode:
            review_css = self._load_review_css()
            review_js = self._load_review_js()
            # Build minimal review data structure
            review_json_data = json_module.dumps({
                'threads': {},
                'flags': {},
                'requests': {},
                'config': {
                    'currentUser': '',
                    'autoSync': False
                }
            })

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

            # Review mode assets (conditional)
            'review_css': review_css,
            'review_js': review_js,
            'review_json_data': review_json_data,

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

    def _generate_side_panel_js(self) -> str:
        """Generate JavaScript functions for side panel interaction"""
        return """
        // Side panel state management
        const reqCardStack = [];

        function openReqPanel(reqId) {
            const panel = document.getElementById('req-panel');
            const cardStack = document.getElementById('req-card-stack');
            const reqData = window.REQ_CONTENT_DATA;

            if (!reqData || !reqData[reqId]) {
                console.error('Requirement data not found:', reqId);
                return;
            }

            // Show panel if hidden
            panel.classList.remove('hidden');

            // Check if card already exists
            if (reqCardStack.includes(reqId)) {
                return; // Already open
            }

            // Add to stack
            reqCardStack.unshift(reqId);

            // Create card element
            const req = reqData[reqId];
            const card = document.createElement('div');
            card.className = 'req-card';
            card.id = `req-card-${reqId}`;

            // Render markdown content
            const bodyHtml = window.marked ? marked.parse(req.body) : req.body;
            const rationaleHtml = req.rationale ? (window.marked ? marked.parse(req.rationale) : req.rationale) : '';

            // Build implements links
            let implementsHtml = '';
            if (req.implements && req.implements.length > 0) {
                const implLinks = req.implements.sort().map(parentId =>
                    `<a href="#" onclick="openReqPanel('${parentId}'); return false;" class="implements-link">${parentId}</a>`
                ).join(', ');
                implementsHtml = `<div class="req-card-implements">Implements: ${implLinks}</div>`;
            }

            // Determine if in roadmap based on file path
            const isInRoadmap = req.filePath.includes('roadmap/');
            const moveButtons = isInRoadmap
                ? `<button class="edit-btn from-roadmap panel-edit-btn" onclick="addPendingMove('${reqId}', '${req.file}', 'from-roadmap')" title="Move out of roadmap">↩ From Roadmap</button>
                   <button class="edit-btn move-file panel-edit-btn" onclick="showMoveToFile('${reqId}', '${req.file}')" title="Move to different file">📁 Move</button>`
                : `<button class="edit-btn to-roadmap panel-edit-btn" onclick="addPendingMove('${reqId}', '${req.file}', 'to-roadmap')" title="Move to roadmap">🗺️ To Roadmap</button>
                   <button class="edit-btn move-file panel-edit-btn" onclick="showMoveToFile('${reqId}', '${req.file}')" title="Move to different file">📁 Move</button>`;

            // Generate VS Code link - use relative path when REPO_ROOT is empty (portable mode)
            const repoRelPath = req.filePath.replace(/^\\.\\.\\//, '');
            const vscodeHref = window.REPO_ROOT
                ? `vscode://file/${window.REPO_ROOT}/${repoRelPath}:${req.line}`
                : `${req.filePath}`;  // Relative link for portable mode
            const vscodeTitle = window.REPO_ROOT
                ? 'Open in VS Code'
                : `Open file (${repoRelPath}:${req.line})`;

            card.innerHTML = `
                <div class="req-card-header">
                    <span class="req-card-title">REQ-${reqId}: ${req.title}</span>
                    <button class="close-btn" onclick="closeReqCard('${reqId}')">×</button>
                </div>
                <div class="req-card-body">
                    <div class="req-card-meta">
                        <span class="badge">${req.level}</span>
                        <span class="badge">${req.status}</span>
                        <a href="#" onclick="openCodeViewer('${req.filePath}', ${req.line}); return false;" class="file-ref-link">${req.file}:${req.line}</a>
                        <a href="${vscodeHref}" title="${vscodeTitle}" class="vscode-link">🔧</a>
                    </div>
                    <div class="req-card-actions edit-actions">
                        ${moveButtons}
                    </div>
                    ${implementsHtml}
                    <div class="req-card-content markdown-body">
                        <div class="req-body">${bodyHtml}</div>
                        ${rationaleHtml ? `<div class="req-rationale"><strong>Rationale:</strong> ${rationaleHtml}</div>` : ''}
                    </div>
                </div>
            `;

            // Add to top of stack
            cardStack.insertBefore(card, cardStack.firstChild);
        }

        function closeReqCard(reqId) {
            const card = document.getElementById(`req-card-${reqId}`);
            if (card) {
                card.remove();
            }
            const index = reqCardStack.indexOf(reqId);
            if (index > -1) {
                reqCardStack.splice(index, 1);
            }

            // Hide panel if empty
            if (reqCardStack.length === 0) {
                document.getElementById('req-panel').classList.add('hidden');
            }
        }

        function closeAllCards() {
            const cardStack = document.getElementById('req-card-stack');
            cardStack.innerHTML = '';
            reqCardStack.length = 0;
            document.getElementById('req-panel').classList.add('hidden');
        }

        // Panel resize functionality
        (function initResize() {
            const panel = document.getElementById('req-panel');
            const handle = document.getElementById('resizeHandle');
            if (!panel || !handle) return;

            let isResizing = false;
            let startX, startWidth;

            handle.addEventListener('mousedown', function(e) {
                isResizing = true;
                startX = e.clientX;
                startWidth = panel.offsetWidth;
                handle.classList.add('dragging');
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';
                e.preventDefault();
            });

            document.addEventListener('mousemove', function(e) {
                if (!isResizing) return;
                const diff = startX - e.clientX;
                const newWidth = Math.min(Math.max(startWidth + diff, 250), window.innerWidth * 0.7);
                panel.style.width = newWidth + 'px';
            });

            document.addEventListener('mouseup', function() {
                if (isResizing) {
                    isResizing = false;
                    handle.classList.remove('dragging');
                    document.body.style.cursor = '';
                    document.body.style.userSelect = '';
                }
            });
        })();

        // Code viewer functions
        async function openCodeViewer(filePath, lineNum) {
            const modal = document.getElementById('code-viewer-modal');
            const content = document.getElementById('code-viewer-content');
            const title = document.getElementById('code-viewer-title');
            const lineInfo = document.getElementById('code-viewer-line');
            const vscodeLink = document.getElementById('code-viewer-vscode');

            title.textContent = filePath;
            lineInfo.textContent = `Line ${lineNum}`;
            content.innerHTML = '<div class="loading">Loading...</div>';
            modal.classList.remove('hidden');

            // Set VS Code link - use absolute path when REPO_ROOT set, relative otherwise
            if (vscodeLink) {
                // Remove leading ../ from relative path to get repo-relative path
                const repoRelPath = filePath.replace(/^\\.\\.\\//, '');
                if (window.REPO_ROOT) {
                    // Local mode: use vscode:// protocol with absolute path
                    const absPath = window.REPO_ROOT + '/' + repoRelPath;
                    vscodeLink.href = `vscode://file/${absPath}:${lineNum}`;
                    vscodeLink.title = 'Open in VS Code';
                } else {
                    // Portable mode: use relative file link
                    vscodeLink.href = filePath;
                    vscodeLink.title = `Open file (${repoRelPath}:${lineNum})`;
                }
            }

            try {
                const response = await fetch(filePath);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                const text = await response.text();

                const ext = filePath.split('.').pop().toLowerCase();

                // For markdown files, render as formatted markdown with line anchors
                if (ext === 'md' && window.marked) {
                    // Wrap each source line in a span with line ID before parsing
                    const lines = text.split('\\n');
                    const wrappedText = lines.map((line, idx) =>
                        `<span id="md-line-${idx + 1}" class="md-line">${line}</span>`
                    ).join('\\n');

                    // Use custom renderer to preserve line spans through markdown parsing
                    // Simpler approach: render markdown, then inject line markers
                    const renderedHtml = marked.parse(text);
                    content.innerHTML = `<div class="markdown-viewer markdown-body">${renderedHtml}</div>`;
                    content.classList.add('markdown-mode');

                    // Find the element containing the target line by searching the raw text position
                    setTimeout(() => {
                        // Calculate which heading or paragraph contains our target line
                        const targetLine = lineNum;
                        let currentLine = 1;
                        let targetElement = null;

                        // Find the nearest heading at or before the target line
                        const headings = content.querySelectorAll('h1, h2, h3, h4');
                        for (const heading of headings) {
                            // Search for this heading's text in the source to find its line
                            // Only match actual markdown headings (lines starting with #)
                            const headingText = heading.textContent.trim();
                            for (let i = 0; i < lines.length; i++) {
                                const line = lines[i].trim();
                                // Must be a markdown heading line (starts with #) and contain the heading text
                                if (line.startsWith('#') && line.includes(headingText)) {
                                    if (i + 1 <= targetLine) {
                                        targetElement = heading;
                                    }
                                    break;
                                }
                            }
                        }

                        // If no heading found, try to find by searching for the actual line content
                        if (!targetElement && targetLine <= lines.length) {
                            const targetText = lines[targetLine - 1].trim();
                            if (targetText) {
                                // Search all text nodes for this content
                                const walker = document.createTreeWalker(
                                    content,
                                    NodeFilter.SHOW_TEXT,
                                    null,
                                    false
                                );
                                let node;
                                while (node = walker.nextNode()) {
                                    if (node.textContent.includes(targetText)) {
                                        targetElement = node.parentElement;
                                        break;
                                    }
                                }
                            }
                        }

                        // Fallback to first heading
                        if (!targetElement) {
                            targetElement = content.querySelector('h1, h2, h3');
                        }

                        if (targetElement) {
                            targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                            // Briefly highlight the element
                            targetElement.classList.add('highlight-target');
                            setTimeout(() => targetElement.classList.remove('highlight-target'), 2000);
                        }
                    }, 100);
                } else {
                    // For code files, show with line numbers
                    content.classList.remove('markdown-mode');
                    const lines = text.split('\\n');
                    const langClass = getLangClass(ext);

                    let html = '<table class="code-table"><tbody>';
                    lines.forEach((line, idx) => {
                        const lineNumber = idx + 1;
                        const isHighlighted = lineNumber === lineNum;
                        const highlightClass = isHighlighted ? 'highlighted-line' : '';
                        const lineId = `L${lineNumber}`;
                        // Escape HTML entities
                        const escapedLine = line
                            .replace(/&/g, '&amp;')
                            .replace(/</g, '&lt;')
                            .replace(/>/g, '&gt;');
                        html += `<tr id="${lineId}" class="${highlightClass}">`;
                        html += `<td class="line-num">${lineNumber}</td>`;
                        html += `<td class="line-code"><pre><code class="${langClass}">${escapedLine || ' '}</code></pre></td>`;
                        html += '</tr>';
                    });
                    html += '</tbody></table>';

                    content.innerHTML = html;

                    // Scroll to highlighted line
                    setTimeout(() => {
                        const highlightedRow = content.querySelector('.highlighted-line');
                        if (highlightedRow) {
                            highlightedRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                    }, 100);

                    // Apply syntax highlighting if hljs is available
                    if (window.hljs) {
                        content.querySelectorAll('code').forEach(block => {
                            hljs.highlightElement(block);
                        });
                    }
                }
            } catch (err) {
                content.innerHTML = `<div class="error">Failed to load file: ${err.message}</div>`;
            }
        }

        function getLangClass(ext) {
            const langMap = {
                'dart': 'language-dart',
                'sql': 'language-sql',
                'py': 'language-python',
                'js': 'language-javascript',
                'ts': 'language-typescript',
                'json': 'language-json',
                'md': 'language-markdown',
                'yaml': 'language-yaml',
                'yml': 'language-yaml',
                'sh': 'language-bash',
                'bash': 'language-bash'
            };
            return langMap[ext] || 'language-plaintext';
        }

        function closeCodeViewer() {
            document.getElementById('code-viewer-modal').classList.add('hidden');
        }

        // Legend modal functions
        function openLegendModal() {
            document.getElementById('legend-modal').classList.remove('hidden');
        }

        function closeLegendModal() {
            document.getElementById('legend-modal').classList.add('hidden');
        }

        // Leaf only toggle
        let leafOnlyActive = false;
        function toggleLeafOnly() {
            leafOnlyActive = !leafOnlyActive;
            const btn = document.getElementById('btnLeafOnly');
            if (leafOnlyActive) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
            applyFilters();
        }

        // Toggle include deprecated - updates badge counts and filters
        function toggleIncludeDeprecated() {
            const includeDeprecated = document.getElementById('chkIncludeDeprecated').checked;

            // Update PRD/OPS/DEV badge counts based on checkbox
            ['PRD', 'OPS', 'DEV'].forEach(level => {
                const badge = document.getElementById('badge' + level);
                if (badge) {
                    const count = includeDeprecated ? badge.dataset.all : badge.dataset.active;
                    badge.textContent = level + ': ' + count;
                }
            });

            applyFilters();
        }

        // Toggle include roadmap - show/hide roadmap requirements
        function toggleIncludeRoadmap() {
            applyFilters();
        }

        // ========== Edit Mode Functions ==========
        let editModeActive = false;
        const pendingMoves = [];

        function toggleEditMode() {
            editModeActive = !editModeActive;
            const btn = document.getElementById('btnEditMode');
            const panel = document.getElementById('editModePanel');

            if (editModeActive) {
                document.body.classList.add('edit-mode-active');
                btn.classList.add('active');
                panel.style.display = 'block';
                // Auto-enable roadmap view when entering edit mode
                document.getElementById('chkIncludeRoadmap').checked = true;
                applyFilters();
            } else {
                document.body.classList.remove('edit-mode-active');
                btn.classList.remove('active');
                panel.style.display = 'none';
            }
        }

        function addPendingMove(reqId, sourceFile, moveType) {
            // Check if already in pending list
            const existing = pendingMoves.find(m => m.reqId === reqId);
            if (existing) {
                alert('This requirement already has a pending move. Clear selection first.');
                return;
            }

            // Get title from the DOM element
            const reqItem = document.querySelector(`.req-item[data-req-id="${reqId}"]`);
            const title = reqItem ? reqItem.dataset.title : '';

            const move = {
                reqId: reqId,
                sourceFile: sourceFile,
                moveType: moveType,
                title: title,
                targetFile: moveType === 'to-roadmap' ? `roadmap/${sourceFile}` :
                            moveType === 'from-roadmap' ? sourceFile.replace('roadmap/', '') :
                            null
            };
            pendingMoves.push(move);
            updatePendingMovesUI();
            updateDestinationColumns();
        }

        function removePendingMove(index) {
            pendingMoves.splice(index, 1);
            updatePendingMovesUI();
            updateDestinationColumns();
        }

        function clearPendingMoves() {
            pendingMoves.length = 0;
            updatePendingMovesUI();
            updateDestinationColumns();
        }

        // Store original status suffixes for restoration
        const originalStatusSuffixes = new Map();

        function updateDestinationColumns() {
            // Reset all destination columns - show buttons, hide dest text
            document.querySelectorAll('.req-destination').forEach(el => {
                const editActions = el.querySelector('.edit-actions');
                const destText = el.querySelector('.dest-text');
                if (editActions) editActions.style.display = '';
                if (destText) {
                    destText.textContent = '';
                    destText.style.display = 'none';
                }
                el.className = 'req-destination edit-mode-column';
            });

            // Restore original status suffixes for items not in pending moves
            document.querySelectorAll('.req-item[data-req-id]').forEach(item => {
                const reqId = item.dataset.reqId;
                const suffixEl = item.querySelector('.status-suffix');
                if (suffixEl && originalStatusSuffixes.has(reqId)) {
                    const original = originalStatusSuffixes.get(reqId);
                    // Only restore if not in pending moves
                    if (!pendingMoves.some(m => m.reqId === reqId)) {
                        suffixEl.textContent = original.text;
                        suffixEl.className = original.className;
                        suffixEl.title = original.title;
                    }
                }
            });

            // Update destination columns and status suffixes for pending moves
            pendingMoves.forEach(m => {
                const reqItem = document.querySelector(`.req-item[data-req-id="${m.reqId}"]`);
                if (!reqItem) return;

                const destEl = reqItem.querySelector('.req-destination');
                const suffixEl = reqItem.querySelector('.status-suffix');

                // Save original status suffix if not already saved
                if (suffixEl && !originalStatusSuffixes.has(m.reqId)) {
                    originalStatusSuffixes.set(m.reqId, {
                        text: suffixEl.textContent,
                        className: suffixEl.className,
                        title: suffixEl.title
                    });
                }

                // Update destination column - hide buttons, show destination text
                if (destEl) {
                    const editActions = destEl.querySelector('.edit-actions');
                    const destText = destEl.querySelector('.dest-text');

                    // Hide the buttons
                    if (editActions) editActions.style.display = 'none';

                    // Show the destination text
                    if (destText) {
                        destText.style.display = '';
                        if (m.moveType === 'to-roadmap') {
                            destText.textContent = '→ Roadmap';
                            destEl.className = 'req-destination edit-mode-column to-roadmap';
                        } else if (m.moveType === 'from-roadmap') {
                            destText.textContent = '← From Roadmap';
                            destEl.className = 'req-destination edit-mode-column from-roadmap';
                        } else if (m.targetFile) {
                            const displayName = m.targetFile.replace('roadmap/', '').replace(/\\.md$/, '');
                            destText.textContent = '→ ' + displayName;
                        }
                    }
                }

                // Update status suffix to show "pending move" indicator
                if (suffixEl) {
                    const originalText = originalStatusSuffixes.get(m.reqId)?.text || '';
                    if (originalText && originalText !== '↝' && originalText !== '⇢') {
                        suffixEl.textContent = '⇢' + originalText;
                        suffixEl.className = 'status-suffix status-pending-move';
                        suffixEl.title = 'PENDING MOVE + ' + (originalStatusSuffixes.get(m.reqId)?.title || '');
                    } else {
                        suffixEl.textContent = '⇢';
                        suffixEl.className = 'status-suffix status-pending-move';
                        suffixEl.title = 'PENDING MOVE (not yet executed)';
                    }
                }
            });
        }

        let pendingMovesCollapsed = false;

        function togglePendingMoves() {
            pendingMovesCollapsed = !pendingMovesCollapsed;
            const list = document.getElementById('pendingMovesList');
            const toggleBtn = document.getElementById('pendingMovesToggle');
            if (pendingMovesCollapsed) {
                list.style.display = 'none';
                toggleBtn.textContent = '▶';
            } else {
                list.style.display = 'block';
                toggleBtn.textContent = '▼';
            }
        }

        function updatePendingMovesUI() {
            const list = document.getElementById('pendingMovesList');
            const count = document.getElementById('pendingChangesCount');
            const btn = document.getElementById('btnExportMoves');

            count.textContent = pendingMoves.length + ' pending';
            btn.disabled = pendingMoves.length === 0;

            if (pendingMoves.length === 0) {
                list.innerHTML = '<div style="color: #666; padding: 10px;">No pending moves. Click edit buttons on requirements to select them.</div>';
                return;
            }

            list.innerHTML = pendingMoves.map((m, i) => {
                const displayTarget = m.targetFile ?
                    (m.moveType === 'to-roadmap' ? 'Roadmap' :
                     m.moveType === 'from-roadmap' ? m.targetFile :
                     m.targetFile) :
                    '(select target)';
                const titleDisplay = m.title ? ` - ${m.title}` : '';
                return `
                <div class="pending-move-item">
                    <span><strong>REQ-${m.reqId}</strong>${titleDisplay}</span>
                    <span style="color: #666; margin-left: 8px;">→ ${displayTarget}</span>
                    <button onclick="removePendingMove(${i})" style="background: none; border: none; cursor: pointer; margin-left: auto;">✕</button>
                </div>
            `}).join('');
        }

        let filePickerState = { reqId: null, sourceFile: null };
        let allSpecFiles = [];
        const userAddedFiles = new Set();  // Track user-entered filenames for future use

        function showMoveToFile(reqId, sourceFile) {
            filePickerState = { reqId, sourceFile };
            allSpecFiles = getAvailableTargetFiles();

            const modal = document.getElementById('file-picker-modal');
            const input = document.getElementById('filePickerInput');
            const list = document.getElementById('filePickerList');
            const error = document.getElementById('filePickerError');

            // Reset state
            input.value = '';
            error.textContent = '';
            error.style.display = 'none';

            // Populate file list
            renderFileList('');

            // Show modal and focus input
            modal.classList.remove('hidden');
            input.focus();
        }

        function closeFilePicker() {
            document.getElementById('file-picker-modal').classList.add('hidden');
            filePickerState = { reqId: null, sourceFile: null };
        }

        function renderFileList(filter) {
            const list = document.getElementById('filePickerList');
            const filterLower = filter.toLowerCase();

            const filtered = allSpecFiles.filter(f =>
                f.toLowerCase().includes(filterLower)
            );

            if (filtered.length === 0 && filter) {
                list.innerHTML = '<div class="file-picker-empty">No matching files. You can enter a new filename.</div>';
            } else {
                list.innerHTML = filtered.map(f =>
                    `<div class="file-picker-item" onclick="selectFile('${f}')">${f}</div>`
                ).join('');
            }
        }

        function filterFiles(value) {
            renderFileList(value);
            validateFileName(value);
        }

        function selectFile(filename) {
            document.getElementById('filePickerInput').value = filename;
            validateFileName(filename);
        }

        function validateFileName(filename) {
            const error = document.getElementById('filePickerError');

            if (!filename || !filename.trim()) {
                error.style.display = 'none';
                return false;
            }

            filename = filename.trim();

            // Check for .md extension
            if (!filename.endsWith('.md')) {
                error.textContent = 'Filename must end with .md';
                error.style.display = 'block';
                return false;
            }

            // Check for illegal characters (allow alphanumeric, dash, underscore, dot, forward slash for paths)
            const illegalChars = /[<>:"\\|?*\\x00-\\x1f]/;
            if (illegalChars.test(filename)) {
                error.textContent = 'Filename contains illegal characters';
                error.style.display = 'block';
                return false;
            }

            // Check for spaces (should use dashes instead)
            if (filename.includes(' ')) {
                error.textContent = 'Use dashes instead of spaces';
                error.style.display = 'block';
                return false;
            }

            // Check it doesn't start with special chars
            if (/^[.\\-\\/]/.test(filename)) {
                error.textContent = 'Filename cannot start with . - or /';
                error.style.display = 'block';
                return false;
            }

            error.style.display = 'none';
            return true;
        }

        function confirmFilePicker() {
            const input = document.getElementById('filePickerInput');
            const filename = input.value.trim();

            if (!validateFileName(filename)) {
                return;
            }

            // Remember user-entered filenames for future use
            userAddedFiles.add(filename);

            // Add the pending move
            addPendingMove(filePickerState.reqId, filePickerState.sourceFile, 'move-file');
            pendingMoves[pendingMoves.length - 1].targetFile = filename;
            updatePendingMovesUI();
            updateDestinationColumns();

            closeFilePicker();
        }

        function getAvailableTargetFiles() {
            const files = new Set();
            // Add files from existing requirements
            document.querySelectorAll('.req-item[data-file]').forEach(item => {
                files.add(item.dataset.file);
            });
            // Add user-entered filenames from this session
            userAddedFiles.forEach(f => files.add(f));
            return Array.from(files).sort();
        }

        function generateMoveScript() {
            if (pendingMoves.length === 0) {
                alert('No pending moves to generate script for.');
                return;
            }

            // Build JSON moves array
            const moves = pendingMoves
                .filter(m => m.targetFile)
                .map(m => ({
                    reqId: m.reqId,
                    source: m.sourceFile,
                    target: m.targetFile
                }));

            if (moves.length === 0) {
                alert('No valid moves (all moves need target files).');
                return;
            }

            const jsonOutput = JSON.stringify(moves, null, 2);

            // Create downloadable JSON file
            const blob = new Blob([jsonOutput], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'moves.json';
            a.click();
            URL.revokeObjectURL(url);

            alert('Saved moves.json\\n\\nRun with:\\n  python3 tools/requirements/move_reqs.py moves.json\\n\\nOr preview first:\\n  python3 tools/requirements/move_reqs.py --dry-run moves.json');
        }
        // ========== End Edit Mode Functions ==========

        // Close modals on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeCodeViewer();
                closeLegendModal();
            }
        });
"""

    def _generate_code_viewer_css(self) -> str:
        """Generate CSS styles for code viewer modal"""
        return """
        /* Code Viewer Modal */
        .code-viewer-modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.7);
            z-index: 2000;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .code-viewer-modal.hidden {
            display: none;
        }
        .code-viewer-container {
            width: 85%;
            height: 85%;
            background: #1e1e1e;
            border-radius: 8px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0,0,0,0.5);
        }
        .code-viewer-header {
            background: #333;
            padding: 12px 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #444;
        }
        .code-viewer-title {
            color: #e0e0e0;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 14px;
        }
        .code-viewer-line {
            color: #888;
            font-size: 12px;
            margin-left: 15px;
        }
        .code-viewer-close {
            background: #dc3545;
            border: none;
            color: white;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        .code-viewer-close:hover {
            background: #c82333;
        }
        .code-viewer-body {
            flex: 1;
            overflow: auto;
            background: #1e1e1e;
        }
        .code-table {
            border-collapse: collapse;
            width: 100%;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            font-size: 13px;
            line-height: 1.5;
        }
        .code-table tr {
            background: #1e1e1e;
        }
        .code-table tr.highlighted-line {
            background: #3a3a00 !important;
        }
        .code-table tr.highlighted-line .line-num {
            background: #5a5a00;
            color: #fff;
        }
        .line-num {
            text-align: right;
            padding: 0 12px;
            color: #606060;
            background: #252526;
            user-select: none;
            min-width: 50px;
            border-right: 1px solid #333;
            vertical-align: top;
        }
        .line-code {
            padding: 0 16px;
            white-space: pre;
            color: #d4d4d4;
        }
        .line-code pre {
            margin: 0;
            padding: 0;
        }
        .line-code code {
            font-family: inherit;
            background: transparent !important;
            padding: 0 !important;
        }
        .code-viewer-body .loading {
            color: #888;
            padding: 20px;
            text-align: center;
        }
        .code-viewer-body .error {
            color: #ff6b6b;
            padding: 20px;
            text-align: center;
        }
        /* Markdown rendering in code viewer */
        .code-viewer-body.markdown-mode {
            background: #ffffff;
        }
        .markdown-viewer {
            padding: 20px 30px;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
        }
        .markdown-viewer h1 {
            font-size: 24px;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 8px;
            margin-top: 30px;
        }
        .markdown-viewer h2 {
            font-size: 20px;
            margin-top: 25px;
            color: #2c3e50;
        }
        .markdown-viewer h3 {
            font-size: 16px;
            margin-top: 20px;
            color: #34495e;
        }
        .markdown-viewer p {
            margin: 12px 0;
            line-height: 1.7;
        }
        .markdown-viewer ul, .markdown-viewer ol {
            margin: 12px 0;
            padding-left: 25px;
        }
        .markdown-viewer li {
            margin: 6px 0;
            line-height: 1.6;
        }
        .markdown-viewer code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 13px;
        }
        .markdown-viewer pre {
            background: #2d2d2d;
            color: #ccc;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 15px 0;
        }
        .markdown-viewer pre code {
            background: none;
            padding: 0;
            color: inherit;
        }
        .markdown-viewer blockquote {
            margin: 15px 0;
            padding: 10px 15px;
            border-left: 4px solid #0066cc;
            background: #f8f9fa;
            color: #555;
        }
        .markdown-viewer table {
            border-collapse: collapse;
            margin: 15px 0;
            width: 100%;
        }
        .markdown-viewer th, .markdown-viewer td {
            border: 1px solid #dee2e6;
            padding: 8px 12px;
            text-align: left;
        }
        .markdown-viewer th {
            background: #f8f9fa;
            font-weight: 600;
        }
        .markdown-viewer strong {
            font-weight: 600;
        }
        .markdown-viewer a {
            color: #0066cc;
        }
        .markdown-viewer hr {
            border: none;
            border-top: 1px solid #dee2e6;
            margin: 20px 0;
        }
        .markdown-viewer .highlight-target {
            background: #fff3cd;
            animation: highlight-fade 2s ease-out;
        }
        @keyframes highlight-fade {
            0% { background: #fff3cd; }
            100% { background: transparent; }
        }
"""

    def _generate_code_viewer_html(self) -> str:
        """Generate HTML for code viewer modal"""
        return """
    <!-- Code Viewer Modal -->
    <div id="code-viewer-modal" class="code-viewer-modal hidden">
        <div class="code-viewer-container">
            <div class="code-viewer-header">
                <div>
                    <span id="code-viewer-title" class="code-viewer-title"></span>
                    <span id="code-viewer-line" class="code-viewer-line"></span>
                    <a id="code-viewer-vscode" href="#" title="Open in VS Code" class="vscode-link" style="font-size: 18px;">🔧</a>
                </div>
                <button class="code-viewer-close" onclick="closeCodeViewer()">Close (Esc)</button>
            </div>
            <div id="code-viewer-content" class="code-viewer-body"></div>
        </div>
    </div>
"""

    def _generate_legend_modal_html(self) -> str:
        """Generate HTML for legend modal"""
        return """
    <!-- Legend Modal -->
    <div id="legend-modal" class="legend-modal hidden" onclick="if(event.target===this)closeLegendModal()">
        <div class="legend-modal-container">
            <div class="legend-modal-header">
                <h2>Legend</h2>
                <button class="legend-modal-close" onclick="closeLegendModal()">×</button>
            </div>
            <div class="legend-modal-body">
                <div class="legend-grid">
                    <div class="legend-section">
                        <h3>Requirement Levels</h3>
                        <ul>
                            <li><span class="stat-badge prd">PRD</span> Product Requirements</li>
                            <li><span class="stat-badge ops">OPS</span> Operations Requirements</li>
                            <li><span class="stat-badge dev">DEV</span> Development Requirements</li>
                        </ul>
                    </div>
                    <div class="legend-section">
                        <h3>Status</h3>
                        <ul>
                            <li><span class="status-badge status-active">Active</span> Active requirement</li>
                            <li><span class="status-badge status-draft">Draft</span> Draft requirement</li>
                            <li><span class="status-badge status-deprecated">Deprecated</span> Deprecated</li>
                        </ul>
                    </div>
                    <div class="legend-section">
                        <h3>Implementation Coverage</h3>
                        <ul>
                            <li>● Full - All children/code implemented</li>
                            <li>◐ Partial - Some implementation</li>
                            <li>○ None - No implementation found</li>
                        </ul>
                    </div>
                    <div class="legend-section">
                        <h3>Test Status</h3>
                        <ul>
                            <li>✅ Tests passing</li>
                            <li>❌ Tests failing</li>
                            <li>⚡ Not tested</li>
                        </ul>
                    </div>
                    <div class="legend-section">
                        <h3>Change Indicators</h3>
                        <ul>
                            <li><span class="status-new">★</span> NEW - Uncommitted new requirement</li>
                            <li><span class="status-modified">◆</span> MODIFIED - Content changed (uncommitted)</li>
                            <li><span class="status-moved">↝</span> MOVED - Relocated to different file</li>
                            <li><span class="status-pending-move">⇢</span> PENDING - Staged for move (not yet executed)</li>
                            <li>🛤️ Roadmap - Requirement is in roadmap/ directory</li>
                        </ul>
                    </div>
                    <div class="legend-section">
                        <h3>Issues (Always Visible)</h3>
                        <ul>
                            <li><span class="conflict-icon">⚠️</span> CONFLICT - Roadmap REQ has same ID as existing REQ</li>
                            <li><span class="cycle-icon">🔄</span> CYCLE - REQ is part of a dependency cycle</li>
                        </ul>
                    </div>
                </div>
                <div class="legend-section" style="margin-top: 15px;">
                    <h3>Controls</h3>
                    <ul>
                        <li>▼/▶ Click to expand/collapse children</li>
                        <li>🍃 Leaf Only - Show only leaf requirements (no children)</li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
"""

    def _generate_file_picker_modal_html(self) -> str:
        """Generate HTML for file picker modal"""
        return """
    <!-- File Picker Modal -->
    <div id="file-picker-modal" class="file-picker-modal hidden" onclick="if(event.target===this)closeFilePicker()">
        <div class="file-picker-container">
            <div class="file-picker-header">
                <h2>Select Destination File</h2>
                <button class="file-picker-close" onclick="closeFilePicker()">×</button>
            </div>
            <div class="file-picker-body">
                <div class="file-picker-input-row">
                    <input type="text" id="filePickerInput" placeholder="Enter or select filename (e.g., prd-security.md)"
                           oninput="filterFiles(this.value)"
                           onkeydown="if(event.key==='Enter'){confirmFilePicker();event.preventDefault();}">
                    <button class="btn" onclick="confirmFilePicker()">Confirm</button>
                </div>
                <div id="filePickerError" class="file-picker-error" style="display: none;"></div>
                <div class="file-picker-hint">Click a file below to select it, or type a new filename</div>
                <div id="filePickerList" class="file-picker-list"></div>
            </div>
        </div>
    </div>
"""

    def _generate_legend_modal_css(self) -> str:
        """Generate CSS for legend modal"""
        return """
        .legend-modal {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .legend-modal.hidden {
            display: none;
        }
        .legend-modal-container {
            background: white;
            border-radius: 8px;
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow: auto;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        }
        .legend-modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 20px;
            border-bottom: 1px solid #dee2e6;
        }
        .legend-modal-header h2 {
            margin: 0;
            font-size: 16px;
        }
        .legend-modal-close {
            background: none;
            border: none;
            font-size: 24px;
            cursor: pointer;
            color: #666;
            padding: 0 5px;
        }
        .legend-modal-close:hover {
            color: #000;
        }
        .legend-modal-body {
            padding: 20px;
        }
        .legend-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        .legend-section h3 {
            font-size: 13px;
            margin: 0 0 10px 0;
            color: #495057;
        }
        .legend-section ul {
            list-style: none;
            padding: 0;
            margin: 0;
            font-size: 12px;
        }
        .legend-section li {
            margin: 6px 0;
            display: flex;
            align-items: center;
            gap: 8px;
        }
"""

    def _generate_file_picker_modal_css(self) -> str:
        """Generate CSS for file picker modal"""
        return """
        .file-picker-modal {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .file-picker-modal.hidden {
            display: none;
        }
        .file-picker-container {
            background: white;
            border-radius: 8px;
            max-width: 500px;
            width: 90%;
            max-height: 80vh;
            display: flex;
            flex-direction: column;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        }
        .file-picker-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 20px;
            border-bottom: 1px solid #dee2e6;
        }
        .file-picker-header h2 {
            margin: 0;
            font-size: 18px;
        }
        .file-picker-close {
            background: none;
            border: none;
            font-size: 24px;
            cursor: pointer;
            color: #666;
            padding: 0 5px;
        }
        .file-picker-close:hover {
            color: #333;
        }
        .file-picker-body {
            padding: 20px;
            overflow-y: auto;
        }
        .file-picker-input-row {
            display: flex;
            gap: 10px;
            margin-bottom: 10px;
        }
        .file-picker-input-row input {
            flex: 1;
            padding: 8px 12px;
            border: 1px solid #ced4da;
            border-radius: 4px;
            font-size: 14px;
        }
        .file-picker-input-row input:focus {
            outline: none;
            border-color: #007bff;
            box-shadow: 0 0 0 2px rgba(0,123,255,0.25);
        }
        .file-picker-error {
            color: #dc3545;
            font-size: 12px;
            margin-bottom: 10px;
            padding: 5px 10px;
            background: #fff5f5;
            border-radius: 3px;
        }
        .file-picker-hint {
            font-size: 12px;
            color: #666;
            margin-bottom: 10px;
        }
        .file-picker-list {
            max-height: 300px;
            overflow-y: auto;
            border: 1px solid #dee2e6;
            border-radius: 4px;
        }
        .file-picker-item {
            padding: 8px 12px;
            cursor: pointer;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 13px;
            border-bottom: 1px solid #eee;
        }
        .file-picker-item:last-child {
            border-bottom: none;
        }
        .file-picker-item:hover {
            background: #e3f2fd;
        }
        .file-picker-empty {
            padding: 15px;
            color: #666;
            text-align: center;
            font-style: italic;
        }
"""

    def _generate_side_panel_css(self) -> str:
        """Generate CSS styles for side panel"""
        return """
        .side-panel {
            width: 400px;
            min-width: 250px;
            max-width: 70vw;
            height: 100vh;
            background: white;
            border-left: 2px solid #dee2e6;
            box-shadow: -2px 0 8px rgba(0,0,0,0.1);
            display: flex;
            flex-direction: column;
            flex-shrink: 0;
        }
        .side-panel.hidden {
            display: none;
        }
        .resize-handle {
            position: absolute;
            left: -4px;
            top: 0;
            width: 8px;
            height: 100%;
            cursor: col-resize;
            background: transparent;
            z-index: 10;
        }
        .resize-handle:hover,
        .resize-handle.dragging {
            background: rgba(0, 102, 204, 0.3);
        }
        .panel-header {
            padding: 15px;
            background: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-weight: 600;
            font-size: 14px;
        }
        .panel-header button {
            padding: 4px 8px;
            font-size: 11px;
            border: none;
            background: #dc3545;
            color: white;
            border-radius: 3px;
            cursor: pointer;
        }
        .panel-header button:hover {
            background: #c82333;
        }
        #req-card-stack {
            flex: 1;
            overflow-y: auto;
            padding: 10px;
        }
        .req-card {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            margin-bottom: 10px;
            overflow: hidden;
        }
        .req-card-header {
            background: #e9ecef;
            padding: 10px 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #dee2e6;
        }
        .req-card-title {
            font-weight: 600;
            font-size: 12px;
            color: #2c3e50;
        }
        .close-btn {
            background: none;
            border: none;
            font-size: 20px;
            color: #6c757d;
            cursor: pointer;
            padding: 0;
            width: 24px;
            height: 24px;
            line-height: 20px;
        }
        .close-btn:hover {
            color: #dc3545;
        }
        .req-card-body {
            padding: 12px;
        }
        .req-card-meta {
            display: flex;
            gap: 6px;
            margin-bottom: 10px;
            flex-wrap: wrap;
        }
        .req-card-meta .badge {
            display: inline-block;
            padding: 2px 6px;
            background: #0066cc;
            color: white;
            border-radius: 3px;
            font-size: 10px;
            font-weight: 600;
        }
        .req-card-meta .file-ref {
            font-size: 10px;
            color: #6c757d;
            font-family: 'Consolas', 'Monaco', monospace;
        }
        .file-ref-link {
            font-size: 10px;
            color: #0066cc;
            font-family: 'Consolas', 'Monaco', monospace;
            text-decoration: none;
        }
        .file-ref-link:hover {
            text-decoration: underline;
        }
        .req-card-implements {
            font-size: 11px;
            color: #6c757d;
            margin-bottom: 10px;
            padding: 6px 8px;
            background: #f8f9fa;
            border-radius: 3px;
        }
        .req-card-implements .implements-link {
            color: #0066cc;
            text-decoration: none;
        }
        .req-card-implements .implements-link:hover {
            text-decoration: underline;
        }
        .req-card-content {
            font-size: 13px;
            line-height: 1.6;
        }
        .req-body {
            margin-bottom: 10px;
        }
        .req-rationale {
            padding: 8px;
            background: #fff3cd;
            border-left: 3px solid #ffc107;
            font-size: 12px;
        }
        /* Markdown content styling */
        .markdown-body p {
            margin: 0 0 10px 0;
        }
        .markdown-body ul, .markdown-body ol {
            margin: 0 0 10px 0;
            padding-left: 20px;
        }
        .markdown-body li {
            margin: 4px 0;
        }
        .markdown-body code {
            background: #f4f4f4;
            padding: 2px 5px;
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 12px;
        }
        .markdown-body pre {
            background: #2d2d2d;
            color: #ccc;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
            margin: 10px 0;
        }
        .markdown-body pre code {
            background: none;
            padding: 0;
            color: inherit;
        }
        .markdown-body strong {
            font-weight: 600;
        }
        .markdown-body em {
            font-style: italic;
        }
        .markdown-body h1, .markdown-body h2, .markdown-body h3 {
            margin: 15px 0 10px 0;
            font-weight: 600;
        }
        .markdown-body h1 { font-size: 18px; }
        .markdown-body h2 { font-size: 16px; }
        .markdown-body h3 { font-size: 14px; }
        .markdown-body blockquote {
            margin: 10px 0;
            padding: 8px 12px;
            border-left: 3px solid #dee2e6;
            background: #f8f9fa;
            color: #6c757d;
        }
        .markdown-body a {
            color: #0066cc;
            text-decoration: none;
        }
        .markdown-body a:hover {
            text-decoration: underline;
        }
        .markdown-body table {
            border-collapse: collapse;
            margin: 10px 0;
            width: 100%;
        }
        .markdown-body th, .markdown-body td {
            border: 1px solid #dee2e6;
            padding: 6px 10px;
            text-align: left;
        }
        .markdown-body th {
            background: #f8f9fa;
            font-weight: 600;
        }
"""

    def _generate_html(self, embed_content: bool = False, edit_mode: bool = False) -> str:
        """Generate interactive HTML traceability matrix from markdown source

        Args:
            embed_content: If True, embed full requirement content as JSON and include side panel
            edit_mode: If True, include edit mode UI for batch moving requirements
        """
        # Parse requirements for HTML rendering
        by_level = self._count_by_level()

        # Collect all unique topics from requirements
        all_topics = set()
        for req in self.requirements.values():
            topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem
            all_topics.add(topic)
        sorted_topics = sorted(all_topics)

        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>Requirements Traceability Matrix</title>
    <style>
        body {{
            font-family: 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
            font-size: 13px;
            line-height: 1.4;
            margin: 0;
            padding: 0;
            background: #f8f9fa;
            height: 100vh;
            overflow: hidden;
        }}
        .app-layout {{
            display: flex;
            height: 100vh;
            overflow: hidden;
        }}
        .main-content {{
            flex: 1;
            overflow-y: auto;
            padding: 15px;
            min-width: 0;
        }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }}
        h1 {{
            font-size: 20px;
            font-weight: 600;
            color: #2c3e50;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 8px;
            margin: 0 0 15px 0;
        }}
        h2 {{
            font-size: 16px;
            font-weight: 600;
            color: #34495e;
            margin: 20px 0 10px 0;
        }}
        .title-bar {{
            display: flex;
            align-items: center;
            gap: 20px;
            padding: 10px 0;
            border-bottom: 2px solid #0066cc;
            margin-bottom: 10px;
        }}
        .version-badge {{
            font-size: 10px;
            color: #6c757d;
            background: #e9ecef;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }}
        .title-bar h1 {{
            font-size: 18px;
            font-weight: 600;
            color: #2c3e50;
            margin: 0;
            border: none;
            padding: 0;
        }}
        .stats-badges {{
            display: flex;
            gap: 10px;
            margin-right: auto;
        }}
        .stat-badge {{
            padding: 4px 10px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            color: white;
        }}
        .stat-badge.prd {{ background: #0066cc; }}
        .stat-badge.ops {{ background: #fd7e14; }}
        .stat-badge.dev {{ background: #28a745; }}
        .btn-legend {{
            background: #6c757d;
            font-size: 12px;
        }}
        .btn-legend:hover {{
            background: #5a6268;
        }}
        .checkbox-label {{
            display: flex;
            align-items: center;
            gap: 4px;
            font-size: 12px;
            color: #495057;
            cursor: pointer;
            padding: 6px 10px;
            background: #e9ecef;
            border-radius: 3px;
        }}
        .checkbox-label:hover {{
            background: #dee2e6;
        }}
        .checkbox-label input {{
            cursor: pointer;
        }}
        /* Edit Mode styles */
        .edit-mode-panel {{
            background: #fff3cd;
            border: 1px solid #ffc107;
            border-radius: 4px;
            padding: 15px;
            margin: 10px 0;
        }}
        .edit-mode-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }}
        .edit-mode-title {{
            font-size: 14px;
        }}
        .edit-mode-actions {{
            display: flex;
            gap: 10px;
        }}
        .pending-moves-list {{
            max-height: 200px;
            overflow-y: auto;
            font-size: 12px;
        }}
        .pending-move-item {{
            padding: 5px 10px;
            background: white;
            border-radius: 3px;
            margin: 3px 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .edit-actions {{
            display: none;
        }}
        body.edit-mode-active .edit-actions {{
            display: flex;
            flex-direction: column;
            gap: 2px;
        }}
        .edit-btn {{
            padding: 2px 6px;
            font-size: 10px;
            cursor: pointer;
            border: 1px solid #ccc;
            border-radius: 3px;
            background: white;
            white-space: nowrap;
        }}
        .edit-btn:hover {{
            background: #e9ecef;
        }}
        .edit-btn.to-roadmap {{
            border-color: #fd7e14;
            color: #fd7e14;
        }}
        .edit-btn.from-roadmap {{
            border-color: #28a745;
            color: #28a745;
        }}
        .vscode-link {{
            font-size: 16px;
            color: #007acc;
            text-decoration: none;
            margin-left: 6px;
        }}
        .vscode-link:hover {{
            color: #005a9e;
        }}
        .dest-text {{
            font-size: 11px;
            color: #666;
            white-space: nowrap;
        }}
        .edit-btn.move-file {{
            border-color: #007bff;
            color: #007bff;
        }}
        /* Panel/card edit buttons - always visible, horizontal layout */
        .req-card-actions {{
            display: flex !important;
            flex-direction: row;
            gap: 8px;
            margin: 8px 0;
        }}
        .panel-edit-btn {{
            font-size: 11px;
            padding: 4px 8px;
        }}
        .controls {{
            margin: 15px 0;
            padding: 10px;
            background: #e9ecef;
            border-radius: 4px;
            display: flex;
            gap: 8px;
            align-items: center;
        }}
        .btn {{
            padding: 6px 12px;
            border: none;
            border-radius: 3px;
            background: #0066cc;
            color: white;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: background 0.15s;
        }}
        .btn:hover {{
            background: #0052a3;
        }}
        .btn-secondary {{
            background: #6c757d;
        }}
        .btn-secondary:hover {{
            background: #5a6268;
        }}
        .btn-secondary.active {{
            background: #0066cc;
        }}
        .btn-secondary.active:hover {{
            background: #0052a3;
        }}
        /* Toggle buttons - white when off, colored when active */
        .toggle-btn {{
            background: white;
            color: #495057;
            border: 1px solid #28a745;
        }}
        .toggle-btn:hover {{
            background: #e8f5e9;
        }}
        .toggle-btn.active {{
            background: #28a745;
            color: white;
            border: 1px solid #28a745;
        }}
        /* Edit Mode button - blue theme instead of green */
        #btnEditMode {{
            border: 1px solid #007bff;
        }}
        #btnEditMode:hover {{
            background: #e3f2fd;
        }}
        #btnEditMode.active {{
            background: #007bff;
            color: white;
            border: 1px solid #007bff;
        }}
        .req-tree {{
            margin: 15px 0;
            overflow-x: auto;
        }}
        .req-item {{
            margin: 2px 0;
            background: #ffffff;
            border-left: 3px solid #28a745;
            overflow: hidden;
        }}
        .req-item.prd {{ border-left-color: #0066cc; }}
        .req-item.ops {{ border-left-color: #fd7e14; }}
        .req-item.dev {{ border-left-color: #28a745; }}
        .req-item.deprecated {{ opacity: 0.6; }}
        .req-header-container {{
            padding: 6px 10px;
            cursor: pointer;
            user-select: none;
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .req-header-container:hover {{
            background: #f8f9fa;
        }}
        /* Indentation based on hierarchy level (20px per level) */
        .req-item[data-indent="0"] .req-header-container {{
            padding-left: 10px;
        }}
        .req-item[data-indent="1"] .req-header-container {{
            padding-left: 30px;
        }}
        .req-item[data-indent="2"] .req-header-container {{
            padding-left: 50px;
        }}
        .req-item[data-indent="3"] .req-header-container {{
            padding-left: 70px;
        }}
        .req-item[data-indent="4"] .req-header-container {{
            padding-left: 90px;
        }}
        .req-item[data-indent="5"] .req-header-container {{
            padding-left: 110px;
        }}
        /* Cap indent at level 5 for any deeper nesting */
        .req-item[data-indent="6"] .req-header-container,
        .req-item[data-indent="7"] .req-header-container,
        .req-item[data-indent="8"] .req-header-container,
        .req-item[data-indent="9"] .req-header-container {{
            padding-left: 110px;
        }}
        .collapse-icon {{
            font-size: 10px;
            color: #6c757d;
            transition: transform 0.15s;
            flex-shrink: 0;
            width: 12px;
            text-align: center;
        }}
        .collapse-icon.collapsed {{
            transform: rotate(-90deg);
        }}
        .req-content {{
            flex: 1;
            display: grid;
            /* REQ ID | Title | Level | Status | Coverage | Tests | Topic | Destination */
            grid-template-columns: 110px minmax(100px, 1fr) 45px 90px 35px 50px 180px 110px;
            align-items: center;
            gap: 6px;
            min-width: 700px;
        }}
        .req-id {{
            font-weight: 600;
            color: #0066cc;
            font-size: 12px;
            font-family: 'Consolas', 'Monaco', monospace;
        }}
        .req-header {{
            font-weight: 500;
            color: #2c3e50;
            font-size: 13px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}
        .req-level {{
            font-size: 11px;
            color: #7f8c8d;
            text-align: center;
        }}
        .req-badges {{
            display: flex;
            gap: 4px;
            align-items: center;
        }}
        .req-status {{
            font-size: 11px;
            color: #7f8c8d;
            text-align: center;
        }}
        .req-location {{
            font-size: 11px;
            color: #7f8c8d;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}
        /* Edit mode column - hidden by default, shown in edit mode */
        .edit-mode-column {{
            display: none;
        }}
        body.edit-mode-active .edit-mode-column {{
            display: block;
        }}
        .req-destination {{
            min-width: 100px;
            max-width: 150px;
            font-size: 11px;
            padding: 2px 6px;
        }}
        .req-destination:not(:empty) {{
            background: #e8f4fd;
            border-radius: 4px;
            color: #0366d6;
            font-weight: 500;
        }}
        .req-destination.to-roadmap {{
            background: #fff3cd;
            color: #856404;
        }}
        .req-destination.from-roadmap {{
            background: #d4edda;
            color: #155724;
        }}
        .req-item.impl-file {{
            border-left: 3px solid #6c757d;
            background: #f8f9fa;
        }}
        .req-item.impl-file .req-header-container {{
            cursor: default;
        }}
        .req-item.impl-file .req-header-container:hover {{
            background: #f0f0f0;
        }}
        .status-badge {{
            display: inline-block;
            padding: 2px 6px;
            border-radius: 2px;
            font-size: 10px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.3px;
        }}
        .status-active {{ background: #d4edda; color: #155724; }}
        .status-draft {{ background: #fff3cd; color: #856404; }}
        .status-deprecated {{ background: #f8d7da; color: #721c24; }}
        .status-suffix {{
            font-weight: bold;
            font-size: 12px;
            margin-left: 1px;
            cursor: help;
        }}
        .status-new {{ color: #28a745; }}  /* Green ★ for NEW */
        .status-modified {{ color: #fd7e14; }}  /* Orange ◆ for MODIFIED */
        .status-moved {{ color: #6f42c1; }}  /* Purple ↝ for MOVED (actual) */
        .status-moved-modified {{ color: #6f42c1; }}  /* Purple for MOVED+MODIFIED */
        .status-pending-move {{ color: #007bff; }}  /* Blue ⇢ for PENDING move */
        .roadmap-icon {{
            margin-left: 4px;
            font-size: 12px;
            opacity: 0.8;
        }}
        .conflict-icon {{
            margin-right: 4px;
            font-size: 14px;
            color: #dc3545;
        }}
        .conflict-item {{
            background-color: rgba(220, 53, 69, 0.1) !important;
            border-left: 3px solid #dc3545 !important;
        }}
        .conflict-item:hover {{
            background-color: rgba(220, 53, 69, 0.15) !important;
        }}
        .cycle-icon {{
            margin-right: 4px;
            font-size: 14px;
            color: #fd7e14;
        }}
        .cycle-item {{
            background-color: rgba(253, 126, 20, 0.1) !important;
            border-left: 3px solid #fd7e14 !important;
        }}
        .cycle-item:hover {{
            background-color: rgba(253, 126, 20, 0.15) !important;
        }}
        .req-coverage {{
            min-width: 30px;
            max-width: 40px;
            text-align: center;
            font-size: 14px;
        }}
        .test-badge {{
            display: inline-block;
            padding: 2px 6px;
            border-radius: 2px;
            font-size: 10px;
            font-weight: 600;
        }}
        .test-passed {{ background: #d4edda; color: #155724; }}
        .test-failed {{ background: #f8d7da; color: #721c24; }}
        .test-not-tested {{ background: #fff3cd; color: #856404; }}
        .test-error {{ background: #f5c2c7; color: #842029; }}
        .test-skipped {{ background: #e2e3e5; color: #41464b; }}
        .coverage-badge {{
            display: inline-block;
            font-size: 14px;
            cursor: help;
        }}
        /* Collapsed items hidden via class */
        .req-item.collapsed-by-parent {{
            display: none;
        }}
        .filter-header {{
            display: grid;
            /* REQ ID | Title | Level | Status | Coverage | Tests | Topic | Destination */
            grid-template-columns: 110px minmax(100px, 1fr) 45px 90px 35px 50px 180px 110px;
            align-items: center;
            gap: 6px;
            padding: 8px 10px 8px 42px;
            background: #e9ecef;
            border-bottom: 2px solid #dee2e6;
            margin-bottom: 8px;
            position: sticky;
            top: 0;
            z-index: 10;
            min-width: 700px;
        }}
        .filter-column {{
            display: flex;
            flex-direction: column;
            gap: 4px;
        }}
        .filter-column-multi .filter-row {{
            display: flex;
            gap: 4px;
        }}
        .filter-column-multi .filter-row select {{
            flex: 1;
            min-width: 0;
        }}
        .filter-label {{
            font-size: 10px;
            font-weight: 600;
            color: #495057;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .filter-column input, .filter-column select {{
            padding: 3px 6px;
            border: 1px solid #ced4da;
            border-radius: 2px;
            font-size: 11px;
            background: white;
            width: 100%;
            box-sizing: border-box;
        }}
        .filter-column input::placeholder {{
            color: #adb5bd;
            font-size: 10px;
        }}
        .filter-controls {{
            margin: 15px 0;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 4px;
            display: flex;
            gap: 10px;
            align-items: center;
        }}
        .filter-stats {{
            margin-left: auto;
            font-size: 11px;
            color: #6c757d;
            font-weight: 500;
        }}
        .view-toggle {{
            display: flex;
            gap: 0;
            margin-right: 15px;
            border-radius: 4px;
            overflow: hidden;
        }}
        .view-btn {{
            border-radius: 0;
            border: 1px solid #0066cc;
            background: white;
            color: #0066cc;
        }}
        .view-btn:first-child {{
            border-radius: 4px 0 0 4px;
        }}
        .view-btn:last-child {{
            border-radius: 0 4px 4px 0;
            border-left: none;
        }}
        .view-btn.active {{
            background: #0066cc;
            color: white;
        }}
        .view-btn:hover:not(.active) {{
            background: #e6f0ff;
        }}
        /* Flat view: force all items to indent 0 */
        .req-tree.flat-view .req-item .req-header-container {{
            padding-left: 10px !important;
        }}
        /* Hierarchical view: hide non-root items initially */
        .req-tree.hierarchy-view .req-item:not([data-is-root="true"]) {{
            display: none;
        }}
        .req-tree.hierarchy-view .req-item[data-is-root="true"] {{
            display: block;
        }}
        /* But show children of expanded roots */
        .req-tree.hierarchy-view .req-item.hierarchy-visible {{
            display: block;
        }}
        .req-tree.hierarchy-view .req-item.hierarchy-visible.collapsed-by-parent {{
            display: none;
        }}
        .req-item.filtered-out {{
            display: none !important;
        }}
        .level-legend {{
            display: flex;
            gap: 15px;
            margin: 15px 0;
            padding: 8px 12px;
            background: #f8f9fa;
            border-radius: 4px;
            font-size: 12px;
        }}
        .legend-item {{
            display: flex;
            align-items: center;
            gap: 6px;
        }}
        .legend-color {{
            width: 16px;
            height: 16px;
            border-radius: 2px;
        }}
        .legend-color.prd {{ background: #0066cc; }}
        .legend-color.ops {{ background: #fd7e14; }}
        .legend-color.dev {{ background: #28a745; }}
        {self._generate_side_panel_css() if embed_content else ''}
        {self._generate_code_viewer_css() if embed_content else ''}
        {self._generate_legend_modal_css() if embed_content else ''}
        {self._generate_file_picker_modal_css()}
    </style>
    {('<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/vs2015.min.css">' + chr(10) + '    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>' + chr(10) + '    <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"></script>') if embed_content else ''}
</head>
<body>
<div class="app-layout">
    <div class="main-content">
    <div class="container">
        <div class="title-bar">
            <h1>Requirements Traceability</h1>
            <div class="stats-badges">
                <span class="stat-badge prd" id="badgePRD" data-active="{by_level['active']['PRD']}" data-all="{by_level['all']['PRD']}">PRD: {by_level['active']['PRD']}</span>
                <span class="stat-badge ops" id="badgeOPS" data-active="{by_level['active']['OPS']}" data-all="{by_level['all']['OPS']}">OPS: {by_level['active']['OPS']}</span>
                <span class="stat-badge dev" id="badgeDEV" data-active="{by_level['active']['DEV']}" data-all="{by_level['all']['DEV']}">DEV: {by_level['active']['DEV']}</span>
            </div>
            <span class="version-badge">v{self.VERSION}</span>
            <button class="btn btn-legend" onclick="openLegendModal()" title="Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}">ℹ️ Legend</button>
        </div>

        <div class="filter-controls">
            <div class="view-toggle">
                <button class="btn view-btn active" id="btnFlatView" onclick="switchView('flat')">Flat View</button>
                <button class="btn view-btn" id="btnHierarchyView" onclick="switchView('hierarchy')">Hierarchical View</button>
                <button class="btn view-btn" id="btnUncommittedView" onclick="switchView('uncommitted')">Uncommitted</button>
                <button class="btn view-btn" id="btnBranchView" onclick="switchView('branch')">Changed vs Main</button>
            </div>
            <button class="btn toggle-btn" id="btnLeafOnly" onclick="toggleLeafOnly()">🍃 Leaf Only</button>
            <label class="checkbox-label" title="Include deprecated requirements in counts and views">
                <input type="checkbox" id="chkIncludeDeprecated" onchange="toggleIncludeDeprecated()">
                Include deprecated
            </label>
            <label class="checkbox-label" title="Include requirements from spec/roadmap/ directory">
                <input type="checkbox" id="chkIncludeRoadmap" onchange="toggleIncludeRoadmap()">
                Include roadmap
            </label>
            <button class="btn btn-secondary" id="btnExpandAll" onclick="expandAll()">▼ Expand All</button>
            <button class="btn btn-secondary" id="btnCollapseAll" onclick="collapseAll()">▶ Collapse All</button>
            <button class="btn btn-secondary" onclick="clearFilters()">Clear</button>
            <span class="filter-stats" id="filterStats"></span>
            {'<span style="margin-left: 20px; border-left: 1px solid #ccc; padding-left: 20px;"><button class="btn toggle-btn" id="btnEditMode" onclick="toggleEditMode()">✏️ Edit Mode</button></span>' if edit_mode else ''}
        </div>

        {'''<!-- Edit Mode Panel (hidden by default) -->
        <div id="editModePanel" class="edit-mode-panel" style="display: none;">
            <div class="edit-mode-header">
                <div class="edit-mode-title">
                    <strong>📝 Edit Mode</strong> - Select requirements to move
                    <span id="pendingChangesCount" class="badge" style="margin-left: 10px;">0 pending</span>
                </div>
                <div class="edit-mode-actions">
                    <button class="btn btn-secondary" onclick="clearPendingMoves()">Clear Selection</button>
                    <button class="btn" id="btnExportMoves" onclick="generateMoveScript()" disabled>Export Moves JSON</button>
                </div>
            </div>
            <div class="pending-moves-section">
                <div class="pending-moves-header" onclick="togglePendingMoves()" style="cursor: pointer; user-select: none; display: flex; align-items: center; margin-bottom: 8px;">
                    <span id="pendingMovesToggle" style="margin-right: 6px; font-size: 12px;">▼</span>
                    <strong style="font-size: 12px;">Pending Moves</strong>
                </div>
                <div id="pendingMovesList" class="pending-moves-list"></div>
            </div>
        </div>''' if edit_mode else ''}

        <h2 id="treeTitle">Traceability Tree - Flat View</h2>

        <div class="filter-header">
            <div class="filter-column">
                <div class="filter-label">REQ ID</div>
                <input type="text" id="filterReqId" placeholder="Filter..." oninput="applyFilters()">
            </div>
            <div class="filter-column">
                <div class="filter-label">Title</div>
                <input type="text" id="filterTitle" placeholder="Search title..." oninput="applyFilters()">
            </div>
            <div class="filter-column">
                <div class="filter-label">Level</div>
                <select id="filterLevel" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="PRD">PRD</option>
                    <option value="OPS">OPS</option>
                    <option value="DEV">DEV</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Status</div>
                <select id="filterStatus" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="Active">Active</option>
                    <option value="Draft">Draft</option>
                    <option value="Deprecated">Deprecated</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Cov</div>
                <select id="filterCoverage" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="full">●</option>
                    <option value="partial">◐</option>
                    <option value="none">○</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Tests</div>
                <select id="filterTests" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="tested">✅ Tested</option>
                    <option value="not-tested">⚡ Not Tested</option>
                    <option value="failed">❌ Failed</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Topic</div>
                <select id="filterTopic" onchange="applyFilters()">
                    <option value="">All</option>
"""

        # Add topic options dynamically
        for topic in sorted_topics:
            html += f'                    <option value="{topic}">{topic}</option>\n'

        html += """                </select>
            </div>
"""
        # Add edit mode column header only if edit mode is enabled
        if edit_mode:
            html += """            <div class="filter-column edit-mode-column" style="display: none;">
                <div class="filter-label">Destination</div>
            </div>
"""
        html += """        </div>

        <div class="req-tree" id="reqTree">
"""

        # Add requirements and implementation files as flat list (hierarchy via indentation)
        flat_list = self._build_flat_requirement_list()
        for item_data in flat_list:
            html += self._format_item_flat_html(item_data, embed_content=embed_content, edit_mode=edit_mode)

        html += """        </div>
    </div>
    </div>
"""

        # Add side panel HTML if embedded mode
        if embed_content:
            html += """
    <div id="req-panel" class="side-panel hidden" style="position: relative;">
        <div class="resize-handle" id="resizeHandle"></div>
        <div class="panel-header">
            <span>Requirements</span>
            <button onclick="closeAllCards()">Close All</button>
        </div>
        <div id="req-card-stack"></div>
    </div>
"""

        # Add JSON data script if embedded mode
        if embed_content:
            json_data = self._generate_req_json_data()
            # Properly escape JSON for HTML embedding
            import html as html_module
            escaped_json = html_module.escape(json_data)
            repo_root_str = str(self.repo_root.resolve())
            html += f"""
    <script id="req-content-data" type="application/json">
{json_data}
    </script>
    <script>
        // Load REQ content data into global scope
        window.REQ_CONTENT_DATA = JSON.parse(document.getElementById('req-content-data').textContent);
        // Repository root for VS Code links (absolute path required for vscode:// protocol)
        // Note: VS Code links only work on the machine where this file was generated
        window.REPO_ROOT = '{repo_root_str}';
    </script>
"""

        html += """
    <script>
        // Track collapsed state for each requirement instance
        const collapsedInstances = new Set();

        // Toggle a single requirement instance's children
        function toggleRequirement(element) {
            const item = element.closest('.req-item');
            const instanceId = item.dataset.instanceId;
            const icon = element.querySelector('.collapse-icon');

            if (!icon.textContent) return; // No children to collapse

            const isExpanding = collapsedInstances.has(instanceId);

            if (isExpanding) {
                // Expand
                collapsedInstances.delete(instanceId);
                icon.classList.remove('collapsed');
            } else {
                // Collapse
                collapsedInstances.add(instanceId);
                icon.classList.add('collapsed');
            }

            // Use different behavior based on view mode
            if (currentView === 'hierarchy') {
                toggleRequirementHierarchy(instanceId, isExpanding);
            } else {
                if (isExpanding) {
                    showDescendants(instanceId);
                } else {
                    hideDescendants(instanceId);
                }
            }
            updateExpandCollapseButtons();
        }

        // Hide all descendants of a requirement instance
        function hideDescendants(parentInstanceId) {
            // Hide child requirements
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.add('collapsed-by-parent');
                // Recursively hide descendants' descendants
                hideDescendants(child.dataset.instanceId);
            });
            // Note: impl-files sections are always visible as part of their requirement row
            // They are not affected by collapse state - only child requirements are hidden
        }

        // Show immediate children of a requirement instance only (not grandchildren)
        function showDescendants(parentInstanceId) {
            // Show child requirements
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.remove('collapsed-by-parent');
                // Do NOT recursively show grandchildren - they stay hidden until their parent is expanded
            });
            // Note: impl-files sections are always visible as part of their requirement row
        }

        // Update expand/collapse button states based on current state
        function updateExpandCollapseButtons() {
            const btnExpand = document.getElementById('btnExpandAll');
            const btnCollapse = document.getElementById('btnCollapseAll');

            // Count visible items with children (that can be expanded/collapsed)
            let expandableCount = 0;
            let expandedCount = 0;
            let collapsedCount = 0;

            document.querySelectorAll('.req-item:not(.filtered-out)').forEach(item => {
                const icon = item.querySelector('.collapse-icon');
                if (icon && icon.textContent) {  // Has children
                    expandableCount++;
                    if (icon.classList.contains('collapsed')) {
                        collapsedCount++;
                    } else {
                        expandedCount++;
                    }
                }
            });

            // Update Expand button
            if (expandableCount > 0 && expandedCount === expandableCount) {
                btnExpand.classList.add('active');
                btnExpand.textContent = '▼ All Expanded';
            } else {
                btnExpand.classList.remove('active');
                btnExpand.textContent = '▼ Expand All';
            }

            // Update Collapse button
            if (expandableCount > 0 && collapsedCount === expandableCount) {
                btnCollapse.classList.add('active');
                btnCollapse.textContent = '▶ All Collapsed';
            } else {
                btnCollapse.classList.remove('active');
                btnCollapse.textContent = '▶ Collapse All';
            }
        }

        // Expand all requirements
        function expandAll() {
            collapsedInstances.clear();
            const isHierarchyView = currentView === 'hierarchy';
            document.querySelectorAll('.req-item').forEach(item => {
                item.classList.remove('collapsed-by-parent');
                // In hierarchy view, add hierarchy-visible to non-root items
                if (isHierarchyView && item.dataset.isRoot !== 'true') {
                    item.classList.add('hierarchy-visible');
                }
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
            updateExpandCollapseButtons();
        }

        // Collapse all requirements
        function collapseAll() {
            const isHierarchyView = currentView === 'hierarchy';
            document.querySelectorAll('.req-item').forEach(item => {
                const icon = item.querySelector('.collapse-icon');
                // In hierarchy view, remove hierarchy-visible from non-root items
                if (isHierarchyView && item.dataset.isRoot !== 'true') {
                    item.classList.remove('hierarchy-visible');
                    item.classList.add('collapsed-by-parent');
                }
                // Collapse items that have children (indicated by collapse icon text)
                if (icon && icon.textContent) {
                    collapsedInstances.add(item.dataset.instanceId);
                    hideDescendants(item.dataset.instanceId);
                    icon.classList.add('collapsed');
                }
            });
            updateExpandCollapseButtons();
        }

        // View mode state
        let currentView = 'flat';

        // Switch between flat, hierarchical, uncommitted, and branch views
        function switchView(viewMode) {
            currentView = viewMode;
            const reqTree = document.getElementById('reqTree');
            const btnFlat = document.getElementById('btnFlatView');
            const btnHierarchy = document.getElementById('btnHierarchyView');
            const btnUncommitted = document.getElementById('btnUncommittedView');
            const btnBranch = document.getElementById('btnBranchView');
            const treeTitle = document.getElementById('treeTitle');

            // Reset all button states
            btnFlat.classList.remove('active');
            btnHierarchy.classList.remove('active');
            btnUncommitted.classList.remove('active');
            btnBranch.classList.remove('active');
            reqTree.classList.remove('hierarchy-view');
            reqTree.classList.remove('flat-view');

            if (viewMode === 'hierarchy') {
                reqTree.classList.add('hierarchy-view');
                btnHierarchy.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Hierarchical View';

                // Reset all items and collapse state for hierarchy view
                collapsedInstances.clear();
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('collapsed-by-parent');
                    item.classList.remove('hierarchy-visible');
                    // Collapse all root items initially
                    const icon = item.querySelector('.collapse-icon');
                    if (icon && icon.textContent && item.dataset.isRoot === 'true') {
                        collapsedInstances.add(item.dataset.instanceId);
                        icon.classList.add('collapsed');
                    }
                });
            } else if (viewMode === 'uncommitted') {
                btnUncommitted.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Uncommitted Changes';

                // Reset visibility classes
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                });

                collapseAll();
            } else if (viewMode === 'branch') {
                btnBranch.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Changed vs Main';

                // Reset visibility classes
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                });

                collapseAll();
            } else {
                btnFlat.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Flat View';
                reqTree.classList.add('flat-view');

                // Reset visibility classes - show all items in flat view
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                    item.classList.remove('collapsed-by-parent');
                });

                // Flat view CSS handles showing all items at indent 0
            }

            applyFilters();
        }

        // Modified toggle for hierarchy view
        function toggleRequirementHierarchy(parentInstanceId, isExpanding) {
            // Show/hide immediate children in hierarchy view
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                if (isExpanding) {
                    child.classList.add('hierarchy-visible');
                    child.classList.remove('collapsed-by-parent');
                } else {
                    child.classList.remove('hierarchy-visible');
                    child.classList.add('collapsed-by-parent');
                    // Also collapse any expanded children
                    const childIcon = child.querySelector('.collapse-icon');
                    if (childIcon && childIcon.textContent) {
                        collapsedInstances.add(child.dataset.instanceId);
                        childIcon.classList.add('collapsed');
                        toggleRequirementHierarchy(child.dataset.instanceId, false);
                    }
                }
            });
        }

        // Apply filters (simple flat filtering with duplicate detection)
        function applyFilters() {
            const reqIdFilter = document.getElementById('filterReqId').value.toLowerCase().trim();
            const titleFilter = document.getElementById('filterTitle').value.toLowerCase().trim();
            const levelFilter = document.getElementById('filterLevel').value;
            const statusFilter = document.getElementById('filterStatus').value;
            const topicFilter = document.getElementById('filterTopic')?.value.toLowerCase().trim() || '';
            const testFilter = document.getElementById('filterTests')?.value || '';
            const coverageFilter = document.getElementById('filterCoverage')?.value || '';
            const isLeafOnly = typeof leafOnlyActive !== 'undefined' && leafOnlyActive;
            const includeDeprecated = document.getElementById('chkIncludeDeprecated')?.checked || false;

            // Check if any filter is active (modified views count as filters)
            const isUncommittedView = currentView === 'uncommitted';
            const isBranchView = currentView === 'branch';
            const isModifiedView = isUncommittedView || isBranchView;
            const anyFilterActive = reqIdFilter || titleFilter || levelFilter || statusFilter || topicFilter || testFilter || coverageFilter || isLeafOnly || isModifiedView;

            let visibleCount = 0;
            const seenReqIds = new Set();  // Track which req IDs we've already shown
            const seenVisibleReqIds = new Set();  // Track visible unique req IDs for count
            const allReqIds = new Set();  // Track all unique req IDs for total count

            // Simple iteration: show/hide each item based on filters
            document.querySelectorAll('.req-item').forEach(item => {
                const reqId = item.dataset.reqId ? item.dataset.reqId.toLowerCase() : '';
                const isImplFile = item.classList.contains('impl-file');
                const status = item.dataset.status;

                // Count unique requirements (not impl files, not duplicates)
                // When includeDeprecated is false, don't count deprecated in total
                if (!isImplFile && reqId) {
                    if (includeDeprecated || status !== 'Deprecated') {
                        allReqIds.add(reqId);
                    }
                }
                const level = item.dataset.level;
                const topic = item.dataset.topic ? item.dataset.topic.toLowerCase() : '';
                const title = item.dataset.title ? item.dataset.title.toLowerCase() : '';
                const isUncommitted = item.dataset.uncommitted === 'true';
                const isBranchChanged = item.dataset.branchChanged === 'true';

                let matches = true;

                // Uncommitted view: only show requirements with uncommitted changes
                if (isUncommittedView) {
                    if (isImplFile) {
                        const parentId = item.dataset.parentInstanceId;
                        const parent = document.querySelector(`[data-instance-id="${parentId}"]`);
                        if (!parent || parent.dataset.uncommitted !== 'true') {
                            matches = false;
                        }
                    } else if (!isUncommitted) {
                        matches = false;
                    }
                }

                // Branch view: only show requirements changed vs main
                if (isBranchView) {
                    if (isImplFile) {
                        const parentId = item.dataset.parentInstanceId;
                        const parent = document.querySelector(`[data-instance-id="${parentId}"]`);
                        if (!parent || parent.dataset.branchChanged !== 'true') {
                            matches = false;
                        }
                    } else if (!isBranchChanged) {
                        matches = false;
                    }
                }

                // Apply all filters
                if (reqIdFilter && !reqId.includes(reqIdFilter)) matches = false;
                if (titleFilter && !title.includes(titleFilter)) matches = false;
                if (levelFilter && level !== levelFilter) matches = false;
                if (statusFilter && status !== statusFilter) matches = false;

                // Topic filter: matches exact topic or hierarchical sub-topics
                // e.g., "security" matches "security", "security-RBAC", "security-RLS"
                if (topicFilter && topic !== topicFilter && !topic.startsWith(topicFilter + '-')) {
                    matches = false;
                }

                // Test filter: filter by test status
                if (testFilter && matches) {
                    const testStatus = item.dataset.testStatus || 'not-tested';
                    if (testFilter !== testStatus) {
                        matches = false;
                    }
                }

                // Coverage filter: filter by implementation coverage
                if (coverageFilter && matches) {
                    const coverage = item.dataset.coverage || 'none';
                    if (coverageFilter !== coverage) {
                        matches = false;
                    }
                }

                // Leaf-only filter: show only requirements without children
                if (isLeafOnly && matches && !isImplFile) {
                    const hasChildren = item.dataset.hasChildren === 'true';
                    if (hasChildren) {
                        matches = false;
                    }
                }

                // Deprecated filter: hide deprecated unless checkbox is checked
                if (!includeDeprecated && matches && !isImplFile) {
                    if (status === 'Deprecated') {
                        matches = false;
                    }
                }

                // Roadmap filter: hide roadmap requirements unless checkbox is checked
                // Exception: conflict and cycle items are always shown since they need attention
                const includeRoadmap = document.getElementById('chkIncludeRoadmap')?.checked || false;
                if (!includeRoadmap && matches && !isImplFile) {
                    const isRoadmap = item.dataset.roadmap === 'true';
                    const isConflict = item.dataset.conflict === 'true';
                    const isCycle = item.dataset.cycle === 'true';
                    if (isRoadmap && !isConflict && !isCycle) {
                        matches = false;
                    }
                }

                // Check for duplicates: if filtering and we've already shown this req ID, hide this occurrence
                if (matches && anyFilterActive && !isImplFile && seenReqIds.has(reqId)) {
                    matches = false;  // Hide duplicate
                }

                // Simple show/hide - no hierarchy complexity!
                if (matches) {
                    item.classList.remove('filtered-out');
                    // If any filter is active, ignore collapse state and show matching items
                    if (anyFilterActive) {
                        item.classList.remove('collapsed-by-parent');
                        if (!isImplFile) seenReqIds.add(reqId);  // Mark this req ID as shown
                    }
                    // Count visible unique requirements (not impl files, not duplicates)
                    if (!isImplFile && reqId && !seenVisibleReqIds.has(reqId)) {
                        seenVisibleReqIds.add(reqId);
                        visibleCount++;
                    }
                } else {
                    item.classList.add('filtered-out');
                }
            });

            // Update stats with unique requirement counts
            const totalCount = allReqIds.size;
            let statsText;
            if (isUncommittedView) {
                statsText = `Showing ${visibleCount} uncommitted requirements`;
            } else if (isBranchView) {
                statsText = `Showing ${visibleCount} requirements changed vs main`;
            } else {
                statsText = `Showing ${visibleCount} of ${totalCount} requirements`;
            }
            document.getElementById('filterStats').textContent = statsText;
            updateExpandCollapseButtons();
        }

        // Clear all filters
        function clearFilters() {
            document.getElementById('filterReqId').value = '';
            document.getElementById('filterTitle').value = '';
            document.getElementById('filterLevel').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('filterTopic').value = '';
            document.getElementById('filterTests').value = '';
            document.getElementById('filterCoverage').value = '';
            // Reset leaf-only toggle
            leafOnlyActive = false;
            document.getElementById('btnLeafOnly').classList.remove('active');
            // Reset include deprecated checkbox and update badge counts
            document.getElementById('chkIncludeDeprecated').checked = false;
            // Reset include roadmap checkbox
            document.getElementById('chkIncludeRoadmap').checked = false;
            toggleIncludeDeprecated();  // This will update badges and call applyFilters
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            // Start with flat view - show all unique requirements at indent 0
            switchView('flat');
        });
"""

        # Add side panel JavaScript functions if embedded mode
        if embed_content:
            html += self._generate_side_panel_js()

        html += """
    </script>
"""
        # Add file picker modal (always needed for Edit Mode)
        html += self._generate_file_picker_modal_html()

        # Add code viewer modal if embedded mode
        if embed_content:
            html += self._generate_code_viewer_html()
            html += self._generate_legend_modal_html()

        html += """
</div>
</body>
</html>
"""
        return html

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

