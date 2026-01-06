/**
 * TraceView Review Sync & Fetch Module
 *
 * Handles synchronization of review data:
 * - Fetch review data from server/CLI
 * - Push changes to server
 * - Conflict handling UI
 * - Refresh button logic
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
    // Configuration
    // ==========================================================================

    review.syncConfig = {
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

            const url = `${review.syncConfig.apiEndpoint}?${queryParams}`;
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
            review.state.loadFromEmbedded(data);
            lastSyncTime = new Date();

            // Trigger refresh event
            document.dispatchEvent(new CustomEvent('traceview:data-fetched', {
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
    review.fetchReviewData = fetchReviewData;

    /**
     * Fetch review data for a specific requirement
     * @param {string} reqId - Requirement ID
     * @returns {Promise<Object>} Review data for requirement
     */
    async function fetchReqReviewData(reqId) {
        showSyncIndicator('Fetching...');

        try {
            const url = `${review.syncConfig.apiEndpoint}/reqs/${review.normalizeReqId(reqId)}`;
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
    review.fetchReqReviewData = fetchReqReviewData;

    // ==========================================================================
    // Push Operations
    // ==========================================================================

    /**
     * Push a new thread to server
     * @param {Thread} thread - Thread to push
     * @returns {Promise<Object>} Response data
     */
    async function pushThread(thread) {
        if (!review.state.config.pushOnComment) {
            console.log('Push on comment disabled');
            return null;
        }

        showSyncIndicator('Saving...');

        try {
            const url = `${review.syncConfig.apiEndpoint}/reqs/${review.normalizeReqId(thread.reqId)}/threads`;
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
    review.pushThread = pushThread;

    /**
     * Push a comment to an existing thread
     * @param {string} reqId - Requirement ID
     * @param {string} threadId - Thread ID
     * @param {Comment} comment - Comment to push
     * @returns {Promise<Object>} Response data
     */
    async function pushComment(reqId, threadId, comment) {
        if (!review.state.config.pushOnComment) {
            return null;
        }

        showSyncIndicator('Saving...');

        try {
            const url = `${review.syncConfig.apiEndpoint}/reqs/${review.normalizeReqId(reqId)}/threads/${threadId}/comments`;
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
    review.pushComment = pushComment;

    /**
     * Push status request to server
     * @param {StatusRequest} request - Request to push
     * @returns {Promise<Object>} Response data
     */
    async function pushStatusRequest(request) {
        showSyncIndicator('Saving...');

        try {
            const url = `${review.syncConfig.apiEndpoint}/reqs/${review.normalizeReqId(request.reqId)}/requests`;
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
    review.pushStatusRequest = pushStatusRequest;

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
            const url = `${review.syncConfig.apiEndpoint}/reqs/${review.normalizeReqId(reqId)}/requests/${requestId}/approvals`;
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
    review.pushApproval = pushApproval;

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

        for (let i = 0; i < review.syncConfig.retryAttempts; i++) {
            try {
                return await fetch(url, options);
            } catch (error) {
                lastError = error;
                if (i < review.syncConfig.retryAttempts - 1) {
                    await new Promise(r => setTimeout(r, review.syncConfig.retryDelay));
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

        if (review.state.config.autoFetchOnOpen) {
            autoFetchTimer = setInterval(() => {
                fetchReviewData().catch(console.error);
            }, review.syncConfig.autoFetchInterval);
        }
    }
    review.startAutoFetch = startAutoFetch;

    /**
     * Stop auto-fetch timer
     */
    function stopAutoFetch() {
        if (autoFetchTimer) {
            clearInterval(autoFetchTimer);
            autoFetchTimer = null;
        }
    }
    review.stopAutoFetch = stopAutoFetch;

    /**
     * Get last sync time
     * @returns {Date|null} Last sync timestamp
     */
    function getLastSyncTime() {
        return lastSyncTime;
    }
    review.getLastSyncTime = getLastSyncTime;

    /**
     * Check if currently syncing
     * @returns {boolean} True if sync in progress
     */
    function isSyncInProgress() {
        return isSyncing;
    }
    review.isSyncInProgress = isSyncInProgress;

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
    review.showConflictDialog = showConflictDialog;

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
                Refresh
            </button>
        `;
    }
    review.createRefreshButton = createRefreshButton;

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
    review.createSyncStatus = createSyncStatus;

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
    document.addEventListener('traceview:thread-created', async (e) => {
        const { thread } = e.detail;
        try {
            await pushThread(thread);
        } catch (error) {
            console.error('Failed to push thread:', error);
        }
    });

    // Listen for comment additions
    document.addEventListener('traceview:comment-added', async (e) => {
        const { thread, reqId, body } = e.detail;
        const comment = thread.comments[thread.comments.length - 1];
        try {
            await pushComment(reqId, thread.threadId, comment);
        } catch (error) {
            console.error('Failed to push comment:', error);
        }
    });

    // Listen for status request creation
    document.addEventListener('traceview:request-created', async (e) => {
        const { request } = e.detail;
        try {
            await pushStatusRequest(request);
        } catch (error) {
            console.error('Failed to push request:', error);
        }
    });

    // Listen for approval additions
    document.addEventListener('traceview:approval-added', async (e) => {
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
            review.state.loadFromEmbedded(embeddedData);
            lastSyncTime = new Date();
        }

        // Start auto-fetch if enabled
        if (review.state.config.autoFetchOnOpen) {
            startAutoFetch();
        }

        // Initialize git sync status
        initGitSync();

        console.log('Review sync initialized');
    }
    review.initSync = initSync;

    // ==========================================================================
    // Git Sync Operations
    // ==========================================================================

    // Git sync state
    let gitSyncStatus = null;
    let isGitSyncing = false;
    let autoSyncEnabled = true;

    /**
     * Fetch git sync status from server
     */
    async function fetchGitSyncStatus() {
        try {
            const response = await fetch('/api/reviews/sync/status');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            gitSyncStatus = await response.json();
            autoSyncEnabled = gitSyncStatus.auto_sync_enabled !== false;
            updateGitSyncIndicator();
            return gitSyncStatus;
        } catch (error) {
            console.error('Failed to fetch git sync status:', error);
            return null;
        }
    }
    review.fetchGitSyncStatus = fetchGitSyncStatus;

    /**
     * Manually trigger a git sync (commit + push)
     */
    async function gitPush(message) {
        if (isGitSyncing) {
            return { success: false, error: 'Sync already in progress' };
        }

        isGitSyncing = true;
        updateGitSyncIndicator();

        try {
            const response = await fetch('/api/reviews/sync/push', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    user: review.state.currentUser || 'anonymous',
                    message: message || 'Manual sync'
                })
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();

            if (result.success) {
                showSyncIndicator('Git push completed', 'success');
            } else if (result.error) {
                showSyncIndicator(`Git sync error: ${result.error}`, 'error');
            }

            // Refresh status
            await fetchGitSyncStatus();

            return result;
        } catch (error) {
            console.error('Git sync failed:', error);
            showSyncIndicator(`Git sync failed: ${error.message}`, 'error');
            return { success: false, error: error.message };
        } finally {
            isGitSyncing = false;
            updateGitSyncIndicator();
        }
    }
    review.gitPush = gitPush;

    /**
     * Fetch latest review data from remote git
     */
    async function gitFetch() {
        if (isGitSyncing) {
            return { success: false, error: 'Sync already in progress' };
        }

        isGitSyncing = true;
        updateGitSyncIndicator();

        try {
            const response = await fetch('/api/reviews/sync/fetch', {
                method: 'POST'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();

            if (result.success && result.merged) {
                showSyncIndicator('Updated from git remote', 'success');
                // Reload review data if merged
                await fetchReviewData();
            } else if (result.error) {
                showSyncIndicator(`Git fetch error: ${result.error}`, 'error');
            }

            // Refresh status
            await fetchGitSyncStatus();

            return result;
        } catch (error) {
            console.error('Git fetch failed:', error);
            showSyncIndicator(`Git fetch failed: ${error.message}`, 'error');
            return { success: false, error: error.message };
        } finally {
            isGitSyncing = false;
            updateGitSyncIndicator();
        }
    }
    review.gitFetch = gitFetch;

    /**
     * Update the git sync status indicator
     * Shows package context when on a review branch
     */
    function updateGitSyncIndicator() {
        const indicator = document.getElementById('gitSyncIndicator');
        if (!indicator) return;

        if (isGitSyncing) {
            indicator.innerHTML = '<span class="git-sync-icon syncing">&#x21bb;</span> Git syncing...';
            indicator.className = 'git-sync-indicator syncing';
            return;
        }

        if (!gitSyncStatus) {
            indicator.innerHTML = '<span class="git-sync-icon">&#x2300;</span> Git offline';
            indicator.className = 'git-sync-indicator offline';
            return;
        }

        let html = '';
        let className = 'git-sync-indicator';

        // Show package branch context if available
        const currentBranch = review.packages && review.packages.currentBranch;
        if (currentBranch && currentBranch.startsWith('reviews/')) {
            // Parse branch: reviews/{package}/{user}
            const parts = currentBranch.replace('reviews/', '').split('/');
            if (parts.length >= 2) {
                const packageName = parts[0];
                const userName = parts[1];
                html += `<span class="git-branch-context" title="${currentBranch}">${packageName}/${userName}</span> `;
            }
        }

        if (gitSyncStatus.has_local_changes) {
            html += '<span class="git-sync-icon pending">&#x2022;</span> ';
            className += ' pending';
        } else {
            html += '<span class="git-sync-icon synced">&#x2713;</span> ';
        }

        if (gitSyncStatus.ahead > 0) {
            html += `<span class="git-ahead">&uarr;${gitSyncStatus.ahead}</span> `;
        }
        if (gitSyncStatus.behind > 0) {
            html += `<span class="git-behind">&darr;${gitSyncStatus.behind}</span> `;
            className += ' behind';
        }

        if (gitSyncStatus.has_local_changes) {
            html += 'Changes pending';
        } else if (gitSyncStatus.ahead > 0 || gitSyncStatus.behind > 0) {
            html += 'Git sync needed';
        } else {
            html += 'Git synced';
            className += ' synced';
        }

        indicator.innerHTML = html;
        indicator.className = className;
    }
    review.updateGitSyncIndicator = updateGitSyncIndicator;

    /**
     * Handle sync result from API response
     */
    function handleGitSyncResult(result) {
        if (!result || !result.sync) return;

        const sync = result.sync;
        if (sync.success) {
            if (sync.committed) {
                console.log('Review data committed to git');
            }
            if (sync.pushed) {
                console.log('Review data pushed to git remote');
            }
        } else if (sync.error) {
            console.warn('Git sync issue:', sync.error);
        }

        // Refresh sync status
        fetchGitSyncStatus();
    }
    review.handleGitSyncResult = handleGitSyncResult;

    /**
     * Create git sync controls HTML
     */
    function createGitSyncControls() {
        return `
            <div class="git-sync-controls">
                <span id="gitSyncIndicator" class="git-sync-indicator">
                    <span class="git-sync-icon">&#x21bb;</span> Checking...
                </span>
                <div class="git-sync-buttons">
                    <button class="rs-btn rs-btn-sm" onclick="TraceView.review.gitFetch()" title="Fetch from git remote">
                        &#x2193; Fetch
                    </button>
                    <button class="rs-btn rs-btn-sm" onclick="TraceView.review.gitPush()" title="Push to git remote">
                        &#x2191; Push
                    </button>
                    <button class="rs-btn rs-btn-sm rs-btn-fetch-all" onclick="TraceView.review.fetchAllPackageUsers()" title="Fetch data from all package contributors">
                        &#x21c4; Fetch All
                    </button>
                </div>
            </div>
        `;
    }
    review.createGitSyncControls = createGitSyncControls;

    /**
     * Fetch consolidated review data from all users' branches for the current package.
     * This merges data from reviews/{package}/alice, reviews/{package}/bob, etc.
     */
    async function fetchAllPackageUsers() {
        if (isGitSyncing) {
            return { success: false, error: 'Sync already in progress' };
        }

        isGitSyncing = true;
        updateGitSyncIndicator();

        try {
            const response = await fetch('/api/reviews/sync/fetch-all-package', {
                method: 'POST'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();

            if (result.contributors && result.contributors.length > 0) {
                showSyncIndicator(`Loaded data from ${result.contributors.length} contributor(s)`, 'success');

                // Store contributors list
                if (review.packages) {
                    review.packages.contributors = result.contributors;
                }

                // Trigger refresh event so UI updates with merged data
                document.dispatchEvent(new CustomEvent('traceview:data-fetched', {
                    detail: { data: result, timestamp: new Date() }
                }));
            } else if (result.error) {
                showSyncIndicator(`Fetch error: ${result.error}`, 'error');
            } else {
                showSyncIndicator('No contributors found', 'success');
            }

            // Refresh sync status
            await fetchGitSyncStatus();

            return result;
        } catch (error) {
            console.error('Fetch all package users failed:', error);
            showSyncIndicator(`Fetch failed: ${error.message}`, 'error');
            return { success: false, error: error.message };
        } finally {
            isGitSyncing = false;
            updateGitSyncIndicator();
        }
    }
    review.fetchAllPackageUsers = fetchAllPackageUsers;

    /**
     * Initialize git sync on page load
     */
    async function initGitSync() {
        // Fetch initial sync status
        await fetchGitSyncStatus();

        // Auto-fetch on load if behind
        if (gitSyncStatus && gitSyncStatus.behind > 0) {
            console.log('Behind git remote, fetching updates...');
            await gitFetch();
        }

        // Periodically check sync status (every 30 seconds)
        setInterval(fetchGitSyncStatus, 30000);
    }
    review.initGitSync = initGitSync;

    // Inject git sync styles
    const gitSyncStyles = `
        .git-sync-indicator {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            background: #f5f5f5;
            color: #666;
        }

        .git-sync-indicator.synced {
            background: #e8f5e9;
            color: #2e7d32;
        }

        .git-sync-indicator.pending {
            background: #fff3e0;
            color: #ef6c00;
        }

        .git-sync-indicator.behind {
            background: #e3f2fd;
            color: #1565c0;
        }

        .git-sync-indicator.syncing {
            background: #f3e5f5;
            color: #7b1fa2;
        }

        .git-sync-indicator.offline {
            background: #fafafa;
            color: #999;
        }

        .git-sync-icon {
            font-size: 14px;
        }

        .git-sync-icon.syncing {
            animation: git-spin 1s linear infinite;
        }

        .git-sync-icon.pending {
            color: #ff9800;
        }

        .git-sync-icon.synced {
            color: #4caf50;
        }

        @keyframes git-spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }

        .git-ahead {
            color: #4caf50;
            font-weight: bold;
        }

        .git-behind {
            color: #2196f3;
            font-weight: bold;
        }

        .git-sync-controls {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 8px;
            background: #fafafa;
            border-radius: 4px;
            border: 1px solid #e0e0e0;
            margin-bottom: 8px;
        }

        .git-sync-buttons {
            display: flex;
            gap: 4px;
        }

        .git-branch-context {
            display: inline-block;
            padding: 2px 6px;
            background: #e3f2fd;
            color: #1565c0;
            border-radius: 3px;
            font-size: 11px;
            font-weight: 500;
            margin-right: 4px;
            cursor: default;
        }

        .git-branch-context:hover {
            background: #bbdefb;
        }
    `;

    // Inject git sync styles on load
    (function injectGitSyncStyles() {
        if (document.getElementById('git-sync-styles')) return;

        const style = document.createElement('style');
        style.id = 'git-sync-styles';
        style.textContent = gitSyncStyles;
        document.head.appendChild(style);
    })();

})(TraceView.review);
