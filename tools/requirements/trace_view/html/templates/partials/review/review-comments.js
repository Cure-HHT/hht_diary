/**
 * TraceView Review Comment UI Module
 *
 * User interface for comment threads:
 * - Thread rendering (collapsible)
 * - Comment form (new thread, reply)
 * - Resolve/unresolve actions
 * - Position selection UI
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
                              title="Click to highlight in REQ">
                            ${getPositionIcon(thread)} ${getPositionLabel(thread)}
                        </span>
                        ${resolvedBadge}
                    </div>
                    <div class="rs-thread-actions">
                        ${thread.resolved ?
                            `<button class="rs-btn rs-btn-sm rs-unresolve-btn">Reopen</button>` :
                            `<button class="rs-btn rs-btn-sm rs-resolve-btn">Resolve</button>`
                        }
                        <button class="rs-btn rs-btn-sm rs-collapse-btn" title="Collapse">V</button>
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

    function getConfidenceClass(thread) {
        // This would be set based on resolved position confidence
        // For now, return empty
        return '';
    }

    function getPositionIcon(thread) {
        switch (thread.position.type) {
            case review.PositionType.LINE: return '[L]';
            case review.PositionType.BLOCK: return '[B]';
            case review.PositionType.WORD: return '[W]';
            default: return '[G]';
        }
    }

    function getPositionTooltip(thread) {
        const pos = thread.position;
        switch (pos.type) {
            case review.PositionType.LINE:
                return `Line ${pos.lineNumber}`;
            case review.PositionType.BLOCK:
                return `Lines ${pos.lineRange[0]}-${pos.lineRange[1]}`;
            case review.PositionType.WORD:
                return `"${pos.keyword}" (occurrence ${pos.keywordOccurrence || 1})`;
            default:
                return 'General comment';
        }
    }

    function getPositionLabel(thread) {
        const pos = thread.position;
        switch (pos.type) {
            case review.PositionType.LINE:
                return `Line ${pos.lineNumber}`;
            case review.PositionType.BLOCK:
                return `Lines ${pos.lineRange[0]}-${pos.lineRange[1]}`;
            case review.PositionType.WORD:
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

        const threads = review.state.getThreads(reqId);
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
    review.renderThreadList = renderThreadList;

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
    review.showNewCommentForm = showNewCommentForm;

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

        const user = review.state.currentUser || 'anonymous';
        const posType = form.querySelector('.rs-position-type').value;

        // Get current REQ hash (would come from embedded data)
        const hash = window.REQ_CONTENT_DATA?.[reqId]?.hash || '00000000';

        // Create position based on type
        let position;
        switch (posType) {
            case 'line': {
                const lineNum = parseInt(form.querySelector('.rs-line-input').value, 10);
                position = review.CommentPosition.createLine(hash, lineNum);
                break;
            }
            case 'block': {
                const start = parseInt(form.querySelector('.rs-block-start').value, 10);
                const end = parseInt(form.querySelector('.rs-block-end').value, 10);
                position = review.CommentPosition.createBlock(hash, start, end);
                break;
            }
            case 'word': {
                const keyword = form.querySelector('.rs-keyword').value.trim();
                const occurrence = parseInt(form.querySelector('.rs-keyword-occurrence').value, 10);
                if (!keyword) {
                    alert('Please enter a word or phrase');
                    return;
                }
                position = review.CommentPosition.createWord(hash, keyword, occurrence);
                break;
            }
            default:
                position = review.CommentPosition.createGeneral(hash);
        }

        // Create thread
        const thread = review.Thread.create(reqId, user, position, body);
        review.state.addThread(thread);

        // Auto-change status to Review if currently Draft
        const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
        if (reqData && reqData.status === 'Draft' && typeof review.toggleToReview === 'function') {
            review.toggleToReview(reqId).then(result => {
                if (result.success) {
                    console.log(`Auto-changed REQ-${reqId} status to Review`);
                }
            }).catch(err => {
                console.warn('Failed to auto-change status:', err);
            });
        }

        // Trigger change event
        document.dispatchEvent(new CustomEvent('traceview:thread-created', {
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
                btn.textContent = isCollapsed ? 'V' : '>';
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
                review.activateHighlight(threadId);
            });
            threadEl.addEventListener('mouseleave', () => {
                review.activateHighlight(null);
            });

            // Click to highlight position in REQ card
            threadEl.addEventListener('click', (e) => {
                // Don't trigger if clicking on buttons or reply form
                if (e.target.closest('button') || e.target.closest('.rs-reply-form') ||
                    e.target.closest('textarea') || e.target.closest('input')) {
                    return;
                }
                const threadId = threadEl.getAttribute('data-thread-id');
                highlightThreadPositionInCard(threadId, container);
            });
        });
    }

    /**
     * Highlight the position referenced by a thread in the REQ card
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

        const threads = review.state.getThreads(reqId);
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

        // Highlight based on position type
        let linesToHighlight = [];

        if (position.type === review.PositionType.LINE && position.lineNumber) {
            linesToHighlight = [position.lineNumber];
        } else if (position.type === review.PositionType.BLOCK && position.lineRange) {
            const [start, end] = position.lineRange;
            for (let i = start; i <= end; i++) {
                linesToHighlight.push(i);
            }
        } else if (position.type === review.PositionType.WORD && position.keyword) {
            // For word positions, try to find the line containing the keyword
            const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
            if (reqData && reqData.body) {
                const foundLine = review.findKeywordOccurrence(
                    reqData.body,
                    position.keyword,
                    position.keywordOccurrence || 1
                );
                if (foundLine) {
                    linesToHighlight = [foundLine.line];
                }
            }
        }
        // For 'general' position, no specific lines to highlight

        // Apply highlights and scroll to first highlighted line
        if (linesToHighlight.length > 0) {
            let firstRow = null;
            linesToHighlight.forEach(lineNum => {
                const lineRow = lineContainer.querySelector(`.rs-line-row[data-line="${lineNum}"]`);
                if (lineRow) {
                    lineRow.classList.add('rs-comment-highlight');
                    if (!firstRow) firstRow = lineRow;
                }
            });

            // Scroll the first highlighted line into view
            if (firstRow) {
                firstRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }
    }
    review.highlightThreadPositionInCard = highlightThreadPositionInCard;

    /**
     * Clear comment highlights from line container
     * @param {Element} lineContainer - The lines table element
     */
    function clearCommentHighlights(lineContainer) {
        if (!lineContainer) return;
        lineContainer.querySelectorAll('.rs-comment-highlight').forEach(el => {
            el.classList.remove('rs-comment-highlight');
        });
    }
    review.clearCommentHighlights = clearCommentHighlights;

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

        const user = review.state.currentUser || 'anonymous';
        // Look for data-req-id in the container or its children (thread-list element)
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.getAttribute('data-req-id');

        // Find thread in state
        if (reqId) {
            const threads = review.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.addComment(user, body);

                // Trigger change event
                document.dispatchEvent(new CustomEvent('traceview:comment-added', {
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
        const user = review.state.currentUser || 'anonymous';

        if (reqId) {
            const threads = review.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.resolve(user);

                // Trigger event
                document.dispatchEvent(new CustomEvent('traceview:thread-resolved', {
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
            const threads = review.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.unresolve();

                // Trigger event
                document.dispatchEvent(new CustomEvent('traceview:thread-unresolved', {
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
        const threads = review.state.getThreads(reqId);
        return {
            total: threads.length,
            unresolved: threads.filter(t => !t.resolved).length
        };
    }
    review.getCommentCount = getCommentCount;

    // ==========================================================================
    // Review Panel Integration
    // ==========================================================================

    /**
     * Handle review panel ready event - add comments section
     * @param {CustomEvent} event - Event with reqId and sectionsContainer
     */
    function handleReviewPanelReady(event) {
        const { reqId, sectionsContainer } = event.detail;
        if (!sectionsContainer) return;

        // Create comments section
        const commentsSection = document.createElement('div');
        commentsSection.className = 'rs-comments-section';
        commentsSection.setAttribute('data-req-id', reqId);
        sectionsContainer.appendChild(commentsSection);

        // Render thread list
        renderThreadList(commentsSection, reqId);
    }

    // Register event listener
    document.addEventListener('traceview:review-panel-ready', handleReviewPanelReady);

})(TraceView.review);
