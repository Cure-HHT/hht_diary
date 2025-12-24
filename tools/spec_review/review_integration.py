#!/usr/bin/env python3
"""
Spec Review HTML Integration Module

Integrates review system with the traceability report HTML output.
Provides functions to:
- Generate review-related CSS
- Generate review-related JavaScript
- Load embedded review data for requirements
- Add review panel to requirement display

IMPLEMENTS REQUIREMENTS:
    REQ-d00086: Spec Review Data Model
    REQ-d00091: JavaScript Review Modules
    REQ-d00092: HTML Report Integration
"""

import json
from pathlib import Path
from typing import Dict, List, Any, Optional

from tools.spec_review.review_storage import (
    load_threads,
    load_review_flag,
    load_status_requests,
    load_config,
)
from tools.spec_review.review_data import normalize_req_id


# =============================================================================
# CSS Generation
# =============================================================================

REVIEW_CSS = """
/* ============================================
   Spec Review System Styles
   ============================================ */

/* Review mode toggle */
.review-mode-toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-left: 16px;
}

.review-mode-toggle label {
    font-weight: 500;
    color: var(--text-secondary, #666);
}

.review-mode-toggle input[type="checkbox"] {
    width: 20px;
    height: 20px;
    cursor: pointer;
}

/* Review badge on requirements */
.rs-has-comments {
    border-left: 3px solid var(--primary-color, #0066cc);
}

.rs-req-badges {
    display: inline-flex;
    gap: 4px;
    margin-left: 8px;
}

.rs-badge {
    display: inline-block;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 500;
}

.rs-badge-flagged {
    background: #fff3cd;
    color: #856404;
}

.rs-badge-comments {
    background: #d1ecf1;
    color: #0c5460;
}

.rs-badge-pending {
    background: #f8d7da;
    color: #721c24;
}

.rs-badge-resolved {
    background: #d4edda;
    color: #155724;
}

/* Position highlighting */
.rs-highlight-exact {
    background-color: rgba(255, 235, 59, 0.3);
    border-bottom: 2px solid #ffc107;
}

.rs-highlight-approximate {
    background-color: rgba(255, 193, 7, 0.2);
    border-bottom: 2px dashed #ffc107;
}

.rs-highlight-unanchored {
    background-color: rgba(158, 158, 158, 0.1);
}

.rs-highlight-active {
    background-color: rgba(33, 150, 243, 0.3) !important;
    border-bottom: 2px solid #2196f3 !important;
}

/* Thread list */
.rs-thread-list {
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    margin: 16px 0;
    background: var(--bg-secondary, #f8f9fa);
}

.rs-thread-list-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    border-bottom: 1px solid var(--border-color, #ddd);
    background: var(--bg-tertiary, #e9ecef);
}

.rs-thread-list-header h4 {
    margin: 0;
    font-size: 14px;
}

.rs-thread-list-content {
    padding: 8px;
}

.rs-no-threads {
    color: var(--text-muted, #999);
    text-align: center;
    padding: 16px;
    font-style: italic;
}

/* Thread */
.rs-thread {
    background: var(--bg-primary, #fff);
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    margin-bottom: 8px;
}

.rs-thread-resolved {
    opacity: 0.7;
}

.rs-thread-resolved .rs-thread-header {
    background: #d4edda;
}

.rs-thread-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: var(--bg-secondary, #f8f9fa);
    border-bottom: 1px solid var(--border-color, #eee);
}

.rs-thread-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
}

.rs-author {
    font-weight: 600;
}

.rs-time {
    color: var(--text-muted, #999);
}

.rs-position-indicator {
    font-size: 14px;
}

.rs-thread-actions {
    display: flex;
    gap: 4px;
}

.rs-thread-body {
    padding: 12px;
}

/* Comment */
.rs-comment {
    padding: 8px 0;
    border-bottom: 1px solid var(--border-color, #eee);
}

.rs-comment:last-child {
    border-bottom: none;
}

.rs-comment-header {
    font-size: 12px;
    margin-bottom: 4px;
}

.rs-comment-body {
    font-size: 14px;
    line-height: 1.5;
}

.rs-comment-body code {
    background: var(--bg-code, #f4f4f4);
    padding: 2px 4px;
    border-radius: 2px;
}

/* Reply form */
.rs-reply-form {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--border-color, #eee);
}

.rs-reply-input {
    width: 100%;
    min-height: 60px;
    padding: 8px;
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    font-size: 14px;
    resize: vertical;
}

.rs-reply-actions {
    margin-top: 8px;
    display: flex;
    gap: 8px;
}

/* New comment form */
.rs-new-comment-form {
    background: var(--bg-primary, #fff);
    border: 1px solid var(--primary-color, #0066cc);
    border-radius: 4px;
    padding: 16px;
    margin-bottom: 16px;
}

.rs-new-comment-form h4 {
    margin: 0 0 12px 0;
    color: var(--primary-color, #0066cc);
}

.rs-form-group {
    margin-bottom: 12px;
}

.rs-form-group label {
    display: block;
    font-weight: 500;
    margin-bottom: 4px;
    font-size: 12px;
}

.rs-form-group select,
.rs-form-group input,
.rs-form-group textarea {
    width: 100%;
    padding: 8px;
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    font-size: 14px;
}

.rs-position-options {
    background: var(--bg-secondary, #f8f9fa);
    padding: 12px;
    border-radius: 4px;
    margin: 8px 0;
}

.rs-form-actions {
    display: flex;
    gap: 8px;
    margin-top: 12px;
}

/* Status panel */
.rs-status-panel {
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    margin: 16px 0;
}

.rs-status-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    border-bottom: 1px solid var(--border-color, #ddd);
    background: var(--bg-tertiary, #e9ecef);
}

.rs-status-content {
    padding: 12px;
}

.rs-status-actions {
    padding: 12px;
    border-top: 1px solid var(--border-color, #ddd);
}

/* Request card */
.rs-request-card {
    background: var(--bg-primary, #fff);
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    padding: 12px;
    margin-bottom: 8px;
}

.rs-request-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
}

.rs-request-transition {
    font-weight: 600;
}

.rs-request-state {
    text-transform: uppercase;
    font-size: 10px;
}

.rs-badge-pending { background: #fff3cd; color: #856404; }
.rs-badge-approved { background: #d4edda; color: #155724; }
.rs-badge-rejected { background: #f8d7da; color: #721c24; }
.rs-badge-applied { background: #cce5ff; color: #004085; }

.rs-request-meta {
    font-size: 12px;
    color: var(--text-muted, #666);
    margin-bottom: 8px;
}

.rs-request-justification {
    padding: 8px;
    background: var(--bg-secondary, #f8f9fa);
    border-radius: 4px;
    margin-bottom: 8px;
}

.rs-approval-progress {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
}

.rs-progress-bar {
    flex: 1;
    height: 8px;
    background: var(--bg-tertiary, #e9ecef);
    border-radius: 4px;
    overflow: hidden;
}

.rs-progress-fill {
    height: 100%;
    background: var(--success-color, #28a745);
    transition: width 0.3s;
}

.rs-progress-label {
    font-size: 12px;
    color: var(--text-muted, #666);
}

.rs-approvers {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
}

.rs-approver {
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
}

.rs-approver-pending { background: #f8f9fa; color: #666; }
.rs-approver-approved { background: #d4edda; color: #155724; }
.rs-approver-rejected { background: #f8d7da; color: #721c24; }

.rs-approval-actions {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-top: 8px;
    padding-top: 8px;
    border-top: 1px solid var(--border-color, #eee);
}

.rs-approval-comment {
    flex: 1;
    padding: 4px 8px;
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
}

/* Buttons */
.rs-btn {
    display: inline-block;
    padding: 6px 12px;
    border: 1px solid transparent;
    border-radius: 4px;
    font-size: 13px;
    cursor: pointer;
    background: var(--bg-secondary, #f8f9fa);
    color: var(--text-primary, #333);
}

.rs-btn:hover {
    background: var(--bg-tertiary, #e9ecef);
}

.rs-btn-sm {
    padding: 4px 8px;
    font-size: 11px;
}

.rs-btn-primary {
    background: var(--primary-color, #0066cc);
    color: #fff;
    border-color: var(--primary-color, #0066cc);
}

.rs-btn-primary:hover {
    background: #0052a3;
}

.rs-btn-secondary {
    background: var(--bg-secondary, #6c757d);
    color: #fff;
}

.rs-btn-success {
    background: var(--success-color, #28a745);
    color: #fff;
}

.rs-btn-danger {
    background: var(--danger-color, #dc3545);
    color: #fff;
}

.rs-btn-link {
    background: transparent;
    color: var(--primary-color, #0066cc);
}

/* Sync indicator */
.rs-sync-indicator {
    position: fixed;
    bottom: 16px;
    right: 16px;
    padding: 8px 16px;
    border-radius: 4px;
    background: #333;
    color: #fff;
    font-size: 12px;
    z-index: 1000;
    display: none;
}

.rs-sync-success { background: #28a745; }
.rs-sync-error { background: #dc3545; }

/* Conflict dialog */
.rs-conflict-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
}

.rs-conflict-dialog {
    background: #fff;
    padding: 24px;
    border-radius: 8px;
    max-width: 400px;
    text-align: center;
}

.rs-conflict-options {
    display: flex;
    gap: 8px;
    justify-content: center;
    margin-top: 16px;
}

/* Review panel in side panel */
.review-panel {
    padding: 16px;
}

.review-panel-tabs {
    display: flex;
    border-bottom: 1px solid var(--border-color, #ddd);
    margin-bottom: 16px;
}

.review-panel-tab {
    padding: 8px 16px;
    border: none;
    background: transparent;
    cursor: pointer;
    border-bottom: 2px solid transparent;
}

.review-panel-tab.active {
    border-bottom-color: var(--primary-color, #0066cc);
    font-weight: 600;
}

.review-panel-content {
    min-height: 200px;
}

/* User selector */
.rs-user-selector {
    margin-bottom: 16px;
}

.rs-user-selector label {
    font-size: 12px;
    font-weight: 500;
    margin-right: 8px;
}

.rs-user-selector input {
    padding: 6px 10px;
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    width: 150px;
}
"""


def get_review_css() -> str:
    """Get CSS styles for review system"""
    return REVIEW_CSS


# =============================================================================
# JavaScript Generation
# =============================================================================

def get_review_js_files() -> List[Path]:
    """Get list of review JavaScript files to include"""
    js_dir = Path(__file__).parent / 'js'
    return [
        js_dir / 'review-data.js',
        js_dir / 'review-position.js',
        js_dir / 'review-comments.js',
        js_dir / 'review-status.js',
        js_dir / 'review-sync.js',
    ]


def get_review_js_content() -> str:
    """Get concatenated content of all review JavaScript files"""
    content_parts = []
    for js_file in get_review_js_files():
        if js_file.exists():
            content_parts.append(f"// ===== {js_file.name} =====")
            content_parts.append(js_file.read_text())
            content_parts.append("")
    return "\n".join(content_parts)


def get_review_init_js(current_user: str = "anonymous") -> str:
    """Get JavaScript to initialize review system"""
    return f"""
// Initialize Review System
document.addEventListener('DOMContentLoaded', function() {{
    // Set current user
    ReviewSystem.state.currentUser = '{current_user}';

    // Load embedded review data if available
    if (window.REVIEW_DATA) {{
        ReviewSystem.state.loadFromEmbedded(window.REVIEW_DATA);
    }}

    // Initialize sync if config allows
    if (ReviewSystem.state.config.autoFetchOnOpen) {{
        // Don't auto-fetch in static mode - data is embedded
        console.log('Review system initialized with embedded data');
    }}

    // Add review badges to requirements
    updateReviewBadges();

    // Listen for review mode toggle
    const reviewToggle = document.getElementById('review-mode-toggle');
    if (reviewToggle) {{
        reviewToggle.addEventListener('change', function() {{
            document.body.classList.toggle('review-mode-active', this.checked);
            if (this.checked) {{
                showReviewPanel();
            }} else {{
                hideReviewPanel();
            }}
        }});
    }}
}});

function updateReviewBadges() {{
    // Add badges to each requirement in the grid
    document.querySelectorAll('[data-req-id]').forEach(function(el) {{
        const reqId = el.getAttribute('data-req-id');
        if (!reqId) return;

        const badges = [];
        const flag = ReviewSystem.state.getFlag(reqId);
        if (flag && flag.flaggedForReview) {{
            badges.push('<span class="rs-badge rs-badge-flagged">Review</span>');
        }}

        const counts = ReviewSystem.getCommentCount(reqId);
        if (counts.total > 0) {{
            badges.push('<span class="rs-badge rs-badge-comments">' + counts.total + ' comments</span>');
        }}

        const pendingRequests = ReviewSystem.getPendingRequestCount(reqId);
        if (pendingRequests > 0) {{
            badges.push('<span class="rs-badge rs-badge-pending">' + pendingRequests + ' pending</span>');
        }}

        if (badges.length > 0) {{
            el.classList.add('rs-has-comments');
            const badgeContainer = document.createElement('span');
            badgeContainer.className = 'rs-req-badges';
            badgeContainer.innerHTML = badges.join('');
            const titleEl = el.querySelector('.req-title, .req-id');
            if (titleEl) {{
                titleEl.appendChild(badgeContainer);
            }}
        }}
    }});
}}

function showReviewPanel() {{
    const sidePanel = document.querySelector('.side-panel, #side-panel');
    if (sidePanel) {{
        const existingPanel = sidePanel.querySelector('.review-panel');
        if (!existingPanel) {{
            const panel = document.createElement('div');
            panel.className = 'review-panel';
            panel.innerHTML = `
                <div class="review-panel-tabs">
                    <button class="review-panel-tab active" data-tab="comments">Comments</button>
                    <button class="review-panel-tab" data-tab="status">Status</button>
                </div>
                <div class="rs-user-selector">
                    <label>Your name:</label>
                    <input type="text" id="rs-current-user" value="${{ReviewSystem.state.currentUser}}"
                           onchange="ReviewSystem.state.currentUser = this.value">
                </div>
                <div class="review-panel-content" id="review-panel-content"></div>
            `;
            sidePanel.appendChild(panel);

            // Tab click handlers
            panel.querySelectorAll('.review-panel-tab').forEach(function(tab) {{
                tab.addEventListener('click', function() {{
                    panel.querySelectorAll('.review-panel-tab').forEach(t => t.classList.remove('active'));
                    this.classList.add('active');
                    updateReviewPanelContent(this.getAttribute('data-tab'));
                }});
            }});
        }}
    }}
}}

function hideReviewPanel() {{
    const panel = document.querySelector('.review-panel');
    if (panel) {{
        panel.remove();
    }}
}}

function updateReviewPanelContent(tab) {{
    const content = document.getElementById('review-panel-content');
    const selectedReq = document.querySelector('[data-req-id].selected, .req-selected');
    const reqId = selectedReq ? selectedReq.getAttribute('data-req-id') : null;

    if (!reqId) {{
        content.innerHTML = '<p class="rs-no-threads">Select a requirement to view comments.</p>';
        return;
    }}

    if (tab === 'comments') {{
        ReviewSystem.renderThreadList(content, reqId);
    }} else if (tab === 'status') {{
        // Get current status from the selected REQ
        const statusEl = selectedReq.querySelector('.req-status, [data-status]');
        const currentStatus = statusEl ? (statusEl.getAttribute('data-status') || statusEl.textContent.trim()) : 'Draft';
        ReviewSystem.renderStatusPanel(content, reqId, currentStatus);
    }}
}}
"""


# =============================================================================
# Data Loading
# =============================================================================

def load_review_data_for_reqs(repo_root: Path, req_ids: List[str]) -> Dict[str, Any]:
    """
    Load all review data for a list of requirements.

    Args:
        repo_root: Repository root path
        req_ids: List of requirement IDs

    Returns:
        Dictionary with threads, flags, requests, sessions, config
    """
    result = {
        'threads': {},
        'flags': {},
        'requests': {},
        'config': load_config(repo_root).to_dict()
    }

    for req_id in req_ids:
        normalized_id = normalize_req_id(req_id)

        # Load threads
        threads_file = load_threads(repo_root, req_id)
        if threads_file.threads:
            result['threads'][normalized_id] = [t.to_dict() for t in threads_file.threads]

        # Load flags
        flag = load_review_flag(repo_root, req_id)
        if flag.flaggedForReview:
            result['flags'][normalized_id] = flag.to_dict()

        # Load status requests
        status_file = load_status_requests(repo_root, req_id)
        if status_file.requests:
            result['requests'][normalized_id] = [r.to_dict() for r in status_file.requests]

    return result


def _escape_for_js_embedding(json_str: str) -> str:
    """
    Escape JSON string for safe embedding in <script> tags.

    JSON is valid JavaScript, but some characters that are valid in JSON
    can break when embedded in HTML <script> tags:
    - U+2028 (Line Separator) and U+2029 (Paragraph Separator)
    - </script> sequences
    - Control characters (0x00-0x1F)
    """
    # Escape line/paragraph separators (valid in JSON, breaks JS in HTML)
    json_str = json_str.replace('\u2028', '\\u2028')
    json_str = json_str.replace('\u2029', '\\u2029')

    # Escape </script> to prevent premature tag closure
    json_str = json_str.replace('</script>', '<\\/script>')
    json_str = json_str.replace('</SCRIPT>', '<\\/SCRIPT>')

    return json_str


def generate_embedded_review_data(repo_root: Path, req_ids: List[str]) -> str:
    """
    Generate JavaScript code to embed review data.

    Args:
        repo_root: Repository root path
        req_ids: List of requirement IDs

    Returns:
        JavaScript code defining window.REVIEW_DATA
    """
    data = load_review_data_for_reqs(repo_root, req_ids)
    # Use ensure_ascii=True to escape all non-ASCII chars as \uXXXX
    json_str = json.dumps(data, indent=2, ensure_ascii=True)
    json_str = _escape_for_js_embedding(json_str)
    return f"window.REVIEW_DATA = {json_str};"


# =============================================================================
# HTML Integration
# =============================================================================

def get_review_mode_toggle_html() -> str:
    """Get HTML for review mode toggle button"""
    return """
    <div class="review-mode-toggle">
        <label for="review-mode-toggle">Review Mode</label>
        <input type="checkbox" id="review-mode-toggle">
    </div>
    """


def get_review_filter_html() -> str:
    """Get HTML for review filter options"""
    return """
    <div class="review-filters" style="display: none;" id="review-filters">
        <label>
            <input type="checkbox" id="filter-flagged"> Flagged for review
        </label>
        <label>
            <input type="checkbox" id="filter-with-comments"> Has comments
        </label>
        <label>
            <input type="checkbox" id="filter-pending"> Pending status change
        </label>
    </div>
    """
