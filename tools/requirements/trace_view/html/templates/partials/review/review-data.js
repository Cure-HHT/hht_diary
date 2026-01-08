/**
 * TraceView Review Data Module
 *
 * Client-side data structures matching Python models.
 * Provides validation, serialization, and local state management.
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

    review.PositionType = Object.freeze({
        LINE: 'line',
        BLOCK: 'block',
        WORD: 'word',
        GENERAL: 'general'
    });

    review.RequestState = Object.freeze({
        PENDING: 'pending',
        APPROVED: 'approved',
        REJECTED: 'rejected',
        APPLIED: 'applied'
    });

    review.ApprovalDecision = Object.freeze({
        APPROVE: 'approve',
        REJECT: 'reject'
    });

    review.VALID_REQ_STATUSES = ['Draft', 'Active', 'Deprecated'];

    review.DEFAULT_APPROVAL_RULES = {
        'Draft->Active': ['product_owner', 'tech_lead'],
        'Active->Deprecated': ['product_owner'],
        'Draft->Deprecated': ['product_owner']
    };

    // ==========================================================================
    // Utility Functions
    // ==========================================================================

    /**
     * Generate a UUID v4
     * @returns {string} UUID string
     */
    review.generateUuid = function() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    };

    /**
     * Get current UTC timestamp in ISO 8601 format
     * @returns {string} ISO timestamp
     */
    review.nowIso = function() {
        return new Date().toISOString();
    };

    /**
     * Validate REQ ID format
     * @param {string} reqId - Requirement ID to validate
     * @returns {boolean} True if valid
     */
    review.validateReqId = function(reqId) {
        if (!reqId) return false;
        // Match: d00001, p00042, o00003, or CAL-d00001 (sponsor prefix)
        // But NOT REQ-d00001
        const pattern = /^(?!REQ-)(?:[A-Z]{2,4}-)?[pod]\d{5}$/;
        return pattern.test(reqId);
    };

    /**
     * Validate 8-character hex hash format
     * @param {string} hash - Hash to validate
     * @returns {boolean} True if valid
     */
    review.validateHash = function(hash) {
        if (!hash) return false;
        return /^[a-fA-F0-9]{8}$/.test(hash);
    };

    /**
     * Normalize REQ ID (remove REQ- prefix, lowercase)
     * @param {string} reqId - Requirement ID
     * @returns {string} Normalized ID
     */
    review.normalizeReqId = function(reqId) {
        if (!reqId) return '';
        if (reqId.toUpperCase().startsWith('REQ-')) {
            reqId = reqId.substring(4);
        }
        return reqId.toLowerCase();
    };

    // ==========================================================================
    // Data Classes
    // ==========================================================================

    /**
     * Comment position anchor within a requirement
     */
    class CommentPosition {
        constructor(data) {
            this.type = data.type;
            this.hashWhenCreated = data.hashWhenCreated;
            this.lineNumber = data.lineNumber || null;
            this.lineRange = data.lineRange || null;
            this.keyword = data.keyword || null;
            this.keywordOccurrence = data.keywordOccurrence || null;
            this.fallbackContext = data.fallbackContext || null;
        }

        static createLine(hash, lineNumber, context) {
            return new CommentPosition({
                type: review.PositionType.LINE,
                hashWhenCreated: hash,
                lineNumber: lineNumber,
                fallbackContext: context || null
            });
        }

        static createBlock(hash, startLine, endLine, context) {
            return new CommentPosition({
                type: review.PositionType.BLOCK,
                hashWhenCreated: hash,
                lineRange: [startLine, endLine],
                fallbackContext: context || null
            });
        }

        static createWord(hash, keyword, occurrence, context) {
            return new CommentPosition({
                type: review.PositionType.WORD,
                hashWhenCreated: hash,
                keyword: keyword,
                keywordOccurrence: occurrence || 1,
                fallbackContext: context || null
            });
        }

        static createGeneral(hash) {
            return new CommentPosition({
                type: review.PositionType.GENERAL,
                hashWhenCreated: hash
            });
        }

        validate() {
            const errors = [];
            const validTypes = Object.values(review.PositionType);

            if (!validTypes.includes(this.type)) {
                errors.push(`Invalid position type: ${this.type}`);
            }

            if (!review.validateHash(this.hashWhenCreated)) {
                errors.push(`Invalid hash format: ${this.hashWhenCreated}`);
            }

            if (this.type === review.PositionType.LINE) {
                if (this.lineNumber === null) {
                    errors.push('lineNumber required for line type');
                } else if (this.lineNumber < 1) {
                    errors.push('lineNumber must be positive');
                }
            }

            if (this.type === review.PositionType.BLOCK) {
                if (!this.lineRange || this.lineRange.length !== 2) {
                    errors.push('lineRange required for block type');
                } else if (this.lineRange[0] < 1 || this.lineRange[1] < this.lineRange[0]) {
                    errors.push('Invalid lineRange');
                }
            }

            if (this.type === review.PositionType.WORD) {
                if (!this.keyword) {
                    errors.push('keyword required for word type');
                }
            }

            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            const result = {
                type: this.type,
                hashWhenCreated: this.hashWhenCreated
            };
            if (this.lineNumber !== null) result.lineNumber = this.lineNumber;
            if (this.lineRange !== null) result.lineRange = this.lineRange;
            if (this.keyword !== null) result.keyword = this.keyword;
            if (this.keywordOccurrence !== null) result.keywordOccurrence = this.keywordOccurrence;
            if (this.fallbackContext !== null) result.fallbackContext = this.fallbackContext;
            return result;
        }

        static fromDict(data) {
            return new CommentPosition(data);
        }
    }
    review.CommentPosition = CommentPosition;

    /**
     * Single comment in a thread
     */
    class Comment {
        constructor(data) {
            this.id = data.id;
            this.author = data.author;
            this.timestamp = data.timestamp;
            this.body = data.body;
        }

        static create(author, body) {
            return new Comment({
                id: review.generateUuid(),
                author: author,
                timestamp: review.nowIso(),
                body: body
            });
        }

        validate() {
            const errors = [];
            if (!this.id) errors.push('Comment id is required');
            if (!this.author) errors.push('Comment author is required');
            if (!this.timestamp) errors.push('Comment timestamp is required');
            if (!this.body || !this.body.trim()) errors.push('Comment body cannot be empty');
            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            return {
                id: this.id,
                author: this.author,
                timestamp: this.timestamp,
                body: this.body
            };
        }

        static fromDict(data) {
            return new Comment(data);
        }
    }
    review.Comment = Comment;

    /**
     * Comment thread with position anchor
     */
    class Thread {
        constructor(data) {
            this.threadId = data.threadId;
            this.reqId = data.reqId;
            this.createdBy = data.createdBy;
            this.createdAt = data.createdAt;
            this.position = data.position instanceof CommentPosition ?
                data.position : CommentPosition.fromDict(data.position);
            this.resolved = data.resolved || false;
            this.resolvedBy = data.resolvedBy || null;
            this.resolvedAt = data.resolvedAt || null;
            this.comments = (data.comments || []).map(c =>
                c instanceof Comment ? c : Comment.fromDict(c)
            );
        }

        static create(reqId, creator, position, initialComment) {
            const thread = new Thread({
                threadId: review.generateUuid(),
                reqId: reqId,
                createdBy: creator,
                createdAt: review.nowIso(),
                position: position,
                comments: []
            });
            if (initialComment) {
                thread.addComment(creator, initialComment);
            }
            return thread;
        }

        addComment(author, body) {
            const comment = Comment.create(author, body);
            this.comments.push(comment);
            return comment;
        }

        resolve(user) {
            this.resolved = true;
            this.resolvedBy = user;
            this.resolvedAt = review.nowIso();
        }

        unresolve() {
            this.resolved = false;
            this.resolvedBy = null;
            this.resolvedAt = null;
        }

        validate() {
            const errors = [];
            if (!this.threadId) errors.push('Thread threadId is required');
            if (!review.validateReqId(this.reqId)) {
                errors.push(`Invalid requirement ID: ${this.reqId}`);
            }
            if (!this.createdBy) errors.push('Thread createdBy is required');

            const posValidation = this.position.validate();
            posValidation.errors.forEach(e => errors.push(`Position: ${e}`));

            if (this.resolved) {
                if (!this.resolvedBy) errors.push('Resolved thread must have resolvedBy');
                if (!this.resolvedAt) errors.push('Resolved thread must have resolvedAt');
            }

            this.comments.forEach((c, i) => {
                const commentValidation = c.validate();
                commentValidation.errors.forEach(e => errors.push(`Comment[${i}]: ${e}`));
            });

            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            return {
                threadId: this.threadId,
                reqId: this.reqId,
                createdBy: this.createdBy,
                createdAt: this.createdAt,
                position: this.position.toDict(),
                resolved: this.resolved,
                resolvedBy: this.resolvedBy,
                resolvedAt: this.resolvedAt,
                comments: this.comments.map(c => c.toDict())
            };
        }

        static fromDict(data) {
            return new Thread(data);
        }
    }
    review.Thread = Thread;

    /**
     * Review flag for a requirement
     */
    class ReviewFlag {
        constructor(data) {
            this.flaggedForReview = data.flaggedForReview;
            this.flaggedBy = data.flaggedBy || '';
            this.flaggedAt = data.flaggedAt || '';
            this.reason = data.reason || '';
            this.scope = data.scope || [];
        }

        static create(user, reason, scope) {
            return new ReviewFlag({
                flaggedForReview: true,
                flaggedBy: user,
                flaggedAt: review.nowIso(),
                reason: reason,
                scope: scope
            });
        }

        static cleared() {
            return new ReviewFlag({
                flaggedForReview: false
            });
        }

        validate() {
            const errors = [];
            if (this.flaggedForReview) {
                if (!this.flaggedBy) errors.push('Flagged review must have flaggedBy');
                if (!this.flaggedAt) errors.push('Flagged review must have flaggedAt');
                if (!this.reason) errors.push('Flagged review must have reason');
                if (!this.scope || this.scope.length === 0) {
                    errors.push('Flagged review must have non-empty scope');
                }
            }
            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            return {
                flaggedForReview: this.flaggedForReview,
                flaggedBy: this.flaggedBy,
                flaggedAt: this.flaggedAt,
                reason: this.reason,
                scope: this.scope
            };
        }

        static fromDict(data) {
            return new ReviewFlag(data);
        }
    }
    review.ReviewFlag = ReviewFlag;

    /**
     * Approval on a status change request
     */
    class Approval {
        constructor(data) {
            this.user = data.user;
            this.decision = data.decision;
            this.at = data.at;
            this.comment = data.comment || null;
        }

        static create(user, decision, comment) {
            return new Approval({
                user: user,
                decision: decision,
                at: review.nowIso(),
                comment: comment || null
            });
        }

        validate() {
            const errors = [];
            if (!this.user) errors.push('Approval user is required');
            if (!Object.values(review.ApprovalDecision).includes(this.decision)) {
                errors.push(`Invalid decision: ${this.decision}`);
            }
            if (!this.at) errors.push('Approval timestamp is required');
            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            const result = {
                user: this.user,
                decision: this.decision,
                at: this.at
            };
            if (this.comment !== null) result.comment = this.comment;
            return result;
        }

        static fromDict(data) {
            return new Approval(data);
        }
    }
    review.Approval = Approval;

    /**
     * Status change request
     */
    class StatusRequest {
        constructor(data) {
            this.requestId = data.requestId;
            this.reqId = data.reqId;
            this.type = data.type || 'status_change';
            this.fromStatus = data.fromStatus;
            this.toStatus = data.toStatus;
            this.requestedBy = data.requestedBy;
            this.requestedAt = data.requestedAt;
            this.justification = data.justification;
            this.approvals = (data.approvals || []).map(a =>
                a instanceof Approval ? a : Approval.fromDict(a)
            );
            this.requiredApprovers = data.requiredApprovers || [];
            this.state = data.state || review.RequestState.PENDING;
        }

        static create(reqId, fromStatus, toStatus, requestedBy, justification, requiredApprovers) {
            if (!requiredApprovers) {
                const key = `${fromStatus}->${toStatus}`;
                requiredApprovers = review.DEFAULT_APPROVAL_RULES[key] || ['product_owner'];
            }
            return new StatusRequest({
                requestId: review.generateUuid(),
                reqId: reqId,
                type: 'status_change',
                fromStatus: fromStatus,
                toStatus: toStatus,
                requestedBy: requestedBy,
                requestedAt: review.nowIso(),
                justification: justification,
                approvals: [],
                requiredApprovers: requiredApprovers,
                state: review.RequestState.PENDING
            });
        }

        addApproval(user, decision, comment) {
            const approval = Approval.create(user, decision, comment);
            this.approvals.push(approval);
            this._updateState();
            return approval;
        }

        _updateState() {
            if (this.state === review.RequestState.APPLIED) return;

            // Check for rejections
            for (const approval of this.approvals) {
                if (approval.decision === review.ApprovalDecision.REJECT) {
                    this.state = review.RequestState.REJECTED;
                    return;
                }
            }

            // Check if all required approvers have approved
            const approvedUsers = new Set(
                this.approvals
                    .filter(a => a.decision === review.ApprovalDecision.APPROVE)
                    .map(a => a.user)
            );

            const allApproved = this.requiredApprovers.every(
                approver => approvedUsers.has(approver)
            );

            this.state = allApproved ? review.RequestState.APPROVED : review.RequestState.PENDING;
        }

        markApplied() {
            if (this.state !== review.RequestState.APPROVED) {
                throw new Error('Can only apply approved requests');
            }
            this.state = review.RequestState.APPLIED;
        }

        validate() {
            const errors = [];
            if (!this.requestId) errors.push('requestId is required');
            if (!review.validateReqId(this.reqId)) {
                errors.push(`Invalid requirement ID: ${this.reqId}`);
            }
            if (this.type !== 'status_change') {
                errors.push(`Invalid type: ${this.type}`);
            }
            if (!review.VALID_REQ_STATUSES.includes(this.fromStatus)) {
                errors.push(`Invalid fromStatus: ${this.fromStatus}`);
            }
            if (!review.VALID_REQ_STATUSES.includes(this.toStatus)) {
                errors.push(`Invalid toStatus: ${this.toStatus}`);
            }
            if (this.fromStatus === this.toStatus) {
                errors.push('fromStatus and toStatus must be different');
            }
            if (!this.requestedBy) errors.push('requestedBy is required');
            if (!this.justification) errors.push('justification is required');
            if (!Object.values(review.RequestState).includes(this.state)) {
                errors.push(`Invalid state: ${this.state}`);
            }

            this.approvals.forEach((a, i) => {
                const approvalValidation = a.validate();
                approvalValidation.errors.forEach(e => errors.push(`Approval[${i}]: ${e}`));
            });

            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            return {
                requestId: this.requestId,
                reqId: this.reqId,
                type: this.type,
                fromStatus: this.fromStatus,
                toStatus: this.toStatus,
                requestedBy: this.requestedBy,
                requestedAt: this.requestedAt,
                justification: this.justification,
                approvals: this.approvals.map(a => a.toDict()),
                requiredApprovers: this.requiredApprovers,
                state: this.state
            };
        }

        static fromDict(data) {
            return new StatusRequest(data);
        }
    }
    review.StatusRequest = StatusRequest;

    /**
     * Review session metadata
     */
    class ReviewSession {
        constructor(data) {
            this.sessionId = data.sessionId;
            this.user = data.user;
            this.name = data.name;
            this.createdAt = data.createdAt;
            this.description = data.description || null;
        }

        static create(user, name, description) {
            return new ReviewSession({
                sessionId: review.generateUuid(),
                user: user,
                name: name,
                createdAt: review.nowIso(),
                description: description || null
            });
        }

        validate() {
            const errors = [];
            if (!this.sessionId) errors.push('sessionId is required');
            if (!this.user) errors.push('user is required');
            if (!this.name) errors.push('name is required');
            if (!this.createdAt) errors.push('createdAt is required');
            return { valid: errors.length === 0, errors: errors };
        }

        toDict() {
            const result = {
                sessionId: this.sessionId,
                user: this.user,
                name: this.name,
                createdAt: this.createdAt
            };
            if (this.description !== null) result.description = this.description;
            return result;
        }

        static fromDict(data) {
            return new ReviewSession(data);
        }
    }
    review.ReviewSession = ReviewSession;

    /**
     * Review system configuration
     */
    class ReviewConfig {
        constructor(data) {
            this.approvalRules = data.approvalRules || Object.assign({}, review.DEFAULT_APPROVAL_RULES);
            this.pushOnComment = data.pushOnComment !== undefined ? data.pushOnComment : true;
            this.autoFetchOnOpen = data.autoFetchOnOpen !== undefined ? data.autoFetchOnOpen : true;
        }

        static createDefault() {
            return new ReviewConfig({});
        }

        getRequiredApprovers(fromStatus, toStatus) {
            const key = `${fromStatus}->${toStatus}`;
            return this.approvalRules[key] || ['product_owner'];
        }

        toDict() {
            return {
                approvalRules: this.approvalRules,
                pushOnComment: this.pushOnComment,
                autoFetchOnOpen: this.autoFetchOnOpen
            };
        }

        static fromDict(data) {
            return new ReviewConfig(data);
        }
    }
    review.ReviewConfig = ReviewConfig;

    // ==========================================================================
    // State Management
    // ==========================================================================

    /**
     * Local state manager for review data
     */
    class ReviewState {
        constructor() {
            this.threads = {};      // reqId -> Thread[]
            this.flags = {};        // reqId -> ReviewFlag
            this.requests = {};     // reqId -> StatusRequest[]
            this.sessions = [];     // ReviewSession[]
            this.config = ReviewConfig.createDefault();
            this.currentUser = null;
            this.currentSession = null;
        }

        /**
         * Load review data from embedded JSON
         * @param {Object} data - Embedded review data
         */
        loadFromEmbedded(data) {
            if (data.threads) {
                for (const reqId in data.threads) {
                    this.threads[reqId] = data.threads[reqId].map(t => Thread.fromDict(t));
                }
            }
            if (data.flags) {
                for (const reqId in data.flags) {
                    this.flags[reqId] = ReviewFlag.fromDict(data.flags[reqId]);
                }
            }
            if (data.requests) {
                for (const reqId in data.requests) {
                    this.requests[reqId] = data.requests[reqId].map(r => StatusRequest.fromDict(r));
                }
            }
            if (data.sessions) {
                this.sessions = data.sessions.map(s => ReviewSession.fromDict(s));
            }
            if (data.config) {
                this.config = ReviewConfig.fromDict(data.config);
            }
        }

        /**
         * Get threads for a requirement
         * @param {string} reqId - Requirement ID
         * @returns {Thread[]} Array of threads
         */
        getThreads(reqId) {
            const normalizedId = review.normalizeReqId(reqId);
            return this.threads[normalizedId] || [];
        }

        /**
         * Get review flag for a requirement
         * @param {string} reqId - Requirement ID
         * @returns {ReviewFlag} Review flag
         */
        getFlag(reqId) {
            const normalizedId = review.normalizeReqId(reqId);
            return this.flags[normalizedId] || ReviewFlag.cleared();
        }

        /**
         * Get status requests for a requirement
         * @param {string} reqId - Requirement ID
         * @returns {StatusRequest[]} Array of requests
         */
        getRequests(reqId) {
            const normalizedId = review.normalizeReqId(reqId);
            return this.requests[normalizedId] || [];
        }

        /**
         * Get all flagged requirement IDs
         * @returns {string[]} Array of flagged requirement IDs
         */
        getFlaggedReqs() {
            return Object.keys(this.flags).filter(
                reqId => this.flags[reqId].flaggedForReview
            );
        }

        /**
         * Add a thread
         * @param {Thread} thread - Thread to add
         */
        addThread(thread) {
            const normalizedId = review.normalizeReqId(thread.reqId);
            if (!this.threads[normalizedId]) {
                this.threads[normalizedId] = [];
            }
            this.threads[normalizedId].push(thread);
        }

        /**
         * Set review flag
         * @param {string} reqId - Requirement ID
         * @param {ReviewFlag} flag - Review flag
         */
        setFlag(reqId, flag) {
            const normalizedId = review.normalizeReqId(reqId);
            this.flags[normalizedId] = flag;
        }

        /**
         * Add a status request
         * @param {StatusRequest} request - Request to add
         */
        addRequest(request) {
            const normalizedId = review.normalizeReqId(request.reqId);
            if (!this.requests[normalizedId]) {
                this.requests[normalizedId] = [];
            }
            this.requests[normalizedId].push(request);
        }

        /**
         * Export state to JSON
         * @returns {Object} Serializable state
         */
        toJSON() {
            const result = {
                threads: {},
                flags: {},
                requests: {},
                sessions: this.sessions.map(s => s.toDict()),
                config: this.config.toDict()
            };

            for (const reqId in this.threads) {
                result.threads[reqId] = this.threads[reqId].map(t => t.toDict());
            }
            for (const reqId in this.flags) {
                result.flags[reqId] = this.flags[reqId].toDict();
            }
            for (const reqId in this.requests) {
                result.requests[reqId] = this.requests[reqId].map(r => r.toDict());
            }

            return result;
        }
    }
    review.ReviewState = ReviewState;

    // Global state instance
    review.state = new ReviewState();

    // ==========================================================================
    // Event Listeners for Requirement Selection
    // ==========================================================================

    /**
     * Currently selected requirement ID
     */
    review.selectedReqId = null;

    /**
     * Handle requirement selection event
     * @param {CustomEvent} event - Event with reqId in detail
     */
    function handleReqSelected(event) {
        const { reqId, req } = event.detail;
        review.selectedReqId = reqId;

        // Update review panel header
        const panelContent = document.getElementById('review-panel-content');
        const noSelection = document.getElementById('review-no-selection');

        if (panelContent && noSelection) {
            noSelection.style.display = 'none';
            panelContent.style.display = 'block';

            // Build requirement header
            const reqHeader = document.createElement('div');
            reqHeader.className = 'review-panel-req-header';
            reqHeader.innerHTML = `
                <span class="req-id-badge">REQ-${reqId}</span>
                <span class="req-title-text">${req ? req.title : reqId}</span>
            `;

            // Clear existing content and add header
            panelContent.innerHTML = '';
            panelContent.appendChild(reqHeader);

            // Create sections container
            const sectionsDiv = document.createElement('div');
            sectionsDiv.className = 'review-panel-sections';
            panelContent.appendChild(sectionsDiv);

            // Dispatch event for other modules to populate sections
            document.dispatchEvent(new CustomEvent('traceview:review-panel-ready', {
                detail: { reqId, req, sectionsContainer: sectionsDiv }
            }));
        }
    }

    // Register event listener
    document.addEventListener('traceview:req-selected', handleReqSelected);

})(TraceView.review);
