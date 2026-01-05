/**
 * Spec Review System Initialization Module
 *
 * Main entry point for the review system. Provides:
 * - toggleReviewMode: Enable/disable review mode
 * - selectReqForReview: Select a requirement for reviewing
 * - Integration with line-numbered markdown view
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00092: HTML Report Integration (Phase 5.2: Line-numbered markdown)
 */

// Ensure ReviewSystem namespace exists
window.ReviewSystem = window.ReviewSystem || {};

(function(RS) {
    'use strict';

    // ==========================================================================
    // State
    // ==========================================================================

    let reviewModeActive = false;
    window.currentReviewReqId = null;

    // ==========================================================================
    // Review Mode Toggle
    // ==========================================================================

    /**
     * Toggle review mode on/off
     */
    function toggleReviewMode() {
        reviewModeActive = !reviewModeActive;

        // Update body class
        document.body.classList.toggle('review-mode-active', reviewModeActive);

        // Update button state
        const btn = document.getElementById('btnReviewMode');
        if (btn) {
            btn.classList.toggle('active', reviewModeActive);
        }

        // Show/hide review column
        const reviewColumn = document.getElementById('review-column');
        if (reviewColumn) {
            reviewColumn.classList.toggle('hidden', !reviewModeActive);
        }

        // Dispatch event for other modules
        document.dispatchEvent(new CustomEvent('rs:review-mode-changed', {
            detail: { active: reviewModeActive }
        }));

        // If activating, initialize packages panel
        if (reviewModeActive && RS.initPackagesPanel) {
            RS.initPackagesPanel();
        }

        // If deactivating, clear selections
        if (!reviewModeActive) {
            clearCurrentSelection();
        }

        console.log('[ReviewSystem] Review mode:', reviewModeActive ? 'ON' : 'OFF');
    }
    RS.toggleReviewMode = toggleReviewMode;

    /**
     * Check if review mode is active
     * @returns {boolean}
     */
    function isReviewModeActive() {
        return reviewModeActive;
    }
    RS.isReviewModeActive = isReviewModeActive;

    // ==========================================================================
    // REQ Selection for Review
    // ==========================================================================

    /**
     * Select a requirement for reviewing
     * Opens the REQ card and populates the review panel
     *
     * @param {string} reqId - Requirement ID to select
     */
    function selectReqForReview(reqId) {
        const reqData = window.REQ_CONTENT_DATA;
        if (!reqData || !reqData[reqId]) {
            console.error('Requirement data not found:', reqId);
            return;
        }

        // Store current selection
        window.currentReviewReqId = reqId;
        const req = reqData[reqId];

        // Open the REQ card in the side panel (uses TraceView if available)
        if (window.TraceView && window.TraceView.panel) {
            window.TraceView.panel.open(reqId);
        } else if (typeof openReqPanel === 'function') {
            openReqPanel(reqId);
        }

        // Apply line numbers to the REQ card content
        applyLineNumbersToReqCard(reqId, req);

        // Update the review panel with this REQ's data
        updateReviewPanel(reqId, req);

        // Clear any previous line selections
        if (RS.clearAllLineSelections) {
            RS.clearAllLineSelections();
        }

        console.log('[ReviewSystem] Selected REQ for review:', reqId);
    }
    RS.selectReqForReview = selectReqForReview;

    /**
     * Apply line numbers to a REQ card's content
     *
     * @param {string} reqId - Requirement ID
     * @param {Object} req - Requirement data object
     */
    function applyLineNumbersToReqCard(reqId, req) {
        // Wait for card to be rendered
        setTimeout(() => {
            const card = document.getElementById(`req-card-${reqId}`);
            if (!card) return;

            const contentEl = card.querySelector('.req-card-content');
            if (!contentEl) return;

            // Only apply if not already applied
            if (contentEl.classList.contains('rs-with-line-numbers')) {
                return;
            }

            // Use the line numbers module to convert content
            if (RS.applyLineNumbersToCard && req.body) {
                RS.applyLineNumbersToCard(reqId, contentEl, req.body);
            }
        }, 50);
    }

    /**
     * Update the review panel with requirement data
     *
     * @param {string} reqId - Requirement ID
     * @param {Object} req - Requirement data object
     */
    function updateReviewPanel(reqId, req) {
        // Hide the "no selection" message
        const noSelection = document.getElementById('review-panel-no-selection');
        if (noSelection) {
            noSelection.style.display = 'none';
        }

        // Show the combined view
        const combinedView = document.getElementById('review-panel-combined');
        if (combinedView) {
            combinedView.style.display = 'flex';
        }

        // Update header with REQ info
        updateReviewPanelHeader(reqId, req);

        // Render status section
        const statusContent = document.getElementById('rs-status-content');
        if (statusContent && RS.renderStatusPanel) {
            RS.renderStatusPanel(statusContent, reqId, req.status);
        }

        // Render comments section
        const commentsContent = document.getElementById('rs-comments-content');
        if (commentsContent && RS.renderThreadList) {
            // Add data-req-id for thread list
            commentsContent.setAttribute('data-req-id', reqId);
            RS.renderThreadList(commentsContent, reqId);
        }

        // Bind add comment button
        const addCommentBtn = document.getElementById('rs-add-comment-btn');
        if (addCommentBtn) {
            addCommentBtn.onclick = () => {
                if (RS.showNewCommentForm) {
                    RS.showNewCommentForm(commentsContent, reqId);
                }
            };
        }
    }

    /**
     * Update the review panel header with REQ info
     *
     * @param {string} reqId - Requirement ID
     * @param {Object} req - Requirement data object
     */
    function updateReviewPanelHeader(reqId, req) {
        // Look for or create the header
        let header = document.querySelector('.review-panel-req-header');
        if (!header) {
            const panelHeader = document.querySelector('.review-panel-header');
            if (panelHeader) {
                header = document.createElement('div');
                header.className = 'review-panel-req-header';
                panelHeader.insertAdjacentElement('afterend', header);
            }
        }

        if (header) {
            header.innerHTML = `
                <span class="req-id-badge">REQ-${reqId}</span>
                <span class="req-title-text">${escapeHtml(req.title)}</span>
            `;
        }
    }

    /**
     * Clear current selection
     */
    function clearCurrentSelection() {
        window.currentReviewReqId = null;

        // Show the "no selection" message
        const noSelection = document.getElementById('review-panel-no-selection');
        if (noSelection) {
            noSelection.style.display = 'block';
        }

        // Hide the combined view
        const combinedView = document.getElementById('review-panel-combined');
        if (combinedView) {
            combinedView.style.display = 'none';
        }

        // Clear header
        const header = document.querySelector('.review-panel-req-header');
        if (header) {
            header.innerHTML = '';
        }
    }
    RS.clearCurrentSelection = clearCurrentSelection;

    // ==========================================================================
    // Event Handlers
    // ==========================================================================

    /**
     * Handle clicks on requirement rows in the tree
     * In review mode, select the REQ for review
     */
    function handleReqRowClick(event) {
        if (!reviewModeActive) return;

        // Find the REQ row
        const reqRow = event.target.closest('[data-req-id]');
        if (!reqRow) return;

        const reqId = reqRow.dataset.reqId;
        if (!reqId) return;

        // Prevent default link behavior if clicking a link
        if (event.target.tagName === 'A') {
            event.preventDefault();
        }

        selectReqForReview(reqId);
    }

    /**
     * Handle clicks on REQ cards
     * Update the review panel when a card is clicked
     */
    function handleReqCardClick(event) {
        if (!reviewModeActive) return;

        // Find the REQ card
        const reqCard = event.target.closest('.req-card');
        if (!reqCard) return;

        // Extract reqId from card id
        const reqId = reqCard.id.replace('req-card-', '');
        if (!reqId || reqId === window.currentReviewReqId) return;

        // Don't capture clicks on buttons or inputs
        if (event.target.closest('button, input, textarea, select')) {
            return;
        }

        selectReqForReview(reqId);
    }

    // ==========================================================================
    // Utilities
    // ==========================================================================

    /**
     * Escape HTML special characters
     */
    function escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /**
     * Initialize the review system
     */
    function init() {
        // Load embedded review data
        if (window.REVIEW_DATA) {
            if (RS.initSync) {
                RS.initSync(window.REVIEW_DATA);
            } else if (RS.state && RS.state.loadFromEmbedded) {
                RS.state.loadFromEmbedded(window.REVIEW_DATA);
            }
        }

        // Set up click handlers for REQ selection
        const reqTree = document.getElementById('reqTree');
        if (reqTree) {
            reqTree.addEventListener('click', handleReqRowClick);
        }

        // Set up click handler on REQ card stack
        const cardStack = document.getElementById('req-card-stack');
        if (cardStack) {
            cardStack.addEventListener('click', handleReqCardClick);
        }

        // Check if we should auto-activate review mode
        if (document.body.dataset.reviewMode === 'true') {
            // Page was generated with review mode, may want to auto-activate
            // For now, require manual activation via button
        }

        console.log('[ReviewSystem] Review system initialized');
    }
    RS.init = init;

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})(window.ReviewSystem);
