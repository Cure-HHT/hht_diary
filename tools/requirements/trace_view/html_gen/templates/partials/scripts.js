/**
 * TraceView Interactive Traceability Matrix JavaScript
 *
 * This module provides all interactive functionality for the trace-view HTML report.
 * Organized using the module pattern with logical sub-objects for maintainability.
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-tv-d00003: JavaScript Extraction
 */

const TraceView = (function() {
    'use strict';

    // ==========================================================================
    // State Management (REQ-tv-d00003-I: Global state encapsulated)
    // ==========================================================================

    /**
     * Internal state object - encapsulates all global state variables
     */
    const state = {
        reqCardStack: [],
        pendingMoves: [],
        editModeActive: false,
        leafOnlyActive: false,
        pendingMovesCollapsed: false,
        filePickerState: { reqId: null, sourceFile: null },
        allSpecFiles: [],
        userAddedFiles: new Set(),
        originalStatusSuffixes: new Map(),
        // Navigation state
        collapsedInstances: new Set(),
        currentView: 'flat'
    };

    // ==========================================================================
    // Panel Management (REQ-tv-d00003-F: Logical sub-objects)
    // ==========================================================================

    /**
     * Side panel operations for requirement details
     */
    const panel = {
        /**
         * Open a requirement in the side panel
         * @param {string} reqId - The requirement ID to display
         */
        open: function(reqId) {
            const panelEl = document.getElementById('req-panel');
            const cardStack = document.getElementById('req-card-stack');
            const reqData = window.REQ_CONTENT_DATA;

            if (!reqData || !reqData[reqId]) {
                console.error('Requirement data not found:', reqId);
                return;
            }

            // Show panel if hidden
            panelEl.classList.remove('hidden');

            // Check if card already exists
            if (state.reqCardStack.includes(reqId)) {
                return; // Already open
            }

            // Add to stack
            state.reqCardStack.unshift(reqId);

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
                    `<a href="#" onclick="TraceView.panel.open('${parentId}'); return false;" class="implements-link">${parentId}</a>`
                ).join(', ');
                implementsHtml = `<div class="req-card-implements">Implements: ${implLinks}</div>`;
            }

            // Determine if in roadmap based on file path
            const isInRoadmap = req.filePath.includes('roadmap/');
            const moveButtons = isInRoadmap
                ? `<button class="edit-btn from-roadmap panel-edit-btn" onclick="TraceView.editMode.addMove('${reqId}', '${req.file}', 'from-roadmap')" title="Move out of roadmap">↩ From Roadmap</button>
                   <button class="edit-btn move-file panel-edit-btn" onclick="TraceView.filePicker.show('${reqId}', '${req.file}')" title="Move to different file">📁 Move</button>`
                : `<button class="edit-btn to-roadmap panel-edit-btn" onclick="TraceView.editMode.addMove('${reqId}', '${req.file}', 'to-roadmap')" title="Move to roadmap">🗺️ To Roadmap</button>
                   <button class="edit-btn move-file panel-edit-btn" onclick="TraceView.filePicker.show('${reqId}', '${req.file}')" title="Move to different file">📁 Move</button>`;

            // Generate VS Code link - use relative path when REPO_ROOT is empty (portable mode)
            const repoRelPath = req.filePath.replace(/^\.\.\//, '');
            const vscodeHref = window.REPO_ROOT
                ? `vscode://file/${window.REPO_ROOT}/${repoRelPath}:${req.line}`
                : `${req.filePath}`;  // Relative link for portable mode
            const vscodeTitle = window.REPO_ROOT
                ? 'Open in VS Code'
                : `Open file (${repoRelPath}:${req.line})`;

            card.innerHTML = `
                <div class="req-card-header">
                    <span class="req-card-title">REQ-${reqId}: ${req.title}</span>
                    <button class="close-btn" onclick="TraceView.panel.close('${reqId}')">×</button>
                </div>
                <div class="req-card-body">
                    <div class="req-card-meta">
                        <span class="badge">${req.level}</span>
                        <span class="badge">${req.status}</span>
                        <a href="#" onclick="TraceView.codeViewer.open('${req.filePath}', ${req.line}); return false;" class="file-ref-link">${req.file}:${req.line}</a>
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
        },

        /**
         * Close a specific requirement card
         * @param {string} reqId - The requirement ID to close
         */
        close: function(reqId) {
            const card = document.getElementById(`req-card-${reqId}`);
            if (card) {
                card.remove();
            }
            const index = state.reqCardStack.indexOf(reqId);
            if (index > -1) {
                state.reqCardStack.splice(index, 1);
            }

            // Hide panel if empty
            if (state.reqCardStack.length === 0) {
                document.getElementById('req-panel').classList.add('hidden');
            }
        },

        /**
         * Close all requirement cards
         */
        closeAll: function() {
            const cardStack = document.getElementById('req-card-stack');
            cardStack.innerHTML = '';
            state.reqCardStack.length = 0;
            document.getElementById('req-panel').classList.add('hidden');
        },

        /**
         * Initialize panel resize functionality
         */
        initResize: function() {
            const panelEl = document.getElementById('req-panel');
            const handle = document.getElementById('resizeHandle');
            if (!panelEl || !handle) return;

            let isResizing = false;
            let startX, startWidth;

            handle.addEventListener('mousedown', function(e) {
                isResizing = true;
                startX = e.clientX;
                startWidth = panelEl.offsetWidth;
                handle.classList.add('dragging');
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';
                e.preventDefault();
            });

            document.addEventListener('mousemove', function(e) {
                if (!isResizing) return;
                const diff = startX - e.clientX;
                const newWidth = Math.min(Math.max(startWidth + diff, 250), window.innerWidth * 0.7);
                panelEl.style.width = newWidth + 'px';
            });

            document.addEventListener('mouseup', function() {
                if (isResizing) {
                    isResizing = false;
                    handle.classList.remove('dragging');
                    document.body.style.cursor = '';
                    document.body.style.userSelect = '';
                }
            });
        }
    };

    // ==========================================================================
    // Code Viewer (REQ-tv-d00003-F: Logical sub-objects)
    // ==========================================================================

    /**
     * Code viewer modal operations
     */
    const codeViewer = {
        /**
         * Get language class for syntax highlighting
         * @param {string} ext - File extension
         * @returns {string} Language class for highlight.js
         */
        getLangClass: function(ext) {
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
        },

        /**
         * Open the code viewer modal with file content
         * @param {string} filePath - Path to the file
         * @param {number} lineNum - Line number to highlight
         */
        open: async function(filePath, lineNum) {
            const modal = document.getElementById('code-viewer-modal');
            const content = document.getElementById('code-viewer-content');
            const title = document.getElementById('code-viewer-title');
            const lineInfo = document.getElementById('code-viewer-line');
            const vscodeLink = document.getElementById('code-viewer-vscode');

            title.textContent = filePath;
            lineInfo.textContent = `Line ${lineNum}`;
            content.innerHTML = '<div class="loading">Loading...</div>';
            modal.classList.remove('hidden');

            // Set VS Code link
            if (vscodeLink) {
                const repoRelPath = filePath.replace(/^\.\.\//, '');
                if (window.REPO_ROOT) {
                    const absPath = window.REPO_ROOT + '/' + repoRelPath;
                    vscodeLink.href = `vscode://file/${absPath}:${lineNum}`;
                    vscodeLink.title = 'Open in VS Code';
                } else {
                    vscodeLink.href = filePath;
                    vscodeLink.title = `Open file (${repoRelPath}:${lineNum})`;
                }
            }

            try {
                const response = await fetch(filePath);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                const text = await response.text();
                const ext = filePath.split('.').pop().toLowerCase();

                // For markdown files, render as formatted markdown
                if (ext === 'md' && window.marked) {
                    const renderedHtml = marked.parse(text);
                    content.innerHTML = `<div class="markdown-viewer markdown-body">${renderedHtml}</div>`;
                    content.classList.add('markdown-mode');
                    this._scrollToMarkdownLine(content, text, lineNum);
                } else {
                    // For code files, show with line numbers
                    content.classList.remove('markdown-mode');
                    this._renderCodeWithLines(content, text, lineNum, ext);
                }
            } catch (err) {
                content.innerHTML = `<div class="error">Failed to load file: ${err.message}</div>`;
            }
        },

        /**
         * Render code with line numbers and highlighting
         * @private
         */
        _renderCodeWithLines: function(content, text, lineNum, ext) {
            const lines = text.split('\n');
            const langClass = this.getLangClass(ext);

            let html = '<table class="code-table"><tbody>';
            lines.forEach((line, idx) => {
                const lineNumber = idx + 1;
                const isHighlighted = lineNumber === lineNum;
                const highlightClass = isHighlighted ? 'highlighted-line' : '';
                const lineId = `L${lineNumber}`;
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
        },

        /**
         * Scroll to approximate line in markdown view
         * @private
         */
        _scrollToMarkdownLine: function(content, text, lineNum) {
            const lines = text.split('\n');
            setTimeout(() => {
                let targetElement = null;

                // Find the nearest heading at or before the target line
                const headings = content.querySelectorAll('h1, h2, h3, h4');
                for (const heading of headings) {
                    const headingText = heading.textContent.trim();
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        if (line.startsWith('#') && line.includes(headingText)) {
                            if (i + 1 <= lineNum) {
                                targetElement = heading;
                            }
                            break;
                        }
                    }
                }

                // Fallback to first heading
                if (!targetElement) {
                    targetElement = content.querySelector('h1, h2, h3');
                }

                if (targetElement) {
                    targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    targetElement.classList.add('highlight-target');
                    setTimeout(() => targetElement.classList.remove('highlight-target'), 2000);
                }
            }, 100);
        },

        /**
         * Close the code viewer modal
         */
        close: function() {
            document.getElementById('code-viewer-modal').classList.add('hidden');
        }
    };

    // ==========================================================================
    // Edit Mode (REQ-tv-d00003-F: Logical sub-objects)
    // ==========================================================================

    /**
     * Edit mode operations for batch requirement moves
     */
    const editMode = {
        /**
         * Toggle edit mode on/off
         */
        toggle: function() {
            state.editModeActive = !state.editModeActive;
            const btn = document.getElementById('btnEditMode');
            const panel = document.getElementById('editModePanel');

            if (state.editModeActive) {
                document.body.classList.add('edit-mode-active');
                btn.classList.add('active');
                panel.style.display = 'block';
                document.getElementById('chkIncludeRoadmap').checked = true;
                applyFilters();
            } else {
                document.body.classList.remove('edit-mode-active');
                btn.classList.remove('active');
                panel.style.display = 'none';
            }
        },

        /**
         * Add a pending move operation
         * @param {string} reqId - Requirement ID
         * @param {string} sourceFile - Source file path
         * @param {string} moveType - Type of move ('to-roadmap', 'from-roadmap', 'move-file')
         */
        addMove: function(reqId, sourceFile, moveType) {
            const existing = state.pendingMoves.find(m => m.reqId === reqId);
            if (existing) {
                alert('This requirement already has a pending move. Clear selection first.');
                return;
            }

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
            state.pendingMoves.push(move);
            this._updateUI();
            this._updateDestinationColumns();
        },

        /**
         * Remove a pending move by index
         * @param {number} index - Index in pendingMoves array
         */
        removeMove: function(index) {
            state.pendingMoves.splice(index, 1);
            this._updateUI();
            this._updateDestinationColumns();
        },

        /**
         * Clear all pending moves
         */
        clearMoves: function() {
            state.pendingMoves.length = 0;
            this._updateUI();
            this._updateDestinationColumns();
        },

        /**
         * Generate and download moves JSON
         */
        generateScript: function() {
            if (state.pendingMoves.length === 0) {
                alert('No pending moves to generate script for.');
                return;
            }

            const moves = state.pendingMoves
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
            const blob = new Blob([jsonOutput], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'moves.json';
            a.click();
            URL.revokeObjectURL(url);

            alert('Saved moves.json\n\nRun with:\n  python3 tools/requirements/move_reqs.py moves.json\n\nOr preview first:\n  python3 tools/requirements/move_reqs.py --dry-run moves.json');
        },

        /**
         * Toggle pending moves list visibility
         */
        togglePendingMoves: function() {
            state.pendingMovesCollapsed = !state.pendingMovesCollapsed;
            const list = document.getElementById('pendingMovesList');
            const toggleBtn = document.getElementById('pendingMovesToggle');
            if (state.pendingMovesCollapsed) {
                list.style.display = 'none';
                toggleBtn.textContent = '▶';
            } else {
                list.style.display = 'block';
                toggleBtn.textContent = '▼';
            }
        },

        /**
         * Update the pending moves UI
         * @private
         */
        _updateUI: function() {
            const list = document.getElementById('pendingMovesList');
            const count = document.getElementById('pendingChangesCount');
            const btn = document.getElementById('btnExportMoves');

            count.textContent = state.pendingMoves.length + ' pending';
            btn.disabled = state.pendingMoves.length === 0;

            if (state.pendingMoves.length === 0) {
                list.innerHTML = '<div style="color: #666; padding: 10px;">No pending moves. Click edit buttons on requirements to select them.</div>';
                return;
            }

            list.innerHTML = state.pendingMoves.map((m, i) => {
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
                    <button onclick="TraceView.editMode.removeMove(${i})" style="background: none; border: none; cursor: pointer; margin-left: auto;">✕</button>
                </div>
            `}).join('');
        },

        /**
         * Update destination columns in the requirement tree
         * @private
         */
        _updateDestinationColumns: function() {
            // Reset all destination columns
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
                if (suffixEl && state.originalStatusSuffixes.has(reqId)) {
                    const original = state.originalStatusSuffixes.get(reqId);
                    if (!state.pendingMoves.some(m => m.reqId === reqId)) {
                        suffixEl.textContent = original.text;
                        suffixEl.className = original.className;
                        suffixEl.title = original.title;
                    }
                }
            });

            // Update destination columns and status suffixes for pending moves
            state.pendingMoves.forEach(m => {
                const reqItem = document.querySelector(`.req-item[data-req-id="${m.reqId}"]`);
                if (!reqItem) return;

                const destEl = reqItem.querySelector('.req-destination');
                const suffixEl = reqItem.querySelector('.status-suffix');

                // Save original status suffix if not already saved
                if (suffixEl && !state.originalStatusSuffixes.has(m.reqId)) {
                    state.originalStatusSuffixes.set(m.reqId, {
                        text: suffixEl.textContent,
                        className: suffixEl.className,
                        title: suffixEl.title
                    });
                }

                // Update destination column
                if (destEl) {
                    const editActions = destEl.querySelector('.edit-actions');
                    const destText = destEl.querySelector('.dest-text');

                    if (editActions) editActions.style.display = 'none';
                    if (destText) {
                        destText.style.display = '';
                        if (m.moveType === 'to-roadmap') {
                            destText.textContent = '→ Roadmap';
                            destEl.className = 'req-destination edit-mode-column to-roadmap';
                        } else if (m.moveType === 'from-roadmap') {
                            destText.textContent = '← From Roadmap';
                            destEl.className = 'req-destination edit-mode-column from-roadmap';
                        } else if (m.targetFile) {
                            const displayName = m.targetFile.replace('roadmap/', '').replace(/\.md$/, '');
                            destText.textContent = '→ ' + displayName;
                        }
                    }
                }

                // Update status suffix
                if (suffixEl) {
                    const originalText = state.originalStatusSuffixes.get(m.reqId)?.text || '';
                    if (originalText && originalText !== '↝' && originalText !== '⇢') {
                        suffixEl.textContent = '⇢' + originalText;
                        suffixEl.className = 'status-suffix status-pending-move';
                        suffixEl.title = 'PENDING MOVE + ' + (state.originalStatusSuffixes.get(m.reqId)?.title || '');
                    } else {
                        suffixEl.textContent = '⇢';
                        suffixEl.className = 'status-suffix status-pending-move';
                        suffixEl.title = 'PENDING MOVE (not yet executed)';
                    }
                }
            });
        }
    };

    // ==========================================================================
    // File Picker (REQ-tv-d00003-F: Logical sub-objects)
    // ==========================================================================

    /**
     * File picker modal operations
     */
    const filePicker = {
        /**
         * Show the file picker modal
         * @param {string} reqId - Requirement ID
         * @param {string} sourceFile - Source file path
         */
        show: function(reqId, sourceFile) {
            state.filePickerState = { reqId, sourceFile };
            state.allSpecFiles = this._getAvailableFiles();

            const modal = document.getElementById('file-picker-modal');
            const input = document.getElementById('filePickerInput');
            const error = document.getElementById('filePickerError');

            input.value = '';
            error.textContent = '';
            error.style.display = 'none';

            this._renderList('');
            modal.classList.remove('hidden');
            input.focus();
        },

        /**
         * Close the file picker modal
         */
        close: function() {
            document.getElementById('file-picker-modal').classList.add('hidden');
            state.filePickerState = { reqId: null, sourceFile: null };
        },

        /**
         * Filter the file list based on input
         * @param {string} value - Filter value
         */
        filter: function(value) {
            this._renderList(value);
            this._validate(value);
        },

        /**
         * Select a file from the list
         * @param {string} filename - Selected filename
         */
        select: function(filename) {
            document.getElementById('filePickerInput').value = filename;
            this._validate(filename);
        },

        /**
         * Confirm the file picker selection
         */
        confirm: function() {
            const input = document.getElementById('filePickerInput');
            const filename = input.value.trim();

            if (!this._validate(filename)) {
                return;
            }

            state.userAddedFiles.add(filename);
            editMode.addMove(state.filePickerState.reqId, state.filePickerState.sourceFile, 'move-file');
            state.pendingMoves[state.pendingMoves.length - 1].targetFile = filename;
            editMode._updateUI();
            editMode._updateDestinationColumns();

            this.close();
        },

        /**
         * Render the file list
         * @private
         */
        _renderList: function(filter) {
            const list = document.getElementById('filePickerList');
            const filterLower = filter.toLowerCase();

            const filtered = state.allSpecFiles.filter(f =>
                f.toLowerCase().includes(filterLower)
            );

            if (filtered.length === 0 && filter) {
                list.innerHTML = '<div class="file-picker-empty">No matching files. You can enter a new filename.</div>';
            } else {
                list.innerHTML = filtered.map(f =>
                    `<div class="file-picker-item" onclick="TraceView.filePicker.select('${f}')">${f}</div>`
                ).join('');
            }
        },

        /**
         * Validate the filename
         * @private
         */
        _validate: function(filename) {
            const error = document.getElementById('filePickerError');

            if (!filename || !filename.trim()) {
                error.style.display = 'none';
                return false;
            }

            filename = filename.trim();

            if (!filename.endsWith('.md')) {
                error.textContent = 'Filename must end with .md';
                error.style.display = 'block';
                return false;
            }

            const illegalChars = /[<>:"|?*\x00-\x1f]/;
            if (illegalChars.test(filename)) {
                error.textContent = 'Filename contains illegal characters';
                error.style.display = 'block';
                return false;
            }

            if (filename.includes(' ')) {
                error.textContent = 'Use dashes instead of spaces';
                error.style.display = 'block';
                return false;
            }

            if (/^[.\-\/]/.test(filename)) {
                error.textContent = 'Filename cannot start with . - or /';
                error.style.display = 'block';
                return false;
            }

            error.style.display = 'none';
            return true;
        },

        /**
         * Get available target files
         * @private
         */
        _getAvailableFiles: function() {
            const files = new Set();
            document.querySelectorAll('.req-item[data-file]').forEach(item => {
                files.add(item.dataset.file);
            });
            state.userAddedFiles.forEach(f => files.add(f));
            return Array.from(files).sort();
        }
    };

    // ==========================================================================
    // Legend Modal
    // ==========================================================================

    /**
     * Legend modal operations
     */
    const legend = {
        /**
         * Open the legend modal
         */
        open: function() {
            document.getElementById('legend-modal').classList.remove('hidden');
        },

        /**
         * Close the legend modal
         */
        close: function() {
            document.getElementById('legend-modal').classList.add('hidden');
        }
    };

    // ==========================================================================
    // Navigation & View Management
    // ==========================================================================

    /**
     * Navigation operations for requirement tree
     */
    const navigation = {
        /**
         * Toggle a single requirement instance's children
         * @param {HTMLElement} element - The clicked element
         */
        toggleRequirement: function(element) {
            const item = element.closest('.req-item');
            const instanceId = item.dataset.instanceId;
            const icon = element.querySelector('.collapse-icon');

            if (!icon || !icon.textContent) return; // No children to collapse

            const isExpanding = state.collapsedInstances.has(instanceId);

            if (isExpanding) {
                state.collapsedInstances.delete(instanceId);
                icon.classList.remove('collapsed');
            } else {
                state.collapsedInstances.add(instanceId);
                icon.classList.add('collapsed');
            }

            if (state.currentView === 'hierarchy') {
                this.toggleRequirementHierarchy(instanceId, isExpanding);
            } else {
                if (isExpanding) {
                    this.showDescendants(instanceId);
                } else {
                    this.hideDescendants(instanceId);
                }
            }
            this.updateExpandCollapseButtons();
        },

        /**
         * Hide all descendants of a requirement instance
         * @param {string} parentInstanceId - Parent instance ID
         */
        hideDescendants: function(parentInstanceId) {
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.add('collapsed-by-parent');
                this.hideDescendants(child.dataset.instanceId);
            });
        },

        /**
         * Show immediate children of a requirement instance
         * @param {string} parentInstanceId - Parent instance ID
         */
        showDescendants: function(parentInstanceId) {
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.remove('collapsed-by-parent');
            });
        },

        /**
         * Modified toggle for hierarchy view
         * @param {string} parentInstanceId - Parent instance ID
         * @param {boolean} isExpanding - Whether expanding or collapsing
         */
        toggleRequirementHierarchy: function(parentInstanceId, isExpanding) {
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                if (isExpanding) {
                    child.classList.add('hierarchy-visible');
                    child.classList.remove('collapsed-by-parent');
                } else {
                    child.classList.remove('hierarchy-visible');
                    child.classList.add('collapsed-by-parent');
                    const childIcon = child.querySelector('.collapse-icon');
                    if (childIcon && childIcon.textContent) {
                        state.collapsedInstances.add(child.dataset.instanceId);
                        childIcon.classList.add('collapsed');
                        this.toggleRequirementHierarchy(child.dataset.instanceId, false);
                    }
                }
            });
        },

        /**
         * Update expand/collapse button states
         */
        updateExpandCollapseButtons: function() {
            const btnExpand = document.getElementById('btnExpandAll');
            const btnCollapse = document.getElementById('btnCollapseAll');

            let expandableCount = 0;
            let expandedCount = 0;
            let collapsedCount = 0;

            document.querySelectorAll('.req-item:not(.filtered-out)').forEach(item => {
                const icon = item.querySelector('.collapse-icon');
                if (icon && icon.textContent) {
                    expandableCount++;
                    if (icon.classList.contains('collapsed')) {
                        collapsedCount++;
                    } else {
                        expandedCount++;
                    }
                }
            });

            if (expandableCount > 0 && expandedCount === expandableCount) {
                btnExpand.classList.add('active');
                btnExpand.textContent = '▼ All Expanded';
            } else {
                btnExpand.classList.remove('active');
                btnExpand.textContent = '▼ Expand All';
            }

            if (expandableCount > 0 && collapsedCount === expandableCount) {
                btnCollapse.classList.add('active');
                btnCollapse.textContent = '▶ All Collapsed';
            } else {
                btnCollapse.classList.remove('active');
                btnCollapse.textContent = '▶ Collapse All';
            }
        },

        /**
         * Expand all requirements
         */
        expandAll: function() {
            state.collapsedInstances.clear();
            const isHierarchyView = state.currentView === 'hierarchy';
            document.querySelectorAll('.req-item').forEach(item => {
                item.classList.remove('collapsed-by-parent');
                if (isHierarchyView && item.dataset.isRoot !== 'true') {
                    item.classList.add('hierarchy-visible');
                }
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
            this.updateExpandCollapseButtons();
        },

        /**
         * Collapse all requirements
         */
        collapseAll: function() {
            const isHierarchyView = state.currentView === 'hierarchy';
            document.querySelectorAll('.req-item').forEach(item => {
                const icon = item.querySelector('.collapse-icon');
                if (isHierarchyView && item.dataset.isRoot !== 'true') {
                    item.classList.remove('hierarchy-visible');
                    item.classList.add('collapsed-by-parent');
                }
                if (icon && icon.textContent) {
                    state.collapsedInstances.add(item.dataset.instanceId);
                    this.hideDescendants(item.dataset.instanceId);
                    icon.classList.add('collapsed');
                }
            });
            this.updateExpandCollapseButtons();
        },

        /**
         * Switch between view modes
         * @param {string} viewMode - 'flat', 'hierarchy', 'uncommitted', or 'branch'
         */
        switchView: function(viewMode) {
            state.currentView = viewMode;
            const reqTree = document.getElementById('reqTree');
            const btnFlat = document.getElementById('btnFlatView');
            const btnHierarchy = document.getElementById('btnHierarchyView');
            const btnUncommitted = document.getElementById('btnUncommittedView');
            const btnBranch = document.getElementById('btnBranchView');
            const treeTitle = document.getElementById('treeTitle');

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
                state.collapsedInstances.clear();
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('collapsed-by-parent');
                    item.classList.remove('hierarchy-visible');
                    const icon = item.querySelector('.collapse-icon');
                    if (icon && icon.textContent && item.dataset.isRoot === 'true') {
                        state.collapsedInstances.add(item.dataset.instanceId);
                        icon.classList.add('collapsed');
                    }
                });
            } else if (viewMode === 'uncommitted') {
                btnUncommitted.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Uncommitted Changes';
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                });
                this.collapseAll();
            } else if (viewMode === 'branch') {
                btnBranch.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Changed vs Main';
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                });
                this.collapseAll();
            } else {
                btnFlat.classList.add('active');
                treeTitle.textContent = 'Traceability Tree - Flat View';
                reqTree.classList.add('flat-view');
                document.querySelectorAll('.req-item').forEach(item => {
                    item.classList.remove('hierarchy-visible');
                    item.classList.remove('collapsed-by-parent');
                });
            }

            applyFilters();
        }
    };

    // ==========================================================================
    // Filtering
    // ==========================================================================

    /**
     * Apply all filters to the requirement tree
     */
    function applyFilters() {
        const filterReqId = document.getElementById('filterReqId');
        const filterTitle = document.getElementById('filterTitle');
        const filterLevel = document.getElementById('filterLevel');
        const filterStatus = document.getElementById('filterStatus');
        const filterTopic = document.getElementById('filterTopic');
        const filterTests = document.getElementById('filterTests');
        const filterCoverage = document.getElementById('filterCoverage');
        const chkIncludeDeprecated = document.getElementById('chkIncludeDeprecated');
        const chkIncludeRoadmap = document.getElementById('chkIncludeRoadmap');

        const reqIdFilter = filterReqId ? filterReqId.value.toLowerCase().trim() : '';
        const titleFilter = filterTitle ? filterTitle.value.toLowerCase().trim() : '';
        const levelFilter = filterLevel ? filterLevel.value : '';
        const statusFilter = filterStatus ? filterStatus.value : '';
        const topicFilter = filterTopic ? filterTopic.value.toLowerCase().trim() : '';
        const testFilter = filterTests ? filterTests.value : '';
        const coverageFilter = filterCoverage ? filterCoverage.value : '';
        const isLeafOnly = state.leafOnlyActive;
        const includeDeprecated = chkIncludeDeprecated ? chkIncludeDeprecated.checked : false;
        const includeRoadmap = chkIncludeRoadmap ? chkIncludeRoadmap.checked : false;

        const isUncommittedView = state.currentView === 'uncommitted';
        const isBranchView = state.currentView === 'branch';
        const isModifiedView = isUncommittedView || isBranchView;
        const anyFilterActive = reqIdFilter || titleFilter || levelFilter || statusFilter ||
                               topicFilter || testFilter || coverageFilter || isLeafOnly || isModifiedView;

        let visibleCount = 0;
        const seenReqIds = new Set();
        const seenVisibleReqIds = new Set();
        const allReqIds = new Set();

        document.querySelectorAll('.req-item').forEach(item => {
            const reqId = item.dataset.reqId ? item.dataset.reqId.toLowerCase() : '';
            const isImplFile = item.classList.contains('impl-file');
            const status = item.dataset.status;

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

            if (reqIdFilter && !reqId.includes(reqIdFilter)) matches = false;
            if (titleFilter && !title.includes(titleFilter)) matches = false;
            if (levelFilter && level !== levelFilter) matches = false;
            if (statusFilter && status !== statusFilter) matches = false;
            if (topicFilter && topic !== topicFilter && !topic.startsWith(topicFilter + '-')) {
                matches = false;
            }

            if (testFilter && matches) {
                const testStatus = item.dataset.testStatus || 'not-tested';
                if (testFilter !== testStatus) matches = false;
            }

            if (coverageFilter && matches) {
                const coverage = item.dataset.coverage || 'none';
                if (coverageFilter !== coverage) matches = false;
            }

            if (isLeafOnly && matches && !isImplFile) {
                const hasChildren = item.dataset.hasChildren === 'true';
                if (hasChildren) matches = false;
            }

            if (!includeDeprecated && matches && !isImplFile) {
                if (status === 'Deprecated') matches = false;
            }

            if (!includeRoadmap && matches && !isImplFile) {
                const isRoadmap = item.dataset.roadmap === 'true';
                const isConflict = item.dataset.conflict === 'true';
                const isCycle = item.dataset.cycle === 'true';
                if (isRoadmap && !isConflict && !isCycle) matches = false;
            }

            if (matches && anyFilterActive && !isImplFile && seenReqIds.has(reqId)) {
                matches = false;
            }

            if (matches) {
                item.classList.remove('filtered-out');
                if (anyFilterActive) {
                    item.classList.remove('collapsed-by-parent');
                    if (!isImplFile) seenReqIds.add(reqId);
                }
                if (!isImplFile && reqId && !seenVisibleReqIds.has(reqId)) {
                    seenVisibleReqIds.add(reqId);
                    visibleCount++;
                }
            } else {
                item.classList.add('filtered-out');
            }
        });

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
        navigation.updateExpandCollapseButtons();
    }

    /**
     * Clear all filters
     */
    function clearFilters() {
        const filterReqId = document.getElementById('filterReqId');
        const filterTitle = document.getElementById('filterTitle');
        const filterLevel = document.getElementById('filterLevel');
        const filterStatus = document.getElementById('filterStatus');
        const filterTopic = document.getElementById('filterTopic');
        const filterTests = document.getElementById('filterTests');
        const filterCoverage = document.getElementById('filterCoverage');
        const btnLeafOnly = document.getElementById('btnLeafOnly');
        const chkIncludeDeprecated = document.getElementById('chkIncludeDeprecated');
        const chkIncludeRoadmap = document.getElementById('chkIncludeRoadmap');

        if (filterReqId) filterReqId.value = '';
        if (filterTitle) filterTitle.value = '';
        if (filterLevel) filterLevel.value = '';
        if (filterStatus) filterStatus.value = '';
        if (filterTopic) filterTopic.value = '';
        if (filterTests) filterTests.value = '';
        if (filterCoverage) filterCoverage.value = '';

        state.leafOnlyActive = false;
        if (btnLeafOnly) btnLeafOnly.classList.remove('active');
        if (chkIncludeDeprecated) chkIncludeDeprecated.checked = false;
        if (chkIncludeRoadmap) chkIncludeRoadmap.checked = false;

        toggleIncludeDeprecated();
    }

    // ==========================================================================
    // Leaf Only Filter
    // ==========================================================================

    /**
     * Toggle leaf-only filter
     */
    function toggleLeafOnly() {
        state.leafOnlyActive = !state.leafOnlyActive;
        const btn = document.getElementById('btnLeafOnly');
        if (state.leafOnlyActive) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
        applyFilters();
    }

    /**
     * Toggle include deprecated checkbox
     */
    function toggleIncludeDeprecated() {
        const includeDeprecated = document.getElementById('chkIncludeDeprecated').checked;

        ['PRD', 'OPS', 'DEV'].forEach(level => {
            const badge = document.getElementById('badge' + level);
            if (badge) {
                const count = includeDeprecated ? badge.dataset.all : badge.dataset.active;
                badge.textContent = level + ': ' + count;
            }
        });

        applyFilters();
    }

    /**
     * Toggle include roadmap checkbox
     */
    function toggleIncludeRoadmap() {
        applyFilters();
    }

    // ==========================================================================
    // Initialization (REQ-tv-d00003-J: addEventListener for dynamic elements)
    // ==========================================================================

    /**
     * Initialize TraceView
     */
    function init() {
        panel.initResize();

        // Close modals on escape key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                codeViewer.close();
                legend.close();
                filePicker.close();
            }
        });
    }

    // ==========================================================================
    // Public API
    // ==========================================================================

    return {
        // Sub-objects
        panel: panel,
        codeViewer: codeViewer,
        editMode: editMode,
        filePicker: filePicker,
        legend: legend,
        navigation: navigation,
        state: state,

        // Functions
        init: init,
        toggleLeafOnly: toggleLeafOnly,
        toggleIncludeDeprecated: toggleIncludeDeprecated,
        toggleIncludeRoadmap: toggleIncludeRoadmap,
        applyFilters: applyFilters,
        clearFilters: clearFilters
    };
})();

// ==========================================================================
// Global function aliases for backward compatibility with inline onclick handlers
// ==========================================================================

function openReqPanel(reqId) { TraceView.panel.open(reqId); }
function closeReqCard(reqId) { TraceView.panel.close(reqId); }
function closeAllCards() { TraceView.panel.closeAll(); }
function openCodeViewer(filePath, lineNum) { TraceView.codeViewer.open(filePath, lineNum); }
function closeCodeViewer() { TraceView.codeViewer.close(); }
function openLegendModal() { TraceView.legend.open(); }
function closeLegendModal() { TraceView.legend.close(); }
function toggleEditMode() { TraceView.editMode.toggle(); }
function addPendingMove(reqId, sourceFile, moveType) { TraceView.editMode.addMove(reqId, sourceFile, moveType); }
function removePendingMove(index) { TraceView.editMode.removeMove(index); }
function clearPendingMoves() { TraceView.editMode.clearMoves(); }
function togglePendingMoves() { TraceView.editMode.togglePendingMoves(); }
function generateMoveScript() { TraceView.editMode.generateScript(); }
function showMoveToFile(reqId, sourceFile) { TraceView.filePicker.show(reqId, sourceFile); }
function closeFilePicker() { TraceView.filePicker.close(); }
function filterFiles(value) { TraceView.filePicker.filter(value); }
function selectFile(filename) { TraceView.filePicker.select(filename); }
function confirmFilePicker() { TraceView.filePicker.confirm(); }
function toggleLeafOnly() { TraceView.toggleLeafOnly(); }
function toggleIncludeDeprecated() { TraceView.toggleIncludeDeprecated(); }
function toggleIncludeRoadmap() { TraceView.toggleIncludeRoadmap(); }

// Navigation functions
function toggleRequirement(element) { TraceView.navigation.toggleRequirement(element); }
function expandAll() { TraceView.navigation.expandAll(); }
function collapseAll() { TraceView.navigation.collapseAll(); }
function switchView(viewMode) { TraceView.navigation.switchView(viewMode); }
function applyFilters() { TraceView.applyFilters(); }
function clearFilters() { TraceView.clearFilters(); }

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', function() {
    TraceView.init();
    // Start with flat view - show all unique requirements at indent 0
    TraceView.navigation.switchView('flat');
});
