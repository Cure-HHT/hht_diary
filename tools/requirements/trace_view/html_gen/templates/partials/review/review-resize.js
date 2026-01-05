/**
 * Review Column Resize Module
 *
 * Handles resizing of the review column (third column in 3-column layout):
 * - Mouse drag resize functionality
 * - Min/max width constraints
 * - Coordinated resize with REQ panel
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00092: HTML Report Integration (3-column layout resize)
 */

// Ensure ReviewSystem namespace exists
window.ReviewSystem = window.ReviewSystem || {};

(function(RS) {
    'use strict';

    // ==========================================================================
    // Configuration
    // ==========================================================================

    const RESIZE_CONFIG = {
        minReviewWidth: 200,       // Minimum review column width
        maxReviewRatio: 0.5,       // Max 50% of viewport
        minReqPanelWidth: 200      // Minimum REQ panel width
    };

    // ==========================================================================
    // Resize State
    // ==========================================================================

    let isResizing = false;
    let startX = 0;
    let startReviewWidth = 0;
    let startReqWidth = 0;

    // ==========================================================================
    // Resize Initialization
    // ==========================================================================

    /**
     * Initialize review column resize functionality
     * Called when review mode is activated
     */
    function initReviewResize() {
        const reviewPanel = document.getElementById('review-column');
        const reqPanel = document.getElementById('req-panel');
        const handle = document.getElementById('reviewResizeHandle');

        if (!reviewPanel || !reqPanel || !handle) {
            return;
        }

        // Mousedown: Start resize
        handle.addEventListener('mousedown', function(e) {
            isResizing = true;
            startX = e.clientX;
            startReviewWidth = reviewPanel.offsetWidth;
            startReqWidth = reqPanel.offsetWidth;

            // Visual feedback
            handle.classList.add('dragging');
            document.body.style.cursor = 'col-resize';
            document.body.style.userSelect = 'none';

            e.preventDefault();
        });

        // Mousemove: Resize in progress
        document.addEventListener('mousemove', function(e) {
            if (!isResizing) return;

            // Calculate the difference (left edge drag means inverse direction)
            const diff = startX - e.clientX;

            // Calculate new widths
            const combinedWidth = startReviewWidth + startReqWidth;
            let newReviewWidth = startReviewWidth + diff;

            // Apply constraints
            newReviewWidth = Math.max(newReviewWidth, RESIZE_CONFIG.minReviewWidth);
            newReviewWidth = Math.min(newReviewWidth, combinedWidth - RESIZE_CONFIG.minReqPanelWidth);
            newReviewWidth = Math.min(newReviewWidth, window.innerWidth * RESIZE_CONFIG.maxReviewRatio);

            // Calculate corresponding REQ panel width
            const newReqWidth = combinedWidth - newReviewWidth;

            // Only apply if both panels stay within constraints
            if (newReqWidth >= RESIZE_CONFIG.minReqPanelWidth) {
                reviewPanel.style.width = newReviewWidth + 'px';
                reqPanel.style.width = newReqWidth + 'px';
            }
        });

        // Mouseup: End resize
        document.addEventListener('mouseup', function() {
            if (isResizing) {
                isResizing = false;
                const handle = document.getElementById('reviewResizeHandle');
                if (handle) {
                    handle.classList.remove('dragging');
                }
                document.body.style.cursor = '';
                document.body.style.userSelect = '';

                // Dispatch resize complete event
                document.dispatchEvent(new CustomEvent('rs:resize-complete', {
                    detail: {
                        reviewWidth: document.getElementById('review-column')?.offsetWidth,
                        reqPanelWidth: document.getElementById('req-panel')?.offsetWidth
                    }
                }));
            }
        });

        console.log('[ReviewResize] Review column resize initialized');
    }

    // ==========================================================================
    // Public API
    // ==========================================================================

    /**
     * Reset review column to default width
     */
    function resetReviewWidth() {
        const reviewPanel = document.getElementById('review-column');
        if (reviewPanel) {
            reviewPanel.style.width = '350px';
        }
    }

    /**
     * Get current review column width
     * @returns {number} Width in pixels
     */
    function getReviewWidth() {
        const reviewPanel = document.getElementById('review-column');
        return reviewPanel ? reviewPanel.offsetWidth : 0;
    }

    // ==========================================================================
    // Exports
    // ==========================================================================

    RS.initReviewResize = initReviewResize;
    RS.resetReviewWidth = resetReviewWidth;
    RS.getReviewWidth = getReviewWidth;

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initReviewResize);
    } else {
        // DOM already loaded
        initReviewResize();
    }

})(window.ReviewSystem);
