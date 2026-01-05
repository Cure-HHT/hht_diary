/**
 * Line-Numbered Markdown View Module
 *
 * Adds line numbers to rendered markdown content in REQ cards.
 * Users can click line numbers to select positions for comments.
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00092: HTML Report Integration (Phase 5.2)
 */

// Ensure ReviewSystem namespace exists
window.ReviewSystem = window.ReviewSystem || {};

(function(RS) {
    'use strict';

    // ==========================================================================
    // State Management
    // ==========================================================================

    // Selected line state (exposed globally for comment forms)
    window.selectedLineNumber = null;
    window.selectedLineRange = null;

    // Track shift-click for range selection
    let rangeStartLine = null;

    // ==========================================================================
    // Line Number Conversion
    // ==========================================================================

    /**
     * Convert rendered markdown HTML to line-numbered view
     *
     * Takes the raw markdown source and rendered HTML, then creates
     * a table-based layout with clickable line numbers.
     *
     * @param {string} rawMarkdown - Original markdown source text
     * @param {string} renderedHtml - HTML from marked.parse()
     * @param {string} reqId - Requirement ID for data attributes
     * @returns {string} HTML with line numbers table structure
     */
    function convertToLineNumberedView(rawMarkdown, renderedHtml, reqId) {
        if (!rawMarkdown) {
            return renderedHtml;
        }

        const lines = rawMarkdown.split('\n');
        const totalLines = lines.length;

        // Build the line-numbered table structure
        let html = `
            <div class="rs-line-numbers-hint">
                <span class="hint-text">Click line numbers to select position for comments</span>
                <span class="selected-lines" id="selected-lines-${reqId}"></span>
            </div>
            <div class="rs-line-numbers-container" data-req-id="${reqId}" data-total-lines="${totalLines}">
                <div class="rs-lines-table">
        `;

        lines.forEach((lineContent, idx) => {
            const lineNum = idx + 1;
            // Render each line as markdown (for inline formatting)
            const lineHtml = window.marked ? marked.parseInline(lineContent) : escapeHtml(lineContent);

            html += `
                <div class="rs-line-row" data-line="${lineNum}" data-source-line="${idx}">
                    <div class="rs-line-number" data-line="${lineNum}" title="Line ${lineNum}">${lineNum}</div>
                    <div class="rs-line-text">${lineHtml || '&nbsp;'}</div>
                </div>
            `;
        });

        html += `
                </div>
            </div>
        `;

        return html;
    }
    RS.convertToLineNumberedView = convertToLineNumberedView;

    /**
     * Escape HTML special characters
     * @param {string} text - Text to escape
     * @returns {string} Escaped text
     */
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // ==========================================================================
    // Line Selection Handlers
    // ==========================================================================

    /**
     * Handle line number click for position selection
     * Supports shift-click for range selection
     *
     * @param {Event} event - Click event
     */
    function handleLineClick(event) {
        const target = event.target;

        // Only handle clicks on line numbers or line rows
        if (!target.classList.contains('rs-line-number') &&
            !target.closest('.rs-line-row')) {
            return;
        }

        // Find the line row and number
        const lineRow = target.classList.contains('rs-line-row')
            ? target
            : target.closest('.rs-line-row');

        if (!lineRow) return;

        const lineNum = parseInt(lineRow.dataset.line, 10);
        if (isNaN(lineNum)) return;

        const container = lineRow.closest('.rs-line-numbers-container');
        const reqId = container?.dataset.reqId;

        // Shift-click for range selection
        if (event.shiftKey && rangeStartLine !== null) {
            const start = Math.min(rangeStartLine, lineNum);
            const end = Math.max(rangeStartLine, lineNum);
            selectLineRange(container, start, end, reqId);
        } else {
            // Single line selection
            rangeStartLine = lineNum;
            selectSingleLine(container, lineNum, reqId);
        }

        // Prevent text selection on shift-click
        if (event.shiftKey) {
            event.preventDefault();
        }
    }

    /**
     * Select a single line
     *
     * @param {Element} container - Line numbers container
     * @param {number} lineNum - Line number to select
     * @param {string} reqId - Requirement ID
     */
    function selectSingleLine(container, lineNum, reqId) {
        // Clear previous selection
        clearLineSelection(container);

        // Select the line
        const lineRow = container.querySelector(`.rs-line-row[data-line="${lineNum}"]`);
        if (lineRow) {
            lineRow.classList.add('selected');
        }

        // Update global state
        window.selectedLineNumber = lineNum;
        window.selectedLineRange = null;

        // Update hint display
        updateSelectionHint(reqId, `Line ${lineNum}`);

        // Dispatch event for other modules
        document.dispatchEvent(new CustomEvent('rs:line-selected', {
            detail: {
                reqId: reqId,
                lineNumber: lineNum,
                lineRange: null
            }
        }));
    }

    /**
     * Select a range of lines
     *
     * @param {Element} container - Line numbers container
     * @param {number} startLine - Start line number
     * @param {number} endLine - End line number
     * @param {string} reqId - Requirement ID
     */
    function selectLineRange(container, startLine, endLine, reqId) {
        // Clear previous selection
        clearLineSelection(container);

        // Select all lines in range
        for (let i = startLine; i <= endLine; i++) {
            const lineRow = container.querySelector(`.rs-line-row[data-line="${i}"]`);
            if (lineRow) {
                lineRow.classList.add('selected');
            }
        }

        // Update global state
        window.selectedLineNumber = null;
        window.selectedLineRange = [startLine, endLine];

        // Update hint display
        updateSelectionHint(reqId, `Lines ${startLine}-${endLine}`);

        // Dispatch event for other modules
        document.dispatchEvent(new CustomEvent('rs:line-selected', {
            detail: {
                reqId: reqId,
                lineNumber: null,
                lineRange: [startLine, endLine]
            }
        }));
    }

    /**
     * Clear all line selections in a container
     *
     * @param {Element} container - Line numbers container
     */
    function clearLineSelection(container) {
        if (!container) return;

        container.querySelectorAll('.rs-line-row.selected').forEach(row => {
            row.classList.remove('selected');
        });
    }
    RS.clearLineSelection = clearLineSelection;

    /**
     * Clear all line selections globally
     */
    function clearAllLineSelections() {
        document.querySelectorAll('.rs-line-numbers-container').forEach(container => {
            clearLineSelection(container);
            const reqId = container.dataset.reqId;
            if (reqId) {
                updateSelectionHint(reqId, '');
            }
        });

        window.selectedLineNumber = null;
        window.selectedLineRange = null;
        rangeStartLine = null;
    }
    RS.clearAllLineSelections = clearAllLineSelections;

    /**
     * Update the selection hint display
     *
     * @param {string} reqId - Requirement ID
     * @param {string} text - Text to display
     */
    function updateSelectionHint(reqId, text) {
        const hintEl = document.getElementById(`selected-lines-${reqId}`);
        if (hintEl) {
            hintEl.textContent = text;
        }
    }

    // ==========================================================================
    // DOM Integration
    // ==========================================================================

    /**
     * Apply line numbers to a REQ card's content
     *
     * @param {string} reqId - Requirement ID
     * @param {Element} contentEl - Content element to transform
     * @param {string} rawMarkdown - Original markdown source
     */
    function applyLineNumbersToCard(reqId, contentEl, rawMarkdown) {
        if (!contentEl || !rawMarkdown) return;

        // Get the rendered HTML from marked
        const renderedHtml = window.marked ? marked.parse(rawMarkdown) : rawMarkdown;

        // Convert to line-numbered view
        const lineNumberedHtml = convertToLineNumberedView(rawMarkdown, renderedHtml, reqId);

        // Replace content
        contentEl.innerHTML = lineNumberedHtml;
        contentEl.classList.add('rs-with-line-numbers');

        // Bind click handlers
        bindLineClickHandlers(contentEl);
    }
    RS.applyLineNumbersToCard = applyLineNumbersToCard;

    /**
     * Bind click handlers to line numbers in a container
     *
     * @param {Element} container - Container element
     */
    function bindLineClickHandlers(container) {
        if (!container) return;

        // Use event delegation on the container
        container.addEventListener('click', handleLineClick);
    }

    /**
     * Initialize line number functionality for all existing REQ cards
     */
    function initializeLineNumbers() {
        // Find all REQ cards and apply line numbers
        const reqData = window.REQ_CONTENT_DATA;
        if (!reqData) return;

        document.querySelectorAll('.req-card').forEach(card => {
            const reqId = card.id.replace('req-card-', '');
            const contentEl = card.querySelector('.req-card-content');
            const req = reqData[reqId];

            if (contentEl && req && req.body) {
                applyLineNumbersToCard(reqId, contentEl, req.body);
            }
        });
    }
    RS.initializeLineNumbers = initializeLineNumbers;

    // ==========================================================================
    // Integration with Comment Form
    // ==========================================================================

    /**
     * Get current line selection for comment form
     *
     * @returns {Object} Selection info {type, lineNumber, lineRange}
     */
    function getLineSelection() {
        if (window.selectedLineRange) {
            return {
                type: 'block',
                lineNumber: null,
                lineRange: window.selectedLineRange
            };
        } else if (window.selectedLineNumber) {
            return {
                type: 'line',
                lineNumber: window.selectedLineNumber,
                lineRange: null
            };
        }
        return {
            type: 'general',
            lineNumber: null,
            lineRange: null
        };
    }
    RS.getLineSelection = getLineSelection;

    // ==========================================================================
    // Keyboard Shortcuts
    // ==========================================================================

    /**
     * Handle keyboard shortcuts for line selection
     */
    function handleKeyboard(event) {
        // Escape clears selection
        if (event.key === 'Escape') {
            clearAllLineSelections();
        }
    }

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /**
     * Initialize the line numbers module
     */
    function init() {
        // Add keyboard listener
        document.addEventListener('keydown', handleKeyboard);

        // Listen for review mode changes
        document.addEventListener('rs:review-mode-changed', (event) => {
            if (!event.detail.active) {
                // Clear selections when leaving review mode
                clearAllLineSelections();
            }
        });

        console.log('[ReviewSystem] Line numbers module initialized');
    }

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})(window.ReviewSystem);
