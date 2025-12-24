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
                        <span class="rs-author">${escapeHtml(thread.createdBy)}</span>
                        <span class="rs-time">${formatTime(thread.createdAt)}</span>
                        ${resolvedBadge}
                        <span class="rs-position-indicator ${confidenceClass}"
                              title="${getPositionTooltip(thread)}">
                            ${getPositionIcon(thread)}
                        </span>
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
                        <input type="number" class="rs-line-number" min="1" value="1">
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
                const lineNum = parseInt(form.querySelector('.rs-line-number').value, 10);
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

        // Trigger change event
        document.dispatchEvent(new CustomEvent('rs:thread-created', {
            detail: { thread, reqId }
        }));

        // Re-render
        const container = form.closest('.rs-thread-list');
        if (container) {
            renderThreadList(container.parentElement, reqId);
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
    }

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
        const reqId = container.closest('[data-req-id]')?.getAttribute('data-req-id');

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

                // Re-render
                renderThreadList(container.parentElement, reqId);
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
                      container.closest('[data-req-id]')?.getAttribute('data-req-id');
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

                // Re-render
                renderThreadList(container.parentElement || container, reqId);
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
                      container.closest('[data-req-id]')?.getAttribute('data-req-id');

        if (reqId) {
            const threads = RS.state.getThreads(reqId);
            const thread = threads.find(t => t.threadId === threadId);
            if (thread) {
                thread.unresolve();

                // Trigger event
                document.dispatchEvent(new CustomEvent('rs:thread-unresolved', {
                    detail: { thread, reqId }
                }));

                // Re-render
                renderThreadList(container.parentElement || container, reqId);
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
