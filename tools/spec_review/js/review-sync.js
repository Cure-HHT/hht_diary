/**
 * Spec Review Sync & Fetch Module
 *
 * Handles synchronization of review data:
 * - Fetch review data from server/CLI
 * - Push changes to server
 * - Conflict handling UI
 * - Refresh button logic
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00086: Spec Review Data Model
 */

// Ensure ReviewSystem namespace exists
window.ReviewSystem = window.ReviewSystem || {};

(function(RS) {
    'use strict';

    // ==========================================================================
    // Configuration
    // ==========================================================================

    RS.syncConfig = {
        apiEndpoint: '/api/reviews',  // Base endpoint for review API
        autoFetchInterval: 60000,     // Auto-fetch every 60 seconds
        retryAttempts: 3,
        retryDelay: 1000
    };

    // Sync state
    let isSyncing = false;
    let lastSyncTime = null;
    let autoFetchTimer = null;

    // ==========================================================================
    // Fetch Operations
    // ==========================================================================

    /**
     * Fetch all review data from server
     * @param {Object} options - Fetch options
     * @returns {Promise<Object>} Review data
     */
    async function fetchReviewData(options = {}) {
        if (isSyncing) {
            console.warn('Sync already in progress');
            return null;
        }

        isSyncing = true;
        showSyncIndicator('Fetching...');

        try {
            const users = options.users || [];
            const queryParams = new URLSearchParams();
            if (users.length > 0) {
                queryParams.set('users', users.join(','));
            }

            const url = `${RS.syncConfig.apiEndpoint}?${queryParams}`;
            const response = await fetchWithRetry(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`Fetch failed: ${response.status}`);
            }

            const data = await response.json();

            // Load data into state
            RS.state.loadFromEmbedded(data);
            lastSyncTime = new Date();

            // Trigger refresh event
            document.dispatchEvent(new CustomEvent('rs:data-fetched', {
                detail: { data, timestamp: lastSyncTime }
            }));

            showSyncIndicator('Synced', 'success');
            return data;

        } catch (error) {
            console.error('Fetch error:', error);
            showSyncIndicator('Sync failed', 'error');
            throw error;
        } finally {
            isSyncing = false;
        }
    }
    RS.fetchReviewData = fetchReviewData;

    /**
     * Fetch review data for a specific requirement
     * @param {string} reqId - Requirement ID
     * @returns {Promise<Object>} Review data for requirement
     */
    async function fetchReqReviewData(reqId) {
        showSyncIndicator('Fetching...');

        try {
            const url = `${RS.syncConfig.apiEndpoint}/reqs/${RS.normalizeReqId(reqId)}`;
            const response = await fetchWithRetry(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });

            if (!response.ok) {
                if (response.status === 404) {
                    return { threads: [], requests: [], flag: null };
                }
                throw new Error(`Fetch failed: ${response.status}`);
            }

            const data = await response.json();
            showSyncIndicator('Synced', 'success');
            return data;

        } catch (error) {
            console.error('Fetch error:', error);
            showSyncIndicator('Sync failed', 'error');
            throw error;
        }
    }
    RS.fetchReqReviewData = fetchReqReviewData;

    // ==========================================================================
    // Push Operations
    // ==========================================================================

    /**
     * Push a new thread to server
     * @param {Thread} thread - Thread to push
     * @returns {Promise<Object>} Response data
     */
    async function pushThread(thread) {
        if (!RS.state.config.pushOnComment) {
            console.log('Push on comment disabled');
            return null;
        }

        showSyncIndicator('Saving...');

        try {
            const url = `${RS.syncConfig.apiEndpoint}/reqs/${RS.normalizeReqId(thread.reqId)}/threads`;
            const response = await fetchWithRetry(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(thread.toDict())
            });

            if (!response.ok) {
                throw new Error(`Push failed: ${response.status}`);
            }

            const data = await response.json();
            showSyncIndicator('Saved', 'success');
            return data;

        } catch (error) {
            console.error('Push error:', error);
            showSyncIndicator('Save failed', 'error');
            throw error;
        }
    }
    RS.pushThread = pushThread;

    /**
     * Push a comment to an existing thread
     * @param {string} reqId - Requirement ID
     * @param {string} threadId - Thread ID
     * @param {Comment} comment - Comment to push
     * @returns {Promise<Object>} Response data
     */
    async function pushComment(reqId, threadId, comment) {
        if (!RS.state.config.pushOnComment) {
            return null;
        }

        showSyncIndicator('Saving...');

        try {
            const url = `${RS.syncConfig.apiEndpoint}/reqs/${RS.normalizeReqId(reqId)}/threads/${threadId}/comments`;
            const response = await fetchWithRetry(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(comment.toDict())
            });

            if (!response.ok) {
                throw new Error(`Push failed: ${response.status}`);
            }

            const data = await response.json();
            showSyncIndicator('Saved', 'success');
            return data;

        } catch (error) {
            console.error('Push error:', error);
            showSyncIndicator('Save failed', 'error');
            throw error;
        }
    }
    RS.pushComment = pushComment;

    /**
     * Push status request to server
     * @param {StatusRequest} request - Request to push
     * @returns {Promise<Object>} Response data
     */
    async function pushStatusRequest(request) {
        showSyncIndicator('Saving...');

        try {
            const url = `${RS.syncConfig.apiEndpoint}/reqs/${RS.normalizeReqId(request.reqId)}/requests`;
            const response = await fetchWithRetry(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(request.toDict())
            });

            if (!response.ok) {
                throw new Error(`Push failed: ${response.status}`);
            }

            const data = await response.json();
            showSyncIndicator('Saved', 'success');
            return data;

        } catch (error) {
            console.error('Push error:', error);
            showSyncIndicator('Save failed', 'error');
            throw error;
        }
    }
    RS.pushStatusRequest = pushStatusRequest;

    /**
     * Push approval to server
     * @param {string} reqId - Requirement ID
     * @param {string} requestId - Request ID
     * @param {Approval} approval - Approval to push
     * @returns {Promise<Object>} Response data
     */
    async function pushApproval(reqId, requestId, approval) {
        showSyncIndicator('Saving...');

        try {
            const url = `${RS.syncConfig.apiEndpoint}/reqs/${RS.normalizeReqId(reqId)}/requests/${requestId}/approvals`;
            const response = await fetchWithRetry(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(approval.toDict())
            });

            if (!response.ok) {
                throw new Error(`Push failed: ${response.status}`);
            }

            const data = await response.json();
            showSyncIndicator('Saved', 'success');
            return data;

        } catch (error) {
            console.error('Push error:', error);
            showSyncIndicator('Save failed', 'error');
            throw error;
        }
    }
    RS.pushApproval = pushApproval;

    // ==========================================================================
    // Helper Functions
    // ==========================================================================

    /**
     * Fetch with retry logic
     * @param {string} url - URL to fetch
     * @param {Object} options - Fetch options
     * @returns {Promise<Response>} Response
     */
    async function fetchWithRetry(url, options) {
        let lastError;

        for (let i = 0; i < RS.syncConfig.retryAttempts; i++) {
            try {
                return await fetch(url, options);
            } catch (error) {
                lastError = error;
                if (i < RS.syncConfig.retryAttempts - 1) {
                    await new Promise(r => setTimeout(r, RS.syncConfig.retryDelay));
                }
            }
        }

        throw lastError;
    }

    /**
     * Show sync status indicator
     * @param {string} message - Status message
     * @param {string} type - Status type ('', 'success', 'error')
     */
    function showSyncIndicator(message, type = '') {
        let indicator = document.querySelector('.rs-sync-indicator');

        if (!indicator) {
            indicator = document.createElement('div');
            indicator.className = 'rs-sync-indicator';
            document.body.appendChild(indicator);
        }

        indicator.textContent = message;
        indicator.className = `rs-sync-indicator rs-sync-${type}`;
        indicator.style.display = 'block';

        // Auto-hide after success/error
        if (type) {
            setTimeout(() => {
                indicator.style.display = 'none';
            }, 3000);
        }
    }

    /**
     * Hide sync indicator
     */
    function hideSyncIndicator() {
        const indicator = document.querySelector('.rs-sync-indicator');
        if (indicator) {
            indicator.style.display = 'none';
        }
    }

    // ==========================================================================
    // Auto-Sync
    // ==========================================================================

    /**
     * Start auto-fetch timer
     */
    function startAutoFetch() {
        if (autoFetchTimer) {
            clearInterval(autoFetchTimer);
        }

        if (RS.state.config.autoFetchOnOpen) {
            autoFetchTimer = setInterval(() => {
                fetchReviewData().catch(console.error);
            }, RS.syncConfig.autoFetchInterval);
        }
    }
    RS.startAutoFetch = startAutoFetch;

    /**
     * Stop auto-fetch timer
     */
    function stopAutoFetch() {
        if (autoFetchTimer) {
            clearInterval(autoFetchTimer);
            autoFetchTimer = null;
        }
    }
    RS.stopAutoFetch = stopAutoFetch;

    /**
     * Get last sync time
     * @returns {Date|null} Last sync timestamp
     */
    function getLastSyncTime() {
        return lastSyncTime;
    }
    RS.getLastSyncTime = getLastSyncTime;

    /**
     * Check if currently syncing
     * @returns {boolean} True if sync in progress
     */
    function isSyncInProgress() {
        return isSyncing;
    }
    RS.isSyncInProgress = isSyncInProgress;

    // ==========================================================================
    // Conflict Handling
    // ==========================================================================

    /**
     * Show conflict resolution dialog
     * @param {Object} localData - Local version
     * @param {Object} remoteData - Remote version
     * @returns {Promise<string>} Resolution choice ('local', 'remote', 'merge')
     */
    async function showConflictDialog(localData, remoteData) {
        return new Promise((resolve) => {
            const overlay = document.createElement('div');
            overlay.className = 'rs-conflict-overlay';
            overlay.innerHTML = `
                <div class="rs-conflict-dialog">
                    <h3>Sync Conflict Detected</h3>
                    <p>Your local changes conflict with remote changes.</p>
                    <div class="rs-conflict-options">
                        <button class="rs-btn rs-btn-local">Keep Local</button>
                        <button class="rs-btn rs-btn-remote">Use Remote</button>
                        <button class="rs-btn rs-btn-merge">Merge Both</button>
                    </div>
                </div>
            `;

            overlay.querySelector('.rs-btn-local').addEventListener('click', () => {
                document.body.removeChild(overlay);
                resolve('local');
            });

            overlay.querySelector('.rs-btn-remote').addEventListener('click', () => {
                document.body.removeChild(overlay);
                resolve('remote');
            });

            overlay.querySelector('.rs-btn-merge').addEventListener('click', () => {
                document.body.removeChild(overlay);
                resolve('merge');
            });

            document.body.appendChild(overlay);
        });
    }
    RS.showConflictDialog = showConflictDialog;

    // ==========================================================================
    // UI Components
    // ==========================================================================

    /**
     * Create refresh button HTML
     * @returns {string} HTML
     */
    function createRefreshButton() {
        return `
            <button class="rs-btn rs-refresh-btn" title="Refresh review data">
                🔄 Refresh
            </button>
        `;
    }
    RS.createRefreshButton = createRefreshButton;

    /**
     * Create sync status display HTML
     * @returns {string} HTML
     */
    function createSyncStatus() {
        const time = lastSyncTime ? formatTime(lastSyncTime) : 'Never';
        return `
            <span class="rs-sync-status">
                Last sync: ${time}
            </span>
        `;
    }
    RS.createSyncStatus = createSyncStatus;

    function formatTime(date) {
        if (!date) return 'Never';
        const now = new Date();
        const diff = now - date;

        if (diff < 60000) return 'just now';
        if (diff < 3600000) return Math.floor(diff / 60000) + 'm ago';
        return date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
    }

    // ==========================================================================
    // Event Listeners for Auto-Push
    // ==========================================================================

    // Listen for thread creation
    document.addEventListener('rs:thread-created', async (e) => {
        const { thread } = e.detail;
        try {
            await pushThread(thread);
        } catch (error) {
            console.error('Failed to push thread:', error);
        }
    });

    // Listen for comment additions
    document.addEventListener('rs:comment-added', async (e) => {
        const { thread, reqId, body } = e.detail;
        const comment = thread.comments[thread.comments.length - 1];
        try {
            await pushComment(reqId, thread.threadId, comment);
        } catch (error) {
            console.error('Failed to push comment:', error);
        }
    });

    // Listen for status request creation
    document.addEventListener('rs:request-created', async (e) => {
        const { request } = e.detail;
        try {
            await pushStatusRequest(request);
        } catch (error) {
            console.error('Failed to push request:', error);
        }
    });

    // Listen for approval additions
    document.addEventListener('rs:approval-added', async (e) => {
        const { request, reqId, user, decision } = e.detail;
        const approval = request.approvals[request.approvals.length - 1];
        try {
            await pushApproval(reqId, request.requestId, approval);
        } catch (error) {
            console.error('Failed to push approval:', error);
        }
    });

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /**
     * Initialize sync module
     * @param {Object} embeddedData - Embedded review data from page
     */
    function initSync(embeddedData) {
        // Load embedded data
        if (embeddedData) {
            RS.state.loadFromEmbedded(embeddedData);
            lastSyncTime = new Date();
        }

        // Start auto-fetch if enabled
        if (RS.state.config.autoFetchOnOpen) {
            startAutoFetch();
        }

        console.log('Review sync initialized');
    }
    RS.initSync = initSync;

})(window.ReviewSystem);
