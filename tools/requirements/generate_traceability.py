#!/usr/bin/env python3
"""
Requirements Traceability Matrix Generator

Generates traceability matrix showing relationships between requirements
at different levels (PRD -> Ops -> Dev).

Scans both specification files and implementation files:
- spec/*.md: Requirement definitions
- database/*.sql: Database implementation
- apps/**/*.dart: Flutter apps (future)
- sponsor/{name}/**/*: Sponsor-specific implementations

Multi-Sponsor Support (Phase 3):
- Core mode: Scan only core directories (exclude /sponsor/)
- Sponsor mode: Scan specific sponsor + core directories
- Combined mode: Scan all directories (core + all sponsors)
- Supports sponsor-specific REQ IDs: REQ-{SPONSOR}-{p|o|d}NNNNN (e.g., REQ-CAL-d00001)

Output formats:
- HTML: Interactive web page with collapsible hierarchy (enhanced!)
- Markdown: Documentation-friendly format
- CSV: Spreadsheet import

Features:
- Collapsible requirement hierarchy in HTML view
- Expand/collapse all controls
- Color-coded by requirement level (PRD/Ops/Dev)
- Status badges (Active/Draft/Deprecated)
- Implementation file tracking (which files implement which requirements)
- Markdown source ensures HTML consistency
- Sponsor-aware directory scanning and filtering
"""

import re
import sys
import csv
import json
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime

# Import shared parser
from requirement_parser import RequirementParser, Requirement as BaseRequirement

@dataclass
class TestInfo:
    """Represents test coverage for a requirement"""
    test_count: int = 0
    manual_test_count: int = 0
    test_status: str = "not_tested"  # not_tested, passed, failed, error, skipped
    test_details: List[Dict] = field(default_factory=list)
    notes: str = ""

@dataclass
class TraceabilityRequirement:
    """Extended requirement with traceability-specific fields"""
    id: str
    title: str
    level: str
    implements: List[str]
    status: str
    file_path: Path
    line_number: int
    body: str = ''
    rationale: str = ''
    test_info: Optional[TestInfo] = None
    implementation_files: List[Tuple[str, int]] = field(default_factory=list)

    @classmethod
    def from_base(cls, base_req: BaseRequirement) -> 'TraceabilityRequirement':
        """Create TraceabilityRequirement from shared parser Requirement"""
        # Map level to uppercase for consistency
        level_map = {'PRD': 'PRD', 'Ops': 'OPS', 'Dev': 'DEV'}
        return cls(
            id=base_req.id,
            title=base_req.title,
            level=level_map.get(base_req.level, base_req.level),
            implements=base_req.implements,
            status=base_req.status,
            file_path=base_req.file_path,
            line_number=base_req.line_number,
            body=base_req.body,
            rationale=base_req.rationale
        )


# Alias for backward compatibility within this file
Requirement = TraceabilityRequirement


class TraceabilityGenerator:
    """Generates traceability matrices"""

    # Map parsed levels to uppercase for consistency
    LEVEL_MAP = {
        'PRD': 'PRD',
        'Ops': 'OPS',
        'Dev': 'DEV'
    }

    def __init__(self, spec_dir: Path, test_mapping_file: Optional[Path] = None, impl_dirs: Optional[List[Path]] = None,
                 sponsor: Optional[str] = None, mode: str = 'core', repo_root: Optional[Path] = None):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}
        self.test_mapping_file = test_mapping_file
        self.test_data: Dict[str, TestInfo] = {}
        self.impl_dirs = impl_dirs or []  # Directories containing implementation files
        self.sponsor = sponsor  # Sponsor name (e.g., 'callisto', 'titan')
        self.mode = mode  # Report mode: 'core', 'sponsor', 'combined'
        self.repo_root = repo_root or spec_dir.parent  # Repository root for relative path calculation
        self._base_path = ''  # Relative path from output file to repo root (set during generate)

    def generate(self, format: str = 'markdown', output_file: Path = None, embed_content: bool = False):
        """Generate traceability matrix in specified format

        Args:
            format: Output format ('markdown', 'html', 'csv')
            output_file: Path to write output (default: traceability_matrix.{ext})
            embed_content: If True, embed full requirement content in HTML for portable viewing
        """
        print(f"🔍 Scanning {self.spec_dir} for requirements...")
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return

        print(f"📋 Found {len(self.requirements)} requirements")

        # Scan implementation files for requirement references
        if self.impl_dirs:
            print(f"🔎 Scanning implementation files...")
            self._scan_implementation_files()

        # Load test data if mapping file provided
        if self.test_mapping_file and self.test_mapping_file.exists():
            print(f"📊 Loading test results from {self.test_mapping_file}...")
            self._load_test_data()
        else:
            print("⚠️  No test mapping file provided - all requirements marked as 'not tested'")
        print(f"📝 Generating {format.upper()} traceability matrix...")

        if format == 'html':
            ext = '.html'
        elif format == 'csv':
            ext = '.csv'
        else:
            ext = '.md'

        # Determine output path
        if output_file is None:
            output_file = Path(f'traceability_matrix{ext}')

        # Calculate relative path from output file to repo root for links
        self._calculate_base_path(output_file)

        if format == 'html':
            content = self._generate_html(embed_content=embed_content)
        elif format == 'csv':
            content = self._generate_csv()
        else:
            content = self._generate_markdown()

        output_file.write_text(content)
        print(f"✅ Traceability matrix written to: {output_file}")

    def _calculate_base_path(self, output_file: Path):
        """Calculate relative path from output file location to repo root.

        This ensures links work correctly regardless of where the output file is placed.
        For example:
        - Output at repo_root/my.html -> base_path = '' (links are 'spec/file.md')
        - Output at repo_root/docs/report.html -> base_path = '../' (links are '../spec/file.md')
        - Output at ~/my.html (outside repo) -> base_path = 'file:///abs/path/' (absolute URLs)
        """
        try:
            output_dir = output_file.resolve().parent
            repo_root = self.repo_root.resolve()

            # Check if output is within repo
            try:
                rel_path = output_dir.relative_to(repo_root)
                # Count directory levels from output to repo root
                depth = len(rel_path.parts)
                if depth == 0:
                    self._base_path = ''  # Output is at repo root
                else:
                    self._base_path = '../' * depth
            except ValueError:
                # Output is outside repo - use absolute file:// URLs
                self._base_path = f'file://{repo_root}/'
        except Exception:
            # Fallback to relative path from docs/ (legacy behavior)
            self._base_path = '../'

    def _parse_requirements(self):
        """Parse all requirements from spec files using shared parser"""
        parser = RequirementParser(self.spec_dir)
        result = parser.parse_all()

        # Convert base requirements to traceability requirements
        for req_id, base_req in result.requirements.items():
            self.requirements[req_id] = TraceabilityRequirement.from_base(base_req)

        # Log any parse errors (but don't fail - traceability is best-effort)
        if result.errors:
            for error in result.errors:
                print(f"   ⚠️  Parse warning: {error}")

    def _scan_implementation_files(self):
        """Scan implementation files for requirement references"""
        # Pattern to match requirement references in code comments
        # Matches: REQ-p00001, REQ-o00042, REQ-d00156, REQ-CAL-d00001
        req_ref_pattern = re.compile(r'REQ-(?:([A-Z]+)-)?([pod]\d{5})')

        total_files_scanned = 0
        total_refs_found = 0

        for impl_dir in self.impl_dirs:
            if not impl_dir.exists():
                print(f"   ⚠️  Implementation directory not found: {impl_dir}")
                continue

            # Apply mode-based filtering
            if self._should_skip_directory(impl_dir):
                print(f"   ⏭️  Skipping directory (mode={self.mode}): {impl_dir}")
                continue

            # Determine file patterns based on directory
            if impl_dir.name == 'database':
                patterns = ['*.sql']
            elif impl_dir.name in ['diary_app', 'portal_app']:
                patterns = ['**/*.dart']
            else:
                # Default: scan common code file types
                patterns = ['**/*.dart', '**/*.sql', '**/*.py', '**/*.js', '**/*.ts']

            for pattern in patterns:
                for file_path in impl_dir.glob(pattern):
                    if file_path.is_file():
                        # Skip files in sponsor directories if not in the right mode
                        if self._should_skip_file(file_path):
                            continue

                        total_files_scanned += 1
                        refs = self._scan_file_for_requirements(file_path, req_ref_pattern)
                        total_refs_found += len(refs)

        print(f"   ✅ Scanned {total_files_scanned} implementation files")
        print(f"   📌 Found {total_refs_found} requirement references")

    def _scan_file_for_requirements(self, file_path: Path, pattern: re.Pattern) -> Set[str]:
        """Scan a single implementation file for requirement references"""
        try:
            content = file_path.read_text(encoding='utf-8')
        except (UnicodeDecodeError, PermissionError):
            # Skip files that can't be read
            return set()

        # Find all requirement IDs referenced in this file with their line numbers
        referenced_reqs = set()
        rel_path = file_path.relative_to(self.repo_root)  # Relative to repo root

        for match in pattern.finditer(content):
            sponsor_prefix = match.group(1)  # May be None for core requirements
            req_id_core = match.group(2)  # The core part (e.g., 'd00027')

            # Build full requirement ID (with sponsor prefix if present)
            if sponsor_prefix:
                req_id = f"{sponsor_prefix}-{req_id_core}"
            else:
                req_id = req_id_core

            referenced_reqs.add(req_id)

            # Calculate line number from match position
            line_num = content[:match.start()].count('\n') + 1

            # Add (file_path, line_number) tuple to requirement's implementation_files
            if req_id in self.requirements:
                impl_entry = (str(rel_path), line_num)
                # Avoid duplicates (same file, same line)
                if impl_entry not in self.requirements[req_id].implementation_files:
                    self.requirements[req_id].implementation_files.append(impl_entry)

        return referenced_reqs

    def _should_skip_directory(self, dir_path: Path) -> bool:
        """Check if a directory should be skipped based on mode"""
        # Check if directory is under /sponsor/
        try:
            # Try to get relative path from repo root
            parts = dir_path.parts
            if 'sponsor' in parts:
                sponsor_idx = parts.index('sponsor')
                if sponsor_idx + 1 < len(parts):
                    dir_sponsor = parts[sponsor_idx + 1]

                    # In core mode, skip all sponsor directories
                    if self.mode == 'core':
                        return True

                    # In sponsor mode, skip sponsor directories that don't match our sponsor
                    if self.mode == 'sponsor' and self.sponsor and dir_sponsor != self.sponsor:
                        return True

            return False
        except (ValueError, IndexError):
            return False

    def _should_skip_file(self, file_path: Path) -> bool:
        """Check if a file should be skipped based on mode"""
        # Check if file is under /sponsor/
        try:
            parts = file_path.parts
            if 'sponsor' in parts:
                sponsor_idx = parts.index('sponsor')
                if sponsor_idx + 1 < len(parts):
                    file_sponsor = parts[sponsor_idx + 1]

                    # In core mode, skip all sponsor files
                    if self.mode == 'core':
                        return True

                    # In sponsor mode, skip sponsor files that don't match our sponsor
                    if self.mode == 'sponsor' and self.sponsor and file_sponsor != self.sponsor:
                        return True

            return False
        except (ValueError, IndexError):
            return False

    def _generate_legend_markdown(self) -> str:
        """Generate markdown legend section"""
        return """## Legend

**Requirement Status:**
- ✅ Active requirement
- 🚧 Draft requirement
- ⚠️ Deprecated requirement

**Traceability:**
- 🔗 Has implementation file(s)
- ○ No implementation found

**Interactive (HTML only):**
- ▼ Expandable (has child requirements)
- ▶ Collapsed (click to expand)
"""

    def _generate_markdown(self) -> str:
        """Generate markdown traceability matrix"""
        lines = []
        lines.append("# Requirements Traceability Matrix")
        lines.append(f"\n**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"**Total Requirements**: {len(self.requirements)}\n")

        # Summary by level
        by_level = self._count_by_level()
        lines.append("## Summary\n")
        lines.append(f"- **PRD Requirements**: {by_level['PRD']}")
        lines.append(f"- **OPS Requirements**: {by_level['OPS']}")
        lines.append(f"- **DEV Requirements**: {by_level['DEV']}\n")

        # Add legend
        lines.append(self._generate_legend_markdown())

        # Full traceability tree
        lines.append("## Traceability Tree\n")

        # Start with top-level PRD requirements
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            lines.append(self._format_req_tree_md(prd_req, indent=0))

        # Orphaned ops/dev requirements
        orphaned = self._find_orphaned_requirements()
        if orphaned:
            lines.append("\n## Orphaned Requirements\n")
            lines.append("*(Requirements not linked from any parent)*\n")
            for req in orphaned:
                lines.append(f"- **REQ-{req.id}**: {req.title} ({req.level}) - {req.file_path.name}")

        return '\n'.join(lines)

    def _format_req_tree_md(self, req: Requirement, indent: int) -> str:
        """Format requirement and its children as markdown tree"""
        lines = []
        prefix = "  " * indent

        # Format current requirement
        status_emoji = {
            'Active': '✅',
            'Draft': '🚧',
            'Deprecated': '⚠️'
        }
        emoji = status_emoji.get(req.status, '❓')

        # Create link to source file with REQ anchor
        req_link = f"[REQ-{req.id}]({self._base_path}spec/{req.file_path.name}#REQ-{req.id})"

        lines.append(
            f"{prefix}- {emoji} **{req_link}**: {req.title}\n"
            f"{prefix}  - Level: {req.level} | Status: {req.status}\n"
            f"{prefix}  - File: {req.file_path.name}:{req.line_number}"
        )

        # Format implementation files as nested list with clickable links
        if req.implementation_files:
            lines.append(f"{prefix}  - **Implemented in**:")
            for file_path, line_num in req.implementation_files:
                # Create markdown link to file with line number anchor
                # Format: [database/schema.sql:42](database/schema.sql#L42)
                link = f"[{file_path}:{line_num}]({self._base_path}{file_path}#L{line_num})"
                lines.append(f"{prefix}    - {link}")

        # Find and format children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        if children:
            for child in children:
                lines.append(self._format_req_tree_md(child, indent + 1))

        return '\n'.join(lines)

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
            req_data[req_id] = {
                'title': req.title,
                'status': req.status,
                'level': req.level,
                'body': req.body.strip(),
                'rationale': req.rationale.strip(),
                'file': req.file_path.name,
                'filePath': f"{self._base_path}spec/{req.file_path.name}",
                'line': req.line_number,
                'implements': list(req.implements) if req.implements else []
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

        // Code viewer functions
        async function openCodeViewer(filePath, lineNum) {
            const modal = document.getElementById('code-viewer-modal');
            const content = document.getElementById('code-viewer-content');
            const title = document.getElementById('code-viewer-title');
            const lineInfo = document.getElementById('code-viewer-line');

            title.textContent = filePath;
            lineInfo.textContent = `Line ${lineNum}`;
            content.innerHTML = '<div class="loading">Loading...</div>';
            modal.classList.remove('hidden');

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
                            const headingText = heading.textContent.trim();
                            for (let i = 0; i < lines.length; i++) {
                                if (lines[i].includes(headingText)) {
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

        // Close modal on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeCodeViewer();
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
                </div>
                <button class="code-viewer-close" onclick="closeCodeViewer()">Close (Esc)</button>
            </div>
            <div id="code-viewer-content" class="code-viewer-body"></div>
        </div>
    </div>
"""

    def _generate_side_panel_css(self) -> str:
        """Generate CSS styles for side panel"""
        return """
        .side-panel {
            position: fixed;
            top: 0;
            right: 0;
            width: 30%;
            height: 100vh;
            background: white;
            border-left: 2px solid #dee2e6;
            box-shadow: -2px 0 8px rgba(0,0,0,0.1);
            z-index: 1000;
            display: flex;
            flex-direction: column;
            transition: transform 0.3s ease;
        }
        .side-panel.hidden {
            transform: translateX(100%);
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

    def _generate_html(self, embed_content: bool = False) -> str:
        """Generate interactive HTML traceability matrix from markdown source

        Args:
            embed_content: If True, embed full requirement content as JSON and include side panel
        """
        # First generate markdown to ensure consistency
        markdown_content = self._generate_markdown()

        # Parse markdown for HTML rendering
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
    <title>Requirements Traceability Matrix</title>
    <style>
        body {{
            font-family: 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
            font-size: 13px;
            line-height: 1.4;
            margin: 15px;
            background: #f8f9fa;
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
        .summary {{
            background: #f8f9fa;
            padding: 10px 15px;
            border-radius: 4px;
            margin: 15px 0;
            font-size: 12px;
        }}
        .summary p {{
            margin: 4px 0;
        }}
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin: 15px 0;
        }}
        .summary-card {{
            background: white;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
            border-left: 3px solid #0066cc;
        }}
        .summary-card h3 {{
            margin: 0 0 6px 0;
            color: #7f8c8d;
            font-size: 11px;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .summary-card .number {{
            font-size: 24px;
            font-weight: 600;
            color: #0066cc;
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
        .req-tree {{
            margin: 15px 0;
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
            grid-template-columns: 130px 1fr 60px 90px 60px 180px;
            align-items: center;
            gap: 12px;
            min-width: 0;
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
            grid-template-columns: 130px 1fr 60px 90px 60px 180px;
            align-items: center;
            gap: 12px;
            padding: 8px 10px 8px 42px;
            background: #e9ecef;
            border-bottom: 2px solid #dee2e6;
            margin-bottom: 8px;
            position: sticky;
            top: 0;
            z-index: 10;
        }}
        .filter-column {{
            display: flex;
            flex-direction: column;
            gap: 4px;
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
    </style>
    {('<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/vs2015.min.css">' + chr(10) + '    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>' + chr(10) + '    <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"></script>') if embed_content else ''}
</head>
<body>
    <div class="container">
        <h1>Requirements Traceability Matrix</h1>
        <div class="summary">
            <p><strong>Generated:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            <p><strong>Total Requirements:</strong> {len(self.requirements)}</p>
        </div>

        <div class="summary-grid">
            <div class="summary-card">
                <h3>PRD Level</h3>
                <div class="number">{by_level['PRD']}</div>
            </div>
            <div class="summary-card">
                <h3>OPS Level</h3>
                <div class="number">{by_level['OPS']}</div>
            </div>
            <div class="summary-card">
                <h3>DEV Level</h3>
                <div class="number">{by_level['DEV']}</div>
            </div>
        </div>

        <div class="level-legend">
            <div class="legend-item">
                <div class="legend-color prd"></div>
                <span>PRD (Product Requirements)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color ops"></div>
                <span>Ops (Operations)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color dev"></div>
                <span>Dev (Development)</span>
            </div>
        </div>

        {self._generate_legend_html()}

        <div class="filter-controls">
            <div class="view-toggle">
                <button class="btn view-btn active" id="btnFlatView" onclick="switchView('flat')">Flat View</button>
                <button class="btn view-btn" id="btnHierarchyView" onclick="switchView('hierarchy')">Hierarchical View</button>
            </div>
            <button class="btn" onclick="expandAll()">▼ Expand All</button>
            <button class="btn btn-secondary" onclick="collapseAll()">▶ Collapse All</button>
            <button class="btn btn-secondary" onclick="clearFilters()">Clear Filters</button>
            <span class="filter-stats" id="filterStats"></span>
        </div>

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
                <div class="filter-label">Tests</div>
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
        </div>

        <div class="req-tree" id="reqTree">
"""

        # Add requirements and implementation files as flat list (hierarchy via indentation)
        flat_list = self._build_flat_requirement_list()
        for item_data in flat_list:
            html += self._format_item_flat_html(item_data, embed_content=embed_content)

        html += """        </div>
    </div>
"""

        # Add side panel HTML if embedded mode
        if embed_content:
            html += """
    <div id="req-panel" class="side-panel hidden">
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
            html += f"""
    <script id="req-content-data" type="application/json">
{json_data}
    </script>
    <script>
        // Load REQ content data into global scope
        window.REQ_CONTENT_DATA = JSON.parse(document.getElementById('req-content-data').textContent);
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

        // Expand all requirements
        function expandAll() {
            collapsedInstances.clear();
            document.querySelectorAll('.req-item').forEach(item => {
                item.classList.remove('collapsed-by-parent');
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
        }

        // Collapse all requirements
        function collapseAll() {
            document.querySelectorAll('.req-item').forEach(item => {
                if (item.querySelector('.collapse-icon').textContent) {
                    collapsedInstances.add(item.dataset.instanceId);
                    hideDescendants(item.dataset.instanceId);
                    item.querySelector('.collapse-icon').classList.add('collapsed');
                }
            });
        }

        // View mode state
        let currentView = 'flat';

        // Switch between flat and hierarchical views
        function switchView(viewMode) {
            currentView = viewMode;
            const reqTree = document.getElementById('reqTree');
            const btnFlat = document.getElementById('btnFlatView');
            const btnHierarchy = document.getElementById('btnHierarchyView');
            const treeTitle = document.getElementById('treeTitle');

            if (viewMode === 'hierarchy') {
                reqTree.classList.add('hierarchy-view');
                btnFlat.classList.remove('active');
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
            } else {
                reqTree.classList.remove('hierarchy-view');
                btnFlat.classList.add('active');
                btnHierarchy.classList.remove('active');
                treeTitle.textContent = 'Traceability Tree - Flat View';

                // Reset visibility classes
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                });

                // Collapse all for flat view too
                collapseAll();
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
            const topicFilter = document.getElementById('filterTopic').value.toLowerCase().trim();

            // Check if any filter is active
            const anyFilterActive = reqIdFilter || titleFilter || levelFilter || statusFilter || topicFilter;

            let visibleCount = 0;
            let totalCount = 0;
            const seenReqIds = new Set();  // Track which req IDs we've already shown

            // Simple iteration: show/hide each item based on filters
            document.querySelectorAll('.req-item').forEach(item => {
                totalCount++;
                const reqId = item.dataset.reqId.toLowerCase();
                const level = item.dataset.level;
                const topic = item.dataset.topic.toLowerCase();
                const status = item.dataset.status;
                const title = item.dataset.title.toLowerCase();

                let matches = true;

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

                // Check for duplicates: if filtering and we've already shown this req ID, hide this occurrence
                if (matches && anyFilterActive && seenReqIds.has(reqId)) {
                    matches = false;  // Hide duplicate
                }

                // Simple show/hide - no hierarchy complexity!
                if (matches) {
                    item.classList.remove('filtered-out');
                    // If any filter is active, ignore collapse state and show matching items
                    if (anyFilterActive) {
                        item.classList.remove('collapsed-by-parent');
                        seenReqIds.add(reqId);  // Mark this req ID as shown
                    }
                    visibleCount++;
                } else {
                    item.classList.add('filtered-out');
                }
            });

            // Update stats
            document.getElementById('filterStats').textContent =
                `Showing ${visibleCount} of ${totalCount} requirements`;
        }

        // Clear all filters
        function clearFilters() {
            document.getElementById('filterReqId').value = '';
            document.getElementById('filterTitle').value = '';
            document.getElementById('filterLevel').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('filterTopic').value = '';
            applyFilters();
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            // Start with everything collapsed except top level
            // First, hide all children of all items with children
            document.querySelectorAll('.req-item').forEach(item => {
                const instanceId = item.dataset.instanceId;
                const icon = item.querySelector('.collapse-icon');

                if (icon && icon.textContent) {
                    // This item has children - collapse it
                    collapsedInstances.add(instanceId);
                    hideDescendants(instanceId);
                    icon.classList.add('collapsed');
                }
            });

            // Initialize filter stats
            applyFilters();
        });
"""

        # Add side panel JavaScript functions if embedded mode
        if embed_content:
            html += self._generate_side_panel_js()

        html += """
    </script>
"""
        # Add code viewer modal if embedded mode
        if embed_content:
            html += self._generate_code_viewer_html()

        html += """
</body>
</html>
"""
        return html

    def _build_flat_requirement_list(self) -> List[dict]:
        """Build a flat list of requirements with hierarchy information"""
        flat_list = []
        self._instance_counter = 0  # Track unique instance IDs

        # Start with top-level PRD requirements
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            self._add_requirement_and_children(prd_req, flat_list, indent=0, parent_instance_id='')

        return flat_list

    def _add_requirement_and_children(self, req: Requirement, flat_list: List[dict], indent: int, parent_instance_id: str):
        """Recursively add requirement and its children to flat list"""
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

        # Recursively add child requirements
        for child in children:
            self._add_requirement_and_children(child, flat_list, indent + 1, instance_id)

    def _format_item_flat_html(self, item_data: dict, embed_content: bool = False) -> str:
        """Format a single item (requirement or implementation file) as flat HTML row

        Args:
            item_data: Dictionary containing item data
            embed_content: If True, use onclick handlers instead of href links for portability
        """
        item_type = item_data.get('item_type', 'requirement')

        if item_type == 'implementation':
            return self._format_impl_file_html(item_data, embed_content)
        else:
            return self._format_req_html(item_data, embed_content)

    def _format_impl_file_html(self, item_data: dict, embed_content: bool = False) -> str:
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
                    <div class="req-status"></div>
                    <div class="req-location"></div>
                </div>
            </div>
        </div>
"""
        return html

    def _format_req_html(self, req_data: dict, embed_content: bool = False) -> str:
        """Format a single requirement as flat HTML row

        Args:
            req_data: Dictionary containing requirement data
            embed_content: If True, use onclick handlers instead of href links for portability
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
        if embed_content:
            req_link = f'<a href="#" onclick="event.stopPropagation(); openReqPanel(\'{req.id}\'); return false;" style="color: inherit; text-decoration: none; cursor: pointer;">REQ-{req.id}</a>'
            file_line_link = f'<span style="color: inherit;">{req.file_path.name}:{req.line_number}</span>'
        else:
            req_link = f'<a href="{self._base_path}spec/{req.file_path.name}#REQ-{req.id}" style="color: inherit; text-decoration: none;">REQ-{req.id}</a>'
            file_line_link = f'<a href="{self._base_path}spec/{req.file_path.name}#L{req.line_number}" style="color: inherit; text-decoration: none;">{req.file_path.name}:{req.line_number}</a>'

        # Check if this is a root requirement (no parents)
        is_root = not req.implements or len(req.implements) == 0
        is_root_attr = 'data-is-root="true"' if is_root else 'data-is-root="false"'

        # Build HTML for single flat row with unique instance ID
        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}" data-req-id="{req.id}" data-instance-id="{instance_id}" data-level="{req.level}" data-indent="{indent}" data-parent-instance-id="{parent_instance_id}" data-topic="{topic}" data-status="{req.status}" data-title="{req.title.lower()}" {is_root_attr}>
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-id">{req_link}</div>
                    <div class="req-header">{req.title}</div>
                    <div class="req-level">{req.level}</div>
                    <div class="req-badges">
                        <span class="status-badge status-{status_class}">{req.status}</span>
                        <span class="coverage-badge" title="{coverage_title}">{coverage_icon}</span>
                    </div>
                    <div class="req-status">{test_badge}</div>
                    <div class="req-location">{file_line_link}</div>
                </div>
            </div>
        </div>
"""
        return html

    def _format_req_tree_html(self, req: Requirement) -> str:
        """Format requirement and children as HTML tree (legacy non-collapsible)"""
        status_class = req.status.lower()
        level_class = req.level.lower()

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}">
            <div class="req-header">
                REQ-{req.id}: {req.title}
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
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html(child)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

    def _format_req_tree_html_collapsible(self, req: Requirement) -> str:
        """Format requirement and children as collapsible HTML tree"""
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
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html_collapsible(child)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

    def _load_test_data(self):
        """Load test coverage data from JSON mapping file"""
        try:
            with open(self.test_mapping_file, 'r') as f:
                data = json.load(f)

            mappings = data.get('mappings', {})

            for req_id, test_data in mappings.items():
                tests = test_data.get('tests', [])
                manual_tests = test_data.get('manual_tests', [])
                coverage = test_data.get('coverage', 'not_tested')
                notes = test_data.get('notes', '')

                test_info = TestInfo(
                    test_count=len(tests),
                    manual_test_count=len(manual_tests),
                    test_status=coverage,
                    test_details=tests + manual_tests,
                    notes=notes
                )

                # Attach test info to requirement
                if req_id in self.requirements:
                    self.requirements[req_id].test_info = test_info

            tested = sum(1 for r in self.requirements.values() if r.test_info and r.test_info.test_count > 0)
            print(f"   ✅ Loaded test data for {len(mappings)} requirements")
            print(f"   📊 Test coverage: {tested}/{len(self.requirements)} requirements have tests")

        except Exception as e:
            print(f"   ⚠️  Error loading test data: {e}")
            print(f"   All requirements will be marked as 'not tested'")

    def _generate_csv(self) -> str:
        """Generate CSV traceability matrix"""
        from io import StringIO
        output = StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            'Requirement ID',
            'Title',
            'Level',
            'Status',
            'Implements',
            'Traced By',
            'File',
            'Line',
            'Implementation Files'
        ])

        # Sort requirements by ID
        sorted_reqs = sorted(self.requirements.values(), key=lambda r: r.id)

        for req in sorted_reqs:
            # Compute children (traced by) dynamically
            children = [
                r.id for r in self.requirements.values()
                if req.id in r.implements
            ]

            # Format implementation files as "file:line" strings
            impl_files_str = ', '.join([f'{path}:{line}' for path, line in req.implementation_files]) if req.implementation_files else '-'

            writer.writerow([
                req.id,
                req.title,
                req.level,
                req.status,
                ', '.join(req.implements) if req.implements else '-',
                ', '.join(sorted(children)) if children else '-',
                req.file_path.name,
                req.line_number,
                impl_files_str
            ])

        return output.getvalue()

    def _count_by_level(self) -> Dict[str, int]:
        """Count requirements by level"""
        counts = {'PRD': 0, 'OPS': 0, 'DEV': 0}
        for req in self.requirements.values():
            if req.status == 'Active':  # Only count active requirements
                counts[req.level] = counts.get(req.level, 0) + 1
        return counts

    def _find_orphaned_requirements(self) -> List[Requirement]:
        """Find requirements not linked from any parent"""
        implemented = set()
        for req in self.requirements.values():
            implemented.update(req.implements)

        orphaned = []
        for req in self.requirements.values():
            # Skip PRD requirements (they're top-level)
            if req.level == 'PRD':
                continue
            # Skip if this requirement is implemented by someone
            if req.id in implemented:
                continue
            # Skip if it has no parent (should have one)
            if not req.implements:
                orphaned.append(req)

        return sorted(orphaned, key=lambda r: r.id)

    def _calculate_coverage(self, req_id: str) -> dict:
        """Calculate coverage for a requirement

        Returns:
            dict with 'children' (total child count) and 'traced' (children with implementation)
        """
        # Find all requirements that implement this requirement (children)
        children = [
            r for r in self.requirements.values()
            if req_id in r.implements
        ]

        # Count how many children have implementation files or their own children with implementation
        traced = 0
        for child in children:
            child_status = self._get_implementation_status(child.id)
            if child_status in ['Full', 'Partial']:
                traced += 1

        return {
            'children': len(children),
            'traced': traced
        }

    def _get_implementation_status(self, req_id: str) -> str:
        """Get implementation status for a requirement

        Returns:
            'Unimplemented': No children AND no implementation_files
            'Partial': Some but not all children traced
            'Full': Has implementation_files OR all children traced
        """
        req = self.requirements.get(req_id)
        if not req:
            return 'Unimplemented'

        # If requirement has implementation files, it's fully implemented
        if req.implementation_files:
            return 'Full'

        # Find children
        children = [
            r for r in self.requirements.values()
            if req_id in r.implements
        ]

        # No children and no implementation files = Unimplemented
        if not children:
            return 'Unimplemented'

        # Check how many children are traced
        coverage = self._calculate_coverage(req_id)

        if coverage['traced'] == 0:
            return 'Unimplemented'
        elif coverage['traced'] == coverage['children']:
            return 'Full'
        else:
            return 'Partial'

    def _generate_planning_csv(self) -> str:
        """Generate CSV for sprint planning (actionable items only)

        Returns CSV with columns: REQ ID, Title, Level, Status, Impl Status, Coverage, Code Refs
        Includes only actionable items (Active or Draft status, not deprecated)
        """
        from io import StringIO
        output = StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            'REQ ID',
            'Title',
            'Level',
            'Status',
            'Impl Status',
            'Coverage',
            'Code Refs'
        ])

        # Filter to actionable requirements (Active or Draft status)
        actionable_reqs = [
            req for req in self.requirements.values()
            if req.status in ['Active', 'Draft']
        ]

        # Sort by ID
        actionable_reqs.sort(key=lambda r: r.id)

        for req in actionable_reqs:
            impl_status = self._get_implementation_status(req.id)
            coverage = self._calculate_coverage(req.id)
            code_refs = len(req.implementation_files)

            writer.writerow([
                req.id,
                req.title,
                req.level,
                req.status,
                impl_status,
                f"{coverage['traced']}/{coverage['children']}",
                code_refs
            ])

        return output.getvalue()

    def _generate_coverage_report(self) -> str:
        """Generate text-based coverage report with summary statistics

        Returns a formatted text report showing:
        - Total requirements count
        - Breakdown by level (PRD, OPS, DEV) with percentages
        - Breakdown by implementation status (Full/Partial/Unimplemented)
        """
        lines = []
        lines.append("=== Coverage Report ===")
        lines.append(f"Total Requirements: {len(self.requirements)}")
        lines.append("")

        # Count by level
        by_level = {'PRD': 0, 'OPS': 0, 'DEV': 0}
        implemented_by_level = {'PRD': 0, 'OPS': 0, 'DEV': 0}

        for req in self.requirements.values():
            level = req.level
            by_level[level] = by_level.get(level, 0) + 1

            impl_status = self._get_implementation_status(req.id)
            if impl_status in ['Full', 'Partial']:
                implemented_by_level[level] = implemented_by_level.get(level, 0) + 1

        lines.append("By Level:")
        for level in ['PRD', 'OPS', 'DEV']:
            total = by_level[level]
            implemented = implemented_by_level[level]
            percentage = (implemented / total * 100) if total > 0 else 0
            lines.append(f"  {level}: {total} ({percentage:.0f}% implemented)")

        lines.append("")

        # Count by implementation status
        status_counts = {'Full': 0, 'Partial': 0, 'Unimplemented': 0}
        for req in self.requirements.values():
            impl_status = self._get_implementation_status(req.id)
            status_counts[impl_status] = status_counts.get(impl_status, 0) + 1

        lines.append("By Status:")
        lines.append(f"  Full: {status_counts['Full']}")
        lines.append(f"  Partial: {status_counts['Partial']}")
        lines.append(f"  Unimplemented: {status_counts['Unimplemented']}")

        return '\n'.join(lines)


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Generate requirements traceability matrix with test coverage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Tip: Use --format both to generate both markdown and HTML versions

Examples:
  # Generate matrix for current repo
  python generate_traceability.py

  # Generate matrix for a different repo
  python generate_traceability.py --path /path/to/other/repo

  # Generate for sibling repo with HTML output
  python generate_traceability.py --path ../sibling-repo --format html
'''
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'csv', 'both'],
        default='markdown',
        help='Output format (default: markdown). Use "both" for markdown + HTML'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: traceability_matrix.{format})'
    )
    parser.add_argument(
        '--test-mapping',
        type=Path,
        help='Path to requirement-test mapping JSON file (default: build-reports/templates/requirement_test_mapping.template.json)'
    )
    parser.add_argument(
        '--sponsor',
        type=str,
        help='Sponsor name for sponsor-specific reports (e.g., "callisto", "titan"). Required when --mode is "sponsor"'
    )
    parser.add_argument(
        '--mode',
        choices=['core', 'sponsor', 'combined'],
        default='core',
        help='Report mode: "core" (exclude sponsor code), "sponsor" (specific sponsor + core), "combined" (all code)'
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output directory path (overrides default based on mode)'
    )
    parser.add_argument(
        '--path',
        type=Path,
        help='Path to repository root (default: auto-detect from script location)'
    )
    parser.add_argument(
        '--embed-content',
        action='store_true',
        help='Embed full requirement content in HTML for portable/offline viewing (includes side panel)'
    )
    parser.add_argument(
        '--export-planning',
        action='store_true',
        help='Generate planning CSV with actionable requirements for sprint planning'
    )
    parser.add_argument(
        '--coverage-report',
        action='store_true',
        help='Generate coverage report showing implementation status statistics'
    )

    args = parser.parse_args()

    # Validate sponsor argument
    if args.mode == 'sponsor' and not args.sponsor:
        print("Error: --sponsor is required when --mode is 'sponsor'")
        sys.exit(1)

    # Find spec directory
    if args.path:
        repo_root = args.path.resolve()
    else:
        script_dir = Path(__file__).parent
        repo_root = script_dir.parent.parent
    spec_dir = repo_root / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Determine test mapping file
    if args.test_mapping:
        test_mapping_file = args.test_mapping
    else:
        # Default location (template file for reference)
        test_mapping_file = repo_root / 'build-reports' / 'templates' / 'requirement_test_mapping.template.json'

    # Collect implementation directories to scan based on mode
    impl_dirs = []

    if args.mode == 'core':
        # Core mode: scan core directories only (exclude /sponsor/)
        print(f"Mode: CORE - scanning core directories only")
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        # Scan apps directory if it exists
        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

    elif args.mode == 'sponsor':
        # Sponsor mode: scan specific sponsor + core directories
        print(f"Mode: SPONSOR ({args.sponsor}) - scanning sponsor + core directories")

        # Add sponsor directory
        sponsor_dir = repo_root / 'sponsor' / args.sponsor
        if not sponsor_dir.exists():
            print(f"Warning: Sponsor directory not found: {sponsor_dir}")
        else:
            impl_dirs.append(sponsor_dir)

        # Also scan core directories
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

    elif args.mode == 'combined':
        # Combined mode: scan ALL directories (core + all sponsors)
        print(f"Mode: COMBINED - scanning all directories")

        # Add core directories
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

        # Add all sponsor directories
        sponsor_root = repo_root / 'sponsor'
        if sponsor_root.exists():
            for sponsor_dir in sponsor_root.iterdir():
                if sponsor_dir.is_dir() and not sponsor_dir.name.startswith('.'):
                    impl_dirs.append(sponsor_dir)
                    print(f"   Including sponsor: {sponsor_dir.name}")

    generator = TraceabilityGenerator(
        spec_dir,
        test_mapping_file=test_mapping_file,
        impl_dirs=impl_dirs,
        sponsor=args.sponsor,
        mode=args.mode,
        repo_root=repo_root
    )

    # Determine output path based on --output-dir, --output, or defaults
    if args.output:
        # Explicit output file specified
        output_file = args.output
    elif args.output_dir:
        # Output directory specified - construct filename
        output_dir = args.output_dir
        output_dir.mkdir(parents=True, exist_ok=True)
        if args.format == 'both':
            output_file = output_dir / 'traceability_matrix.md'
        else:
            ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
            output_file = output_dir / f'traceability_matrix{ext}'
    else:
        # Use default output path based on mode
        if args.mode == 'core':
            output_dir = repo_root / 'build-reports' / 'combined' / 'traceability'
        elif args.mode == 'sponsor':
            output_dir = repo_root / 'build-reports' / args.sponsor / 'traceability'
        elif args.mode == 'combined':
            output_dir = repo_root / 'build-reports' / 'combined' / 'traceability'

        output_dir.mkdir(parents=True, exist_ok=True)

        if args.format == 'both':
            output_file = output_dir / 'traceability_matrix.md'
        else:
            ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
            output_file = output_dir / f'traceability_matrix{ext}'

    # Handle special export options first
    if args.export_planning:
        print("📋 Generating planning CSV...")
        generator._parse_requirements()
        if generator.impl_dirs:
            generator._scan_implementation_files()
        planning_csv = generator._generate_planning_csv()
        planning_file = output_file.parent / 'planning_export.csv' if output_file else Path('planning_export.csv')
        planning_file.write_text(planning_csv)
        print(f"✅ Planning CSV written to: {planning_file}")

    if args.coverage_report:
        print("📊 Generating coverage report...")
        if not generator.requirements:
            generator._parse_requirements()
            if generator.impl_dirs:
                generator._scan_implementation_files()
        coverage_report = generator._generate_coverage_report()
        report_file = output_file.parent / 'coverage_report.txt' if output_file else Path('coverage_report.txt')
        report_file.write_text(coverage_report)
        print(f"✅ Coverage report written to: {report_file}")

    # Skip matrix generation if only special exports requested
    if args.export_planning or args.coverage_report:
        if not (args.format or args.output):
            return  # Only special exports requested, no matrix

    # Handle 'both' format option
    if args.format == 'both':
        print("Generating both Markdown and HTML formats...")
        # Generate markdown
        md_output = output_file if output_file.suffix == '.md' else output_file.with_suffix('.md')
        generator.generate(format='markdown', output_file=md_output)

        # Generate HTML (with embed_content if requested)
        html_output = md_output.with_suffix('.html')
        generator.generate(format='html', output_file=html_output, embed_content=args.embed_content)
    else:
        generator.generate(format=args.format, output_file=output_file, embed_content=args.embed_content)


if __name__ == '__main__':
    main()
