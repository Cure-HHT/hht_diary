/**
 * Spec Review Status Request UI Module
 *
 * User interface for status change requests:
 * - Status change request form
 * - Approval workflow display
 * - Pending request badges
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
     * Create status request panel HTML
     * @param {string} reqId - Requirement ID
     * @param {string} currentStatus - Current status of the requirement
     * @returns {string} HTML
     */
    function statusPanelTemplate(reqId, currentStatus) {
        // Show quick toggle button for Draft -> Review
        const quickToggle = currentStatus === 'Draft' ? `
            <button class="rs-btn rs-btn-primary rs-quick-toggle" data-req-id="${reqId}">
                Set to Review
            </button>
        ` : '';

        return `
            <div class="rs-status-panel" data-req-id="${reqId}">
                <div class="rs-status-header">
                    <h4>Status</h4>
                    <span class="rs-current-status status-badge status-${currentStatus.toLowerCase()}">
                        ${escapeHtml(currentStatus)}
                    </span>
                </div>
                ${quickToggle ? `<div class="rs-quick-actions">${quickToggle}</div>` : ''}
                <div class="rs-status-content">
                    <div class="rs-requests"></div>
                    <div class="rs-no-requests" style="display: none;">
                        No pending status change requests.
                    </div>
                </div>
                <div class="rs-status-actions">
                    <button class="rs-btn rs-btn-secondary rs-request-change-btn">
                        Request Status Change
                    </button>
                </div>
            </div>
        `;
    }

    /**
     * Create status request card HTML
     * @param {StatusRequest} request - Request object
     * @returns {string} HTML
     */
    function requestCardTemplate(request) {
        const stateClass = `rs-state-${request.state}`;
        const stateLabel = getStateLabel(request.state);
        const progressPercent = getApprovalProgress(request);

        return `
            <div class="rs-request-card ${stateClass}" data-request-id="${request.requestId}">
                <div class="rs-request-header">
                    <span class="rs-request-transition">
                        ${escapeHtml(request.fromStatus)} → ${escapeHtml(request.toStatus)}
                    </span>
                    <span class="rs-request-state rs-badge rs-badge-${request.state}">
                        ${stateLabel}
                    </span>
                </div>
                <div class="rs-request-meta">
                    <span>Requested by <strong>${escapeHtml(request.requestedBy)}</strong></span>
                    <span>${formatTime(request.requestedAt)}</span>
                </div>
                <div class="rs-request-justification">
                    ${formatCommentBody(request.justification)}
                </div>
                <div class="rs-approval-progress">
                    <div class="rs-progress-bar">
                        <div class="rs-progress-fill" style="width: ${progressPercent}%"></div>
                    </div>
                    <span class="rs-progress-label">
                        ${request.approvals.length}/${request.requiredApprovers.length} approvals
                    </span>
                </div>
                <div class="rs-approvers-list">
                    ${renderApproversList(request)}
                </div>
                ${request.state === RS.RequestState.PENDING ? renderApprovalActions(request) : ''}
            </div>
        `;
    }

    /**
     * Render approvers list with status
     * @param {StatusRequest} request - Request object
     * @returns {string} HTML
     */
    function renderApproversList(request) {
        const approvalMap = {};
        request.approvals.forEach(a => {
            approvalMap[a.user] = a;
        });

        return `
            <div class="rs-approvers">
                ${request.requiredApprovers.map(approver => {
                    const approval = approvalMap[approver];
                    if (approval) {
                        const icon = approval.decision === 'approve' ? '✓' : '✗';
                        const cls = approval.decision === 'approve' ? 'approved' : 'rejected';
                        return `
                            <span class="rs-approver rs-approver-${cls}" title="${approval.comment || ''}">
                                ${icon} ${escapeHtml(approver)}
                            </span>
                        `;
                    } else {
                        return `
                            <span class="rs-approver rs-approver-pending">
                                ○ ${escapeHtml(approver)}
                            </span>
                        `;
                    }
                }).join('')}
            </div>
        `;
    }

    /**
     * Render approval action buttons
     * @param {StatusRequest} request - Request object
     * @returns {string} HTML
     */
    function renderApprovalActions(request) {
        const user = RS.state.currentUser;
        if (!user || !request.requiredApprovers.includes(user)) {
            return '';
        }

        // Check if user already approved
        const existing = request.approvals.find(a => a.user === user);
        if (existing) {
            return `<div class="rs-already-voted">You have already ${existing.decision}d this request.</div>`;
        }

        return `
            <div class="rs-approval-actions">
                <button class="rs-btn rs-btn-success rs-approve-btn">Approve</button>
                <button class="rs-btn rs-btn-danger rs-reject-btn">Reject</button>
                <input type="text" class="rs-approval-comment" placeholder="Comment (optional)">
            </div>
        `;
    }

    /**
     * Create new request form HTML
     * @param {string} reqId - Requirement ID
     * @param {string} currentStatus - Current status
     * @returns {string} HTML
     */
    function requestFormTemplate(reqId, currentStatus) {
        const transitions = getValidTransitions(currentStatus);

        return `
            <div class="rs-request-form" data-req-id="${reqId}">
                <h4>Request Status Change</h4>
                <div class="rs-form-group">
                    <label>Current Status</label>
                    <span class="rs-current-status-display">${escapeHtml(currentStatus)}</span>
                </div>
                <div class="rs-form-group">
                    <label>New Status</label>
                    <select class="rs-new-status">
                        ${transitions.map(status =>
                            `<option value="${status}">${status}</option>`
                        ).join('')}
                    </select>
                </div>
                <div class="rs-form-group">
                    <label>Justification</label>
                    <textarea class="rs-justification" rows="3"
                              placeholder="Explain why this status change is needed..."></textarea>
                </div>
                <div class="rs-required-approvers">
                    <label>Required Approvers</label>
                    <span class="rs-approvers-display"></span>
                </div>
                <div class="rs-form-actions">
                    <button class="rs-btn rs-btn-primary rs-submit-request">Submit Request</button>
                    <button class="rs-btn rs-cancel-request">Cancel</button>
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
            return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        } catch (e) {
            return isoString;
        }
    }

    function formatCommentBody(body) {
        let html = escapeHtml(body);
        html = html.replace(/\n/g, '<br>');
        return html;
    }

    function getStateLabel(state) {
        switch (state) {
            case RS.RequestState.PENDING: return 'Pending';
            case RS.RequestState.APPROVED: return 'Approved';
            case RS.RequestState.REJECTED: return 'Rejected';
            case RS.RequestState.APPLIED: return 'Applied';
            default: return state;
        }
    }

    function getApprovalProgress(request) {
        if (request.requiredApprovers.length === 0) return 100;
        const approved = request.approvals.filter(a => a.decision === 'approve').length;
        return Math.round((approved / request.requiredApprovers.length) * 100);
    }

    function getValidTransitions(currentStatus) {
        const transitions = {
            'Draft': ['Review', 'Active', 'Deprecated'],
            'Review': ['Active', 'Draft', 'Deprecated'],
            'Active': ['Deprecated'],
            'Deprecated': [] // No transitions from Deprecated
        };
        return transitions[currentStatus] || [];
    }

    /**
     * Change status directly via API (no approval workflow)
     * @param {string} reqId - Requirement ID
     * @param {string} newStatus - New status to set
     * @returns {Promise<object>} API response
     */
    async function changeStatusDirect(reqId, newStatus) {
        const user = RS.state.currentUser || 'anonymous';
        try {
            const response = await fetch(`/api/reviews/reqs/${reqId}/status`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ newStatus, user })
            });
            const result = await response.json();
            if (result.success) {
                // Update local state
                const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
                if (reqData) {
                    reqData.status = newStatus;
                }
                // Refresh status display
                updateStatusBadge(reqId, newStatus);

                // Handle auto-add to package when status changes to Review
                if (result.addedToPackage && typeof RS.renderPackagesPanel === 'function') {
                    // Update local package state
                    const pkg = RS.packages && RS.packages.items &&
                                RS.packages.items.find(p => p.packageId === result.addedToPackage.packageId);
                    if (pkg && !pkg.reqIds.includes(reqId)) {
                        pkg.reqIds.push(reqId);
                    }
                    // Re-render packages panel to update counts
                    RS.renderPackagesPanel();
                    console.log(`REQ-${reqId} added to package: ${result.addedToPackage.packageName}`);
                }
            }
            return result;
        } catch (error) {
            console.error('Error changing status:', error);
            return { success: false, error: error.message };
        }
    }
    RS.changeStatusDirect = changeStatusDirect;

    /**
     * Update status badge in the UI
     * @param {string} reqId - Requirement ID
     * @param {string} newStatus - New status
     */
    function updateStatusBadge(reqId, newStatus) {
        // Update in grid/tree
        const statusBadge = document.querySelector(`[data-req-id="${reqId}"] .status-badge`);
        if (statusBadge) {
            statusBadge.className = `status-badge status-${newStatus.toLowerCase()}`;
            statusBadge.textContent = newStatus;
        }
        // Update in middle column if visible
        const middleStatusBadge = document.querySelector(`#req-card-${reqId} .status-badge`);
        if (middleStatusBadge) {
            middleStatusBadge.className = `status-badge status-${newStatus.toLowerCase()}`;
            middleStatusBadge.textContent = newStatus;
        }
    }
    RS.updateStatusBadge = updateStatusBadge;

    /**
     * Toggle Draft to Review status (shortcut for review mode)
     * @param {string} reqId - Requirement ID
     * @returns {Promise<object>} API response
     */
    async function toggleToReview(reqId) {
        const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
        if (!reqData) return { success: false, error: 'REQ not found' };

        if (reqData.status === 'Draft') {
            return await changeStatusDirect(reqId, 'Review');
        }
        return { success: false, error: 'Can only toggle Draft to Review' };
    }
    RS.toggleToReview = toggleToReview;

    // ==========================================================================
    // UI Components
    // ==========================================================================

    /**
     * Render status panel for a requirement
     * @param {Element} container - Container element
     * @param {string} reqId - Requirement ID
     * @param {string} currentStatus - Current requirement status
     */
    function renderStatusPanel(container, reqId, currentStatus) {
        container.innerHTML = statusPanelTemplate(reqId, currentStatus);

        const requests = RS.state.getRequests(reqId);
        const requestsContainer = container.querySelector('.rs-requests');
        const noRequests = container.querySelector('.rs-no-requests');

        if (requests.length === 0) {
            noRequests.style.display = 'block';
        } else {
            requests.forEach(request => {
                requestsContainer.insertAdjacentHTML('beforeend', requestCardTemplate(request));
            });
            bindRequestEvents(container);
        }

        // Bind quick toggle button
        const quickToggleBtn = container.querySelector('.rs-quick-toggle');
        if (quickToggleBtn) {
            quickToggleBtn.addEventListener('click', async () => {
                quickToggleBtn.disabled = true;
                quickToggleBtn.textContent = 'Updating...';
                const result = await toggleToReview(reqId);
                if (result.success) {
                    // Re-render the panel with new status
                    renderStatusPanel(container, reqId, 'Review');
                } else {
                    quickToggleBtn.disabled = false;
                    quickToggleBtn.textContent = 'Set to Review';
                    alert('Failed to change status: ' + (result.error || 'Unknown error'));
                }
            });
        }

        // Bind request change button
        const requestBtn = container.querySelector('.rs-request-change-btn');
        if (requestBtn) {
            const transitions = getValidTransitions(currentStatus);
            if (transitions.length === 0) {
                requestBtn.disabled = true;
                requestBtn.title = 'No valid transitions from current status';
            } else {
                requestBtn.addEventListener('click', () => {
                    showRequestForm(container, reqId, currentStatus);
                });
            }
        }
    }
    RS.renderStatusPanel = renderStatusPanel;

    /**
     * Show request form
     * @param {Element} container - Container element
     * @param {string} reqId - Requirement ID
     * @param {string} currentStatus - Current status
     */
    function showRequestForm(container, reqId, currentStatus) {
        // Remove existing form
        let form = container.querySelector('.rs-request-form');
        if (form) form.remove();

        container.insertAdjacentHTML('afterbegin', requestFormTemplate(reqId, currentStatus));
        form = container.querySelector('.rs-request-form');

        // Update approvers display on status change
        const newStatus = form.querySelector('.rs-new-status');
        const approversDisplay = form.querySelector('.rs-approvers-display');

        function updateApprovers() {
            const toStatus = newStatus.value;
            const approvers = RS.state.config.getRequiredApprovers(currentStatus, toStatus);
            approversDisplay.textContent = approvers.join(', ');
        }
        updateApprovers();
        newStatus.addEventListener('change', updateApprovers);

        // Submit handler
        form.querySelector('.rs-submit-request').addEventListener('click', () => {
            submitStatusRequest(form, reqId, currentStatus);
        });

        // Cancel handler
        form.querySelector('.rs-cancel-request').addEventListener('click', () => {
            form.remove();
        });

        // Focus justification
        form.querySelector('.rs-justification').focus();
    }
    RS.showRequestForm = showRequestForm;

    /**
     * Submit status change request
     * @param {Element} form - Form element
     * @param {string} reqId - Requirement ID
     * @param {string} currentStatus - Current status
     */
    function submitStatusRequest(form, reqId, currentStatus) {
        const newStatus = form.querySelector('.rs-new-status').value;
        const justification = form.querySelector('.rs-justification').value.trim();

        if (!justification) {
            alert('Please provide a justification');
            return;
        }

        const user = RS.state.currentUser || 'anonymous';
        const approvers = RS.state.config.getRequiredApprovers(currentStatus, newStatus);

        // Create request
        const request = RS.StatusRequest.create(
            reqId, currentStatus, newStatus, user, justification, approvers
        );
        RS.state.addRequest(request);

        // Trigger event
        document.dispatchEvent(new CustomEvent('rs:request-created', {
            detail: { request, reqId }
        }));

        // Re-render
        const panel = form.closest('.rs-status-panel');
        if (panel) {
            renderStatusPanel(panel.parentElement, reqId, currentStatus);
        } else {
            form.remove();
        }
    }

    /**
     * Bind event handlers to request elements
     * @param {Element} container - Container element
     */
    function bindRequestEvents(container) {
        // Approve buttons
        container.querySelectorAll('.rs-approve-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const card = btn.closest('.rs-request-card');
                submitApproval(card, container, 'approve');
            });
        });

        // Reject buttons
        container.querySelectorAll('.rs-reject-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const card = btn.closest('.rs-request-card');
                submitApproval(card, container, 'reject');
            });
        });
    }

    /**
     * Submit approval/rejection
     * @param {Element} card - Request card element
     * @param {Element} container - Container element
     * @param {string} decision - 'approve' or 'reject'
     */
    function submitApproval(card, container, decision) {
        const requestId = card.getAttribute('data-request-id');
        const comment = card.querySelector('.rs-approval-comment')?.value || '';
        const user = RS.state.currentUser;
        const reqId = container.querySelector('[data-req-id]')?.getAttribute('data-req-id') ||
                      container.closest('[data-req-id]')?.getAttribute('data-req-id');

        if (!user) {
            alert('Please set your username first');
            return;
        }

        if (reqId) {
            const requests = RS.state.getRequests(reqId);
            const request = requests.find(r => r.requestId === requestId);
            if (request) {
                request.addApproval(user, decision, comment);

                // Trigger event
                document.dispatchEvent(new CustomEvent('rs:approval-added', {
                    detail: { request, reqId, user, decision }
                }));

                // Get current status from display
                const currentStatus = container.querySelector('.rs-current-status strong')?.textContent || 'Draft';

                // Re-render
                renderStatusPanel(container.parentElement || container, reqId, currentStatus);
            }
        }
    }

    /**
     * Get pending request count for a requirement
     * @param {string} reqId - Requirement ID
     * @returns {number} Count of pending requests
     */
    function getPendingRequestCount(reqId) {
        const requests = RS.state.getRequests(reqId);
        return requests.filter(r => r.state === RS.RequestState.PENDING).length;
    }
    RS.getPendingRequestCount = getPendingRequestCount;

    /**
     * Create status badge for display in REQ list
     * @param {string} reqId - Requirement ID
     * @returns {string} HTML for badge or empty string
     */
    function createStatusBadge(reqId) {
        const pending = getPendingRequestCount(reqId);
        if (pending === 0) return '';

        return `<span class="rs-badge rs-badge-pending" title="${pending} pending status request(s)">
            ⏳ ${pending}
        </span>`;
    }
    RS.createStatusBadge = createStatusBadge;

})(window.ReviewSystem);
