/**
 * TraceView Review Position Highlighting Module
 *
 * Client-side position resolution and highlighting.
 * Handles exact, approximate, and unanchored positions.
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-tv-d00016: Review JavaScript Integration
 */

// Ensure TraceView.review namespace exists
window.TraceView = window.TraceView || {};
TraceView.review = TraceView.review || {};

(function(review) {
    'use strict';

    // ==========================================================================
    // Constants
    // ==========================================================================

    review.Confidence = Object.freeze({
        EXACT: 'exact',
        APPROXIMATE: 'approximate',
        UNANCHORED: 'unanchored'
    });

    // CSS classes for highlighting
    review.HighlightClass = {
        EXACT: 'rs-highlight-exact',
        APPROXIMATE: 'rs-highlight-approximate',
        UNANCHORED: 'rs-highlight-unanchored',
        ACTIVE: 'rs-highlight-active'
    };

    // ==========================================================================
    // Resolved Position
    // ==========================================================================

    /**
     * Result of position resolution
     */
    class ResolvedPosition {
        constructor(data) {
            this.originalPosition = data.originalPosition;
            this.confidence = data.confidence;
            this.lineNumber = data.lineNumber || null;
            this.lineRange = data.lineRange || null;
            this.charStart = data.charStart || null;
            this.charEnd = data.charEnd || null;
            this.resolvedType = data.resolvedType;
            this.message = data.message || null;
        }

        /**
         * Check if position is exact match
         * @returns {boolean}
         */
        isExact() {
            return this.confidence === review.Confidence.EXACT;
        }

        /**
         * Check if position is approximate
         * @returns {boolean}
         */
        isApproximate() {
            return this.confidence === review.Confidence.APPROXIMATE;
        }

        /**
         * Check if position is unanchored
         * @returns {boolean}
         */
        isUnanchored() {
            return this.confidence === review.Confidence.UNANCHORED;
        }

        /**
         * Get CSS class for highlighting
         * @returns {string}
         */
        getHighlightClass() {
            switch (this.confidence) {
                case review.Confidence.EXACT: return review.HighlightClass.EXACT;
                case review.Confidence.APPROXIMATE: return review.HighlightClass.APPROXIMATE;
                default: return review.HighlightClass.UNANCHORED;
            }
        }
    }
    review.ResolvedPosition = ResolvedPosition;

    // ==========================================================================
    // Position Resolution Functions
    // ==========================================================================

    /**
     * Get total number of lines in text
     * @param {string} text - Text content
     * @returns {number} Line count
     */
    function getTotalLines(text) {
        if (!text) return 0;
        return text.split('\n').length;
    }
    review.getTotalLines = getTotalLines;

    /**
     * Get line number from character offset
     * @param {string} text - Text content
     * @param {number} offset - Character offset
     * @returns {number} 1-based line number
     */
    function getLineNumberFromCharOffset(text, offset) {
        if (!text || offset < 0) return 1;
        const before = text.substring(0, offset);
        return before.split('\n').length;
    }
    review.getLineNumberFromCharOffset = getLineNumberFromCharOffset;

    /**
     * Get character range for a line
     * @param {string} text - Text content
     * @param {number} lineNum - 1-based line number
     * @returns {Object} {start, end} character offsets
     */
    function getLineCharRange(text, lineNum) {
        if (!text || lineNum < 1) return { start: 0, end: 0 };

        const lines = text.split('\n');
        if (lineNum > lines.length) return { start: text.length, end: text.length };

        let start = 0;
        for (let i = 0; i < lineNum - 1; i++) {
            start += lines[i].length + 1; // +1 for newline
        }
        const end = start + lines[lineNum - 1].length;

        return { start, end };
    }
    review.getLineCharRange = getLineCharRange;

    /**
     * Find line number containing search text
     * @param {string} text - Text content
     * @param {string} search - Text to find
     * @returns {number|null} 1-based line number or null
     */
    function findLineInText(text, search) {
        if (!text || !search) return null;

        const idx = text.indexOf(search);
        if (idx === -1) return null;

        return getLineNumberFromCharOffset(text, idx);
    }
    review.findLineInText = findLineInText;

    /**
     * Find context string position in text
     * @param {string} text - Text content
     * @param {string} context - Context to find
     * @returns {Object|null} {start, end, line} or null
     */
    function findContextInText(text, context) {
        if (!text || !context) return null;

        const idx = text.indexOf(context);
        if (idx === -1) return null;

        return {
            start: idx,
            end: idx + context.length,
            line: getLineNumberFromCharOffset(text, idx)
        };
    }
    review.findContextInText = findContextInText;

    /**
     * Find nth occurrence of keyword in text
     * @param {string} text - Text content
     * @param {string} keyword - Keyword to find
     * @param {number} occurrence - 1-based occurrence index
     * @returns {Object|null} {start, end, line} or null
     */
    function findKeywordOccurrence(text, keyword, occurrence) {
        if (!text || !keyword || occurrence < 1) return null;

        let count = 0;
        let idx = -1;

        while (count < occurrence) {
            idx = text.indexOf(keyword, idx + 1);
            if (idx === -1) return null;
            count++;
        }

        return {
            start: idx,
            end: idx + keyword.length,
            line: getLineNumberFromCharOffset(text, idx)
        };
    }
    review.findKeywordOccurrence = findKeywordOccurrence;

    /**
     * Resolve a comment position against current content
     * @param {CommentPosition} position - Position to resolve
     * @param {string} currentContent - Current REQ content
     * @param {string} currentHash - Current content hash
     * @returns {ResolvedPosition} Resolved position
     */
    function resolvePosition(position, currentContent, currentHash) {
        // Check for exact match
        if (position.hashWhenCreated === currentHash) {
            return resolveExact(position, currentContent);
        }

        // Hash mismatch - try fallback strategies
        return resolveWithFallback(position, currentContent);
    }
    review.resolvePosition = resolvePosition;

    /**
     * Resolve position with exact hash match
     * @param {CommentPosition} position - Position
     * @param {string} content - Content
     * @returns {ResolvedPosition}
     */
    function resolveExact(position, content) {
        const totalLines = getTotalLines(content);

        switch (position.type) {
            case review.PositionType.LINE: {
                if (position.lineNumber > totalLines) {
                    return new ResolvedPosition({
                        originalPosition: position,
                        confidence: review.Confidence.UNANCHORED,
                        resolvedType: 'general',
                        message: 'Line number out of range'
                    });
                }
                const range = getLineCharRange(content, position.lineNumber);
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.EXACT,
                    lineNumber: position.lineNumber,
                    charStart: range.start,
                    charEnd: range.end,
                    resolvedType: 'line'
                });
            }

            case review.PositionType.BLOCK: {
                const [startLine, endLine] = position.lineRange;
                if (startLine > totalLines) {
                    return new ResolvedPosition({
                        originalPosition: position,
                        confidence: review.Confidence.UNANCHORED,
                        resolvedType: 'general',
                        message: 'Block start out of range'
                    });
                }
                const actualEnd = Math.min(endLine, totalLines);
                const startRange = getLineCharRange(content, startLine);
                const endRange = getLineCharRange(content, actualEnd);
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.EXACT,
                    lineRange: [startLine, actualEnd],
                    charStart: startRange.start,
                    charEnd: endRange.end,
                    resolvedType: 'block'
                });
            }

            case review.PositionType.WORD: {
                const found = findKeywordOccurrence(
                    content,
                    position.keyword,
                    position.keywordOccurrence || 1
                );
                if (!found) {
                    return new ResolvedPosition({
                        originalPosition: position,
                        confidence: review.Confidence.UNANCHORED,
                        resolvedType: 'general',
                        message: 'Keyword not found'
                    });
                }
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.EXACT,
                    lineNumber: found.line,
                    charStart: found.start,
                    charEnd: found.end,
                    resolvedType: 'word'
                });
            }

            case review.PositionType.GENERAL:
            default:
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.EXACT,
                    resolvedType: 'general'
                });
        }
    }

    /**
     * Resolve position with fallback strategies (hash mismatch)
     * @param {CommentPosition} position - Position
     * @param {string} content - Content
     * @returns {ResolvedPosition}
     */
    function resolveWithFallback(position, content) {
        const totalLines = getTotalLines(content);

        // Strategy 1: Try line number if available and in range
        let lineToTry = position.lineNumber;
        if (lineToTry === null && position.lineRange) {
            lineToTry = position.lineRange[0];
        }

        if (lineToTry !== null && lineToTry <= totalLines) {
            const range = getLineCharRange(content, lineToTry);
            return new ResolvedPosition({
                originalPosition: position,
                confidence: review.Confidence.APPROXIMATE,
                lineNumber: lineToTry,
                charStart: range.start,
                charEnd: range.end,
                resolvedType: 'line',
                message: 'Position approximated from line number'
            });
        }

        // Strategy 2: Try fallback context
        if (position.fallbackContext) {
            const found = findContextInText(content, position.fallbackContext);
            if (found) {
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.APPROXIMATE,
                    lineNumber: found.line,
                    charStart: found.start,
                    charEnd: found.end,
                    resolvedType: 'context',
                    message: 'Position found via context string'
                });
            }
        }

        // Strategy 3: Try keyword search
        if (position.keyword) {
            const found = findKeywordOccurrence(
                content,
                position.keyword,
                position.keywordOccurrence || 1
            );
            if (found) {
                return new ResolvedPosition({
                    originalPosition: position,
                    confidence: review.Confidence.APPROXIMATE,
                    lineNumber: found.line,
                    charStart: found.start,
                    charEnd: found.end,
                    resolvedType: 'word',
                    message: 'Position found via keyword'
                });
            }
        }

        // All fallbacks failed - return general
        return new ResolvedPosition({
            originalPosition: position,
            confidence: review.Confidence.UNANCHORED,
            resolvedType: 'general',
            message: 'Could not resolve position'
        });
    }

    // ==========================================================================
    // DOM Highlighting
    // ==========================================================================

    /**
     * Highlight a resolved position in a content element
     * @param {Element} element - Content element
     * @param {ResolvedPosition} position - Resolved position
     * @param {string} threadId - Thread ID for data attribute
     */
    function highlightPosition(element, position, threadId) {
        if (!element || position.isUnanchored()) {
            // For general/unanchored, highlight whole element border
            if (element) {
                element.classList.add('rs-has-comments');
            }
            return;
        }

        const content = element.textContent || element.innerText;

        if (position.charStart !== null && position.charEnd !== null) {
            // Wrap the specific range with a highlight span
            highlightCharRange(element, position.charStart, position.charEnd,
                position.getHighlightClass(), threadId);
        } else if (position.lineNumber !== null) {
            // Highlight whole line
            highlightLine(element, position.lineNumber,
                position.getHighlightClass(), threadId);
        } else if (position.lineRange !== null) {
            // Highlight line range
            for (let i = position.lineRange[0]; i <= position.lineRange[1]; i++) {
                highlightLine(element, i, position.getHighlightClass(), threadId);
            }
        }
    }
    review.highlightPosition = highlightPosition;

    /**
     * Highlight a character range in an element
     * @param {Element} element - Content element
     * @param {number} start - Start offset
     * @param {number} end - End offset
     * @param {string} className - CSS class
     * @param {string} threadId - Thread ID
     */
    function highlightCharRange(element, start, end, className, threadId) {
        const text = element.textContent || element.innerText;
        if (start >= text.length || end <= start) return;

        const before = text.substring(0, start);
        const highlight = text.substring(start, end);
        const after = text.substring(end);

        const span = document.createElement('span');
        span.className = className;
        span.textContent = highlight;
        if (threadId) {
            span.setAttribute('data-thread-id', threadId);
        }

        element.innerHTML = '';
        element.appendChild(document.createTextNode(before));
        element.appendChild(span);
        element.appendChild(document.createTextNode(after));
    }

    /**
     * Highlight a specific line in an element
     * @param {Element} element - Content element (assuming line-based structure)
     * @param {number} lineNum - 1-based line number
     * @param {string} className - CSS class
     * @param {string} threadId - Thread ID
     */
    function highlightLine(element, lineNum, className, threadId) {
        // Look for line-based children or create wrapper
        const lines = element.querySelectorAll('.req-line, .code-line, [data-line]');

        if (lines.length > 0) {
            // Use existing line elements
            if (lineNum <= lines.length) {
                const line = lines[lineNum - 1];
                line.classList.add(className);
                if (threadId) {
                    line.setAttribute('data-thread-id', threadId);
                }
            }
        } else {
            // Fallback: wrap line in content
            const text = element.textContent || element.innerText;
            const textLines = text.split('\n');

            if (lineNum <= textLines.length) {
                element.innerHTML = '';
                textLines.forEach((line, i) => {
                    const lineEl = document.createElement('div');
                    lineEl.className = 'req-line';
                    lineEl.setAttribute('data-line', String(i + 1));
                    lineEl.textContent = line;

                    if (i + 1 === lineNum) {
                        lineEl.classList.add(className);
                        if (threadId) {
                            lineEl.setAttribute('data-thread-id', threadId);
                        }
                    }

                    element.appendChild(lineEl);
                });
            }
        }
    }

    /**
     * Clear all highlights from an element
     * @param {Element} element - Content element
     */
    function clearHighlights(element) {
        if (!element) return;

        // Remove highlight classes
        element.classList.remove('rs-has-comments');
        const highlighted = element.querySelectorAll(
            `.${review.HighlightClass.EXACT}, .${review.HighlightClass.APPROXIMATE}, ` +
            `.${review.HighlightClass.UNANCHORED}, .${review.HighlightClass.ACTIVE}`
        );
        highlighted.forEach(el => {
            el.classList.remove(
                review.HighlightClass.EXACT,
                review.HighlightClass.APPROXIMATE,
                review.HighlightClass.UNANCHORED,
                review.HighlightClass.ACTIVE
            );
        });
    }
    review.clearHighlights = clearHighlights;

    /**
     * Activate a specific highlight (make it stand out)
     * @param {string} threadId - Thread ID to activate
     */
    function activateHighlight(threadId) {
        // Deactivate all first
        document.querySelectorAll('.' + review.HighlightClass.ACTIVE).forEach(el => {
            el.classList.remove(review.HighlightClass.ACTIVE);
        });

        // Activate matching
        if (threadId) {
            document.querySelectorAll(`[data-thread-id="${threadId}"]`).forEach(el => {
                el.classList.add(review.HighlightClass.ACTIVE);
            });
        }
    }
    review.activateHighlight = activateHighlight;

})(TraceView.review);
