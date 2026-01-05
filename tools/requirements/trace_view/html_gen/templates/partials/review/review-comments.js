/**
 * Spec Review Comment UI Module
 *
 * User interface for comment threads:
 * - Thread rendering (collapsible)
 * - Comment form (new thread, reply)
 * - Resolve/unresolve actions
 * - Position selection UI
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00086: Spec Review Data Model
 */

// Ensure ReviewSystem namespace exists
window.ReviewSystem = window.ReviewSystem || {};

(function(RS) {
    'use strict';

    // ==========================================================================
    // Templates
    // ==========================================================================

    /**
     * Create thread list container HTML
     * @param {string} reqId - Requirement ID
     * @returns {string} HTML
     */
    function threadListTemplate(reqId) {
        return `
            <div class="rs-thread-list" data-req-id="${reqId}">
                <div class="rs-thread-list-header">
                    <h4>Comments</h4>
                    <button class="rs-btn rs-btn-primary rs-add-comment-btn" title="Add comment">
                        + Add Comment
                    </button>
                </div>
                <div class="rs-thread-list-content">
                    <div class="rs-threads"></div>
                    <div class="rs-no-threads" style="display: none;">
                        No comments yet.
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Create thread HTML
     * @param {Thread} thread - Thread object
     * @returns {string} HTML
     */
    function threadTemplate(thread) {
        const resolvedClass = thread.resolved ? 'rs-thread-resolved' : '';
        const resolvedBadge = thread.resolved ?
            `<span class="rs-badge rs-badge-resolved">Resolved</span>` : '';
        const confidenceClass = getConfidenceClass(thread);

        return `
            <div class="rs-thread ${resolvedClass}" data-thread-id="${thread.threadId}">
                <div class="rs-thread-header">
                    <div class="rs-thread-meta">
                        <span class="rs-position-label ${confidenceClass}"
                              data-thread-id="${thread.threadId}"
                              data-position-type="${thread.position?.type || 'general'}"
                              title="Click to highlight in REQ (click again to clear)">
                            ${getPositionIcon(thread)} ${getPositionLabel(thread)}
                        </span>
                        ${resolvedBadge}
                    </div>
                    <div class="rs-thread-actions">
                        ${thread.resolved ?
                            `<button class="rs-btn rs-btn-sm rs-unresolve-btn">Reopen</button>` :
                            `<button class="rs-btn rs-btn-sm rs-resolve-btn">Resolve</button>`
                        }
                        <button class="rs-btn rs-btn-sm rs-collapse-btn" title="Collapse">▼</button>
                    </div>
                </div>
                <div class="rs-thread-body">
                    <div class="rs-comments">
                        ${thread.comments.map(c => commentTemplate(c)).join('')}
                    </div>
                    <div class="rs-reply-form" style="display: none;">
                        <textarea class="rs-reply-input" placeholder="Write a reply..."></textarea>
                        <div class="rs-reply-actions">
                            <button class="rs-btn rs-btn-primary rs-submit-reply">Reply</button>
                            <button class="rs-btn rs-cancel-reply">Cancel</button>
                        </div>
                    </div>
                    <button class="rs-btn rs-btn-link rs-show-reply-btn">Reply</button>
                </div>
            </div>
        `;
    }

    /**
     * Create comment HTML
     * @param {Comment} comment - Comment object
     * @returns {string} HTML
     */
    function commentTemplate(comment) {
        return `
            <div class="rs-comment" data-comment-id="${comment.id}">
                <div class="rs-comment-header">
                    <span class="rs-author">${escapeHtml(comment.author)}</span>
                    <span class="rs-time">${formatTime(comment.timestamp)}</span>
                </div>
                <div class="rs-comment-body">
                    ${formatCommentBody(comment.body)}
                </div>
            </div>
        `;
    }

    /**
     * Create new comment form HTML
     * @param {string} reqId - Requirement ID
     * @returns {string} HTML
     */
    function newCommentFormTemplate(reqId) {
        return `
            <div class="rs-new-comment-form" data-req-id="${reqId}">
                <h4>New Comment</h4>
                <div class="rs-form-group">
                    <label>Position</label>
                    <select class="rs-position-type">
                        <option value="general">General (whole requirement)</option>
                        <option value="line">Specific line</option>
                        <option value="block">Line range</option>
                        <option value="word">Word/phrase</option>
                    </select>
                </div>
                <div class="rs-position-options" style="display: none;">
                    <div class="rs-line-options" style="display: none;">
                        <label>Line number</label>
                        <input type="number" class="rs-line-input" min="1" value="1">
                    </div>
                    <div class="rs-block-options" style="display: none;">
                        <label>Line range</label>
                        <input type="number" class="rs-block-start" min="1" value="1">
                        <span>to</span>
                        <input type="number" class="rs-block-end" min="1" value="1">
                    </div>
                    <div class="rs-word-options" style="display: none;">
                        <label>Word/phrase</label>
                        <input type="text" class="rs-keyword" placeholder="Enter word or phrase">
                        <label>Occurrence</label>
                        <input type="number" class="rs-keyword-occurrence" min="1" value="1">
                    </div>
                </div>
                <div class="rs-form-group">
                    <label>Comment</label>
                    <textarea class="rs-comment-body-input"
                              placeholder="Write your comment..." rows="4"></textarea>
                </div>
                <div class="rs-form-actions">
                    <button class="rs-btn rs-btn-primary rs-submit-comment">Add Comment</button>
                    <button class="rs-btn rs-cancel-comment">Cancel</button>
                </div>
            </div>
        `;
    }

    // ==========================================================================
    // Helper Functions
    // ==========================================================================

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function formatTime(isoString) {
        try {
            const date = new Date(isoString);
            const now = new Date();
            const diff = now - date;

            if (diff < 60000) return 'just now';
            if (diff < 3600000) return Math.floor(diff / 60000) + 'm ago';
            if (diff < 86400000) return Math.floor(diff / 3600000) + 'h ago';
            if (diff < 604800000) return Math.floor(diff / 86400000) + 'd ago';

            return date.toLocaleDateString();
        } catch (e) {
            return isoString;
        }
    }

    function formatCommentBody(body) {
        // Simple markdown-like formatting
        let html = escapeHtml(body);
        // Bold
        html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        // Italic
        html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
        // Code
        html = html.replace(/`(.+?)`/g, '<code>$1</code>');
        // Line breaks
        html = html.replace(/\n/g, '<br>');
        return html;
    }

    /**
     * Get CSS class based on resolved position confidence
     * @param {Thread} thread - Thread object
     * @returns {string} CSS class for confidence styling
     */
    function getConfidenceClass(thread) {
        // If thread has a resolved position with confidence, use it
        if (thread.resolvedPosition && thread.resolvedPosition.confidence) {
            const confidence = thread.resolvedPosition.confidence;
            if (confidence === RS.Confidence.EXACT || confidence === 'exact') {
                return 'rs-confidence-exact';
            } else if (confidence === RS.Confidence.APPROXIMATE || confidence === 'approximate') {
                return 'rs-confidence-approximate';
            } else if (confidence === RS.Confidence.UNANCHORED || confidence === 'unanchored') {
                return 'rs-confidence-unanchored';
            }
        }
        // Fallback: infer from position type
        if (thread.position) {
            if (thread.position.type === RS.PositionType.GENERAL) {
                return 'rs-confidence-unanchored';
            }
            // If position has specific location data, assume exact until resolved
            return 'rs-confidence-exact';
        }
        return '';
    }

    function getPositionIcon(thread) {
        switch (thread.position.type) {
            case RS.PositionType.LINE: return '📍';
            case RS.PositionType.BLOCK: return '📋';
            case RS.PositionType.WORD: return '🔤';
            default: return '📝';
        }
    }

    function getPositionTooltip(thread) {
        const pos = thread.position;
        switch (pos.type) {
            case RS.PositionType.LINE:
                return `Line ${pos.lineNumber}`;
            case RS.PositionType.BLOCK:
                return `Lines ${pos.lineRange[0]}-${pos.lineRange[1]}`;
            case RS.PositionType.WORD:
                return `"${pos.keyword}" (occurrence ${pos.keywordOccurrence || 1})`;
            default:
                return 'General comment';
        }
    }

    function getPositionLabel(thread) {
        const pos = thread.position;
        switch (pos.type) {
            case RS.PositionType.LINE:
                return `Line ${pos.lineNumber}`;
            case RS.PositionType.BLOCK:
                return `Lines ${pos.lineRange[0]}-${pos.lineRange[1]}`;
            case RS.PositionType.WORD:
                return `"${escapeHtml(pos.keyword)}"`;
            default:
                return 'General';
        }
    }

    // ==========================================================================
    // UI Components
    // ==========================================================================

    /**
     * Render thread list for a requirement
     * @param {Element} container - Container element
     * @param {string} reqId - Requirement ID
     */
    function renderThreadList(container, reqId) {
        container.innerHTML = threadListTemplate(reqId);

        const threads = RS.state.getThreads(reqId);
        const threadsContainer = container.querySelector('.rs-threads');
        const noThreads = container.querySelector('.rs-no-threads');

        if (threads.length === 0) {
            noThreads.style.display = 'block';
        } else {
            threads.forEach(thread => {
                threadsContainer.insertAdjacentHTML('beforeend', threadTemplate(thread));
            });
            bindThreadEvents(container);
        }

        // Bind add comment button
        const addBtn = container.querySelector('.rs-add-comment-btn');
        if (addBtn) {
            addBtn.addEventListener('click', () => showNewCommentForm(container, reqId));
        }
    }
    RS.renderThreadList = renderThreadList;

    /**
     * Show new comment form
     * @param {Element} container - Container element
     * @param {string} reqId - Requirement ID
     */
    function showNewCommentForm(container, reqId) {
        // Check if form already exists
        let form = container.querySelector('.rs-new-comment-form');
        if (form) {
            form.remove();
        }

        container.insertAdjacentHTML('afterbegin', newCommentFormTemplate(reqId));
        form = container.querySelector('.rs-new-comment-form');

        // Position type change handler
        const posType = form.querySelector('.rs-position-type');
        const posOptions = form.querySelector('.rs-position-options');
        const lineOpts = form.querySelector('.rs-line-options');
        const blockOpts = form.querySelector('.rs-block-options');
        const wordOpts = form.querySelector('.rs-word-options');

        posType.addEventListener('change', () => {
            const val = posType.value;
            posOptions.style.display = val === 'general' ? 'none' : 'block';
            lineOpts.style.display = val === 'line' ? 'block' : 'none';
            blockOpts.style.display = val === 'block' ? 'block' : 'none';
            wordOpts.style.display = val === 'word' ? 'block' : 'none';
        });

        // Check for existing line selection (global variables from review init)
        if (typeof selectedLineRange !== 'undefined' && selectedLineRange) {
            // Range selection
            posType.value = 'block';
            posType.dispatchEvent(new Event('change'));
            const startInput = form.querySelector('.rs-block-start');
            const endInput = form.querySelector('.rs-block-end');
            if (startInput) startInput.value = selectedLineRange[0];
            if (endInput) endInput.value = selectedLineRange[1];
        } else if (typeof selectedLineNumber !== 'undefined' && selectedLineNumber) {
            // Single line selection
            posType.value = 'line';
            posType.dispatchEvent(new Event('change'));
            const lineInput = form.querySelector('.rs-line-input');
            if (lineInput) lineInput.value = selectedLineNumber;
        }

        // Submit handler
        form.querySelector('.rs-submit-comment').addEventListener('click', () => {
            submitNewComment(form, reqId);
        });

        // Cancel handler
        form.querySelector('.rs-cancel-comment').addEventListener('click', () => {
            form.remove();
        });

        // Focus textarea
        form.querySelector('.rs-comment-body-input').focus();
    }
    RS.showNewCommentForm = showNewCommentForm;

    /**
     * Submit new comment
     * @param {Element} form - Form element
     * @param {string} reqId - Requirement ID
     */
    function submitNewComment(form, reqId) {
        const body = form.querySelector('.rs-comment-body-input').value.trim();
        if (!body) {
            alert('Please enter a comment');
            return;
        }

        const user = RS.state.currentUser || 'anonymous';
        const posType = form.querySelector('.rs-position-type').value;

        // Get current REQ hash (would come from embedded data)
        const hash = window.REQ_CONTENT_DATA?.[reqId]?.hash || '00000000';

        // Create position based on type
        let position;
        switch (posType) {
            case 'line': {
                const lineNum = parseInt(form.querySelector('.rs-line-input').value, 10);
                position = RS.CommentPosition.createLine(hash, lineNum);
                break;
            }
            case 'block': {
                const start = parseInt(form.querySelector('.rs-block-start').value, 10);
                const end = parseInt(form.querySelector('.rs-block-end').value, 10);
                position = RS.CommentPosition.createBlock(hash, start, end);
                break;
            }
            case 'word': {
                const keyword = form.querySelector('.rs-keyword').value.trim();
                const occurrence = parseInt(form.querySelector('.rs-keyword-occurrence').value, 10);
                if (!keyword) {
                    alert('Please enter a word or phrase');
                    return;
                }
                position = RS.CommentPosition.createWord(hash, keyword, occurrence);
                break;
            }
            default:
                position = RS.CommentPosition.createGeneral(hash);
        }

        // Create thread
        const thread = RS.Thread.create(reqId, user, position, body);
        RS.state.addThread(thread);

        // Auto-change status to Review if currently Draft
        const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
        if (reqData && reqData.status === 'Draft' && typeof RS.toggleToReview === 'function') {
            RS.toggleToReview(reqId).then(result => {
                if (result.success) {
                    console.log(`Auto-changed REQ-${reqId} status to Review`);
                }
            }).catch(err => {
                console.warn('Failed to auto-change status:', err);
            });
        }

        // Trigger change event
        document.dispatchEvent(new CustomEvent('rs:thread-created', {
            detail: { thread, reqId }
        }));

        // Re-render the thread list
        // The form is inside #review-panel-content, find the thread list's parent container
        const threadList = form.closest('.rs-thread-list') ||
                          form.parentElement?.querySelector('.rs-thread-list');
        const reviewPanelContent = document.getElementById('review-panel-content');

        if (threadList && threadList.parentElement) {
            renderThreadList(threadList.parentElement, reqId);
        } else if (reviewPanelContent) {
            // Form is directly in review-panel-content, re-render there
            renderThreadList(reviewPanelContent, reqId);
        } else {
            form.remove();
        }
    }

    /**
     * Bind event handlers to thread elements
     * @param {Element} container - Container element
     */
    function bindThreadEvents(container) {
        // Collapse/expand buttons
        container.querySelectorAll('.rs-collapse-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const thread = btn.closest('.rs-thread');
                const body = thread.querySelector('.rs-thread-body');
                const isCollapsed = body.style.display === 'none';
                body.style.display = isCollapsed ? 'block' : 'none';
                btn.textContent = isCollapsed ? '▼' : '▶';
            });
        });

        // Resolve buttons
        container.querySelectorAll('.rs-resolve-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const threadEl = btn.closest('.rs-thread');
                const threadId = threadEl.getAttribute('data-thread-id');
                resolveThread(threadId, container);
            });
        });

        // Unresolve buttons
        container.querySelectorAll('.rs-unresolve-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const threadEl = btn.closest('.rs-thread');
                const threadId = threadEl.getAttribute('data-thread-id');
                unresolveThread(threadId, container);
            });
        });

        // Reply buttons
        container.querySelectorAll('.rs-show-reply-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const thread = btn.closest('.rs-thread');
                const replyForm = thread.querySelector('.rs-reply-form');
                replyForm.style.display = 'block';
                btn.style.display = 'none';
                replyForm.querySelector('.rs-reply-input').focus();
            });
        });

        // Cancel reply
        container.querySelectorAll('.rs-cancel-reply').forEach(btn => {
            btn.addEventListener('click', () => {
                const thread = btn.closest('.rs-thread');
                const replyForm = thread.querySelector('.rs-reply-form');
                const showBtn = thread.querySelector('.rs-show-reply-btn');
                replyForm.style.display = 'none';
                replyForm.querySelector('.rs-reply-input').value = '';
                showBtn.style.display = 'inline-block';
            });
        });

        // Submit reply
        container.querySelectorAll('.rs-submit-reply').forEach(btn => {
            btn.addEventListener('click', () => {
                const threadEl = btn.closest('.rs-thread');
                submitReply(threadEl, container);
            });
        });

        // Hover to highlight position
        container.querySelectorAll('.rs-thread').forEach(threadEl => {
            threadEl.addEventListener('mouseenter', () => {
                const threadId = threadEl.getAttribute('data-thread-id');
                RS.activateHighlight(threadId);
            });
            threadEl.addEventListener('mouseleave', () => {
                RS.activateHighlight(null);
            });
        });

        // Position label click handler with toggle behavior
        container.querySelectorAll('.rs-position-label').forEach(label => {
            label.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent thread click handler

                const threadId = label.getAttribute('data-thread-id');
                const isActive = label.classList.contains('rs-position-active');

                // Clear all active position labels
                container.querySelectorAll('.rs-position-label.rs-position-active').forEach(l => {
                    l.classList.remove('rs-position-active');
                });

                if (isActive) {
                    // Toggle off - clear highlights
                    clearAllPositionHighlights(container);
                } else {
                    // Toggle on - highlight position
                    label.classList.add('rs-position-active');
                    highlightThreadPositionInCard(threadId, container);
                }
            });
        });
    }

    /**
     * Get highlight class based on thread's resolved position confidence
     * IMPLEMENTS REQUIREMENTS:
     *   REQ-d00092: HTML Report Integration
     *   REQ-d00087: Position Resolution with Fallback
     *
     * @param {Thread} thread - Thread object
     * @returns {string} CSS class for highlight style
     */
    function getHighlightClassForThread(thread) {
        // Check resolved position confidence first
        if (thread.resolvedPosition && thread.resolvedPosition.confidence) {
            const confidence = thread.resolvedPosition.confidence;
            if (confidence === RS.Confidence.EXACT || confidence === 'exact') {
                return 'rs-highlight-exact';
            } else if (confidence === RS.Confidence.APPROXIMATE || confidence === 'approximate') {
                return 'rs-highlight-approximate';
            } else if (confidence === RS.Confidence.UNANCHORED || confidence === 'unanchored') {
                return 'rs-highlight-unanchored';
            }
        }
        // Fallback based on position type
        if (thread.position) {
            if (thread.position.type === RS.PositionType.GENERAL) {
                return 'rs-highlight-unanchored';
            }
        }
        // Default to exact for specific positions
        return 'rs-highlight-exact';
    }

    /**
     * Highlight the position referenced by a thread in the REQ card
     * IMPLEMENTS REQUIREMENTS:
     *   REQ-d00092: HTML Report Integration
     *   REQ-d00087: Position Resolution with Fallback
     *
     * @param {string} threadId - Thread ID
     * @param {Element} container - Container element
     */
    function highlightThreadPositionInCard(threadId, container) {
        // Get the reqId and find the thread
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id') ||
                      (typeof currentReviewReqId !== 'undefined' ? currentReviewReqId : null);

        if (!reqId) return;

        const threads = RS.state.getThreads(reqId);
        const thread = threads.find(t => t.threadId === threadId);
        if (!thread || !thread.position) return;

        const position = thread.position;

        // Find the REQ card's line-numbered view
        const reqCard = document.getElementById(`req-card-${reqId}`);
        if (!reqCard) return;

        const lineContainer = reqCard.querySelector('.rs-lines-table');
        if (!lineContainer) return;

        // Clear any existing highlights
        clearCommentHighlights(lineContainer);

        // Determine highlight class based on confidence
        const highlightClass = getHighlightClassForThread(thread);

        // Highlight based on position type
        let linesToHighlight = [];

        if (position.type === RS.PositionType.LINE && position.lineNumber) {
            linesToHighlight = [position.lineNumber];
        } else if (position.type === RS.PositionType.BLOCK && position.lineRange) {
            const [start, end] = position.lineRange;
            for (let i = start; i <= end; i++) {
                linesToHighlight.push(i);
            }
        } else if (position.type === RS.PositionType.WORD && position.keyword) {
            // For word positions, try to find the line containing the keyword
            const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
            if (reqData && reqData.body) {
                const foundLine = RS.findKeywordOccurrence(
                    reqData.body,
                    position.keyword,
                    position.keywordOccurrence || 1
                );
                if (foundLine) {
                    linesToHighlight = [foundLine.line];
                }
            }
        }
        // For 'general' position, highlight whole REQ card with unanchored style
        if (position.type === RS.PositionType.GENERAL) {
            reqCard.classList.add('rs-highlight-unanchored');
            return;
        }

        // Apply highlights and scroll to first highlighted line
        if (linesToHighlight.length > 0) {
            let firstRow = null;
            linesToHighlight.forEach(lineNum => {
                const lineRow = lineContainer.querySelector(`.rs-line-row[data-line="${lineNum}"]`);
                if (lineRow) {
                    // Add confidence-specific highlight class
                    lineRow.classList.add(highlightClass);
                    lineRow.classList.add('rs-comment-highlight');
                    lineRow.setAttribute('data-highlight-thread', threadId);
                    if (!firstRow) firstRow = lineRow;
                }
            });

            // Scroll the first highlighted line into view
            if (firstRow) {
                firstRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }
    }
    RS.highlightThreadPositionInCard = highlightThreadPositionInCard;

    /**
     * Clear all position highlights from the REQ card
     * @param {Element} container - Container element
     */
    function clearAllPositionHighlights(container) {
        // Get the reqId
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id') ||
                      (typeof currentReviewReqId !== 'undefined' ? currentReviewReqId : null);

        if (!reqId) return;

        // Find the REQ card
        const reqCard = document.getElementById(`req-card-${reqId}`);
        if (!reqCard) return;

        // Remove unanchored highlight from whole card
        reqCard.classList.remove('rs-highlight-unanchored');

        const lineContainer = reqCard.querySelector('.rs-lines-table');
        if (lineContainer) {
            clearCommentHighlights(lineContainer);
        }
    }
    RS.clearAllPositionHighlights = clearAllPositionHighlights;

    /**
     * Clear comment highlights from line container
     * Removes all highlight classes: comment-highlight and confidence-based classes
     * @param {Element} lineContainer - The lines table element
     */
    function clearCommentHighlights(lineContainer) {
        if (!lineContainer) return;
        // Clear all highlight classes
        const allHighlightClasses = [
            'rs-comment-highlight',
            'rs-highlight-exact',
            'rs-highlight-approximate',
            'rs-highlight-unanchored',
            'rs-highlight-active'
        ];
        lineContainer.querySelectorAll('[class*="rs-highlight"], .rs-comment-highlight').forEach(el => {
            allHighlightClasses.forEach(cls => el.classList.remove(cls));
            el.removeAttribute('data-highlight-thread');
        });
    }
    RS.clearCommentHighlights = clearCommentHighlights;

    /**
     * Submit reply to a thread
     * @param {Element} threadEl - Thread element
     * @param {Element} container - Container element
     */
    function submitReply(threadEl, container) {
        const threadId = threadEl.getAttribute('data-thread-id');
        const replyInput = threadEl.querySelector('.rs-reply-input');
        const body = replyInput.value.trim();

        if (!body) {
            alert('Please enter a reply');
            return;
        }

        const user = RS.state.currentUser || 'anonymous';
        // Look for data-req-id in the container or its children (thread-list element)
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id');

        // Find thread in state
        if (reqId) {
            const threads = RS.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.addComment(user, body);

                // Trigger change event
                document.dispatchEvent(new CustomEvent('rs:comment-added', {
                    detail: { thread, reqId, body }
                }));

                // Re-render - find the proper container
                const threadListEl = container.querySelector('.rs-thread-list') || container;
                const renderTarget = threadListEl.parentElement || container;
                renderThreadList(renderTarget, reqId);
            }
        }
    }

    /**
     * Resolve a thread
     * @param {string} threadId - Thread ID
     * @param {Element} container - Container element
     */
    function resolveThread(threadId, container) {
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id');
        const user = RS.state.currentUser || 'anonymous';

        if (reqId) {
            const threads = RS.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.resolve(user);

                // Trigger event
                document.dispatchEvent(new CustomEvent('rs:thread-resolved', {
                    detail: { thread, reqId, user }
                }));

                // Re-render - find the proper container
                const threadListEl = container.querySelector('.rs-thread-list') || container;
                const renderTarget = threadListEl.parentElement || container;
                renderThreadList(renderTarget, reqId);
            }
        }
    }

    /**
     * Unresolve a thread
     * @param {string} threadId - Thread ID
     * @param {Element} container - Container element
     */
    function unresolveThread(threadId, container) {
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id');

        if (reqId) {
            const threads = RS.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.unresolve();

                // Trigger event
                document.dispatchEvent(new CustomEvent('rs:thread-unresolved', {
                    detail: { thread, reqId }
                }));

                // Re-render - find the proper container
                const threadListEl = container.querySelector('.rs-thread-list') || container;
                const renderTarget = threadListEl.parentElement || container;
                renderThreadList(renderTarget, reqId);
            }
        }
    }

    /**
     * Get comment count for a requirement
     * @param {string} reqId - Requirement ID
     * @returns {Object} {total, unresolved}
     */
    function getCommentCount(reqId) {
        const threads = RS.state.getThreads(reqId);
        return {
            total: threads.length,
            unresolved: threads.filter(t => !t.resolved).length
        };
    }
    RS.getCommentCount = getCommentCount;

})(window.ReviewSystem);
