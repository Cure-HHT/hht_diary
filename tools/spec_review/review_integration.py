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

/* Quick actions for status toggle */
.rs-quick-actions {
    padding: 12px;
    background: var(--bg-secondary, #f8f9fa);
    border-bottom: 1px solid var(--border-color, #ddd);
    display: flex;
    gap: 8px;
}

.rs-quick-toggle {
    flex: 1;
}

/* Clickable status badges in review mode */
body.review-mode-active .status-badge.status-draft {
    cursor: pointer;
    transition: opacity 0.2s;
}

body.review-mode-active .status-badge.status-draft:hover {
    opacity: 0.8;
    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
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

/* Review panel - now in dedicated third column */
.review-panel {
    padding: 16px;
    height: 100%;
    display: flex;
    flex-direction: column;
}

.review-panel-header {
    padding: 15px 16px;
    margin: -16px -16px 16px -16px;
    background: #f8f9fa;
    border-bottom: 1px solid #dee2e6;
    font-weight: 600;
    font-size: 14px;
}

.review-panel-title {
    color: #2c3e50;
}

.review-panel-req-header {
    background: var(--primary-color, #0066cc);
    color: #fff;
    padding: 10px 12px;
    margin: 0 -16px 16px -16px;
    font-size: 14px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 8px;
}

.review-panel-req-header .req-id-badge {
    background: rgba(255,255,255,0.2);
    padding: 4px 8px;
    border-radius: 4px;
    font-family: monospace;
}

.review-panel-req-header .req-title-text {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-weight: 400;
    opacity: 0.9;
}

.review-panel-no-selection {
    text-align: center;
    padding: 40px 20px;
    color: var(--text-muted, #666);
}

.review-panel-no-selection .icon {
    font-size: 48px;
    margin-bottom: 16px;
    opacity: 0.5;
}

.review-panel-no-selection p {
    margin: 0 0 8px 0;
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
    flex: 1;
    overflow-y: auto;
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

/* Line numbers for requirement body - table layout for proper alignment */
.rs-line-numbers-container {
    font-family: monospace;
    font-size: 12px;
    line-height: 1.6;
    margin: 8px 0;
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    background: var(--bg-primary, #fff);
    max-height: 350px;
    overflow-y: auto;
    overflow-x: hidden;
}

/* Use table layout for perfect line number alignment with wrapped text */
.rs-lines-table {
    display: table;
    width: 100%;
    border-collapse: collapse;
}

.rs-line-row {
    display: table-row;
}

.rs-line-row:hover {
    background: rgba(0, 102, 204, 0.05);
}

.rs-line-row.selected {
    background: rgba(255, 235, 59, 0.3);
}

.rs-line-number {
    display: table-cell;
    padding: 2px 8px 2px 6px;
    text-align: right;
    color: var(--text-muted, #999);
    background: var(--bg-tertiary, #e9ecef);
    border-right: 1px solid var(--border-color, #ddd);
    user-select: none;
    vertical-align: top;  /* Align to top of wrapped content */
    min-width: 28px;
    width: 28px;
    cursor: pointer;
    font-size: 11px;
}

.rs-line-number:hover {
    background: rgba(0, 102, 204, 0.15);
    color: var(--primary-color, #0066cc);
}

.rs-line-row.selected .rs-line-number {
    background: rgba(0, 102, 204, 0.2);
    color: var(--primary-color, #0066cc);
    font-weight: 600;
}

.rs-line-text {
    display: table-cell;
    padding: 2px 10px;
    vertical-align: top;
    word-break: break-word;
    white-space: pre-wrap;
    cursor: text;  /* Indicate text is selectable */
}

.review-mode-active .rs-line-row {
    cursor: crosshair;  /* Indicate drag selection is available */
}

.review-mode-active .rs-line-row:active {
    cursor: grabbing;
}

/* Empty line placeholder */
.rs-line-text:empty::before {
    content: " ";
    white-space: pre;
}

/* Selected position indicator */
.rs-selected-position {
    background: var(--bg-secondary, #f8f9fa);
    border: 1px solid var(--border-color, #ddd);
    border-radius: 4px;
    padding: 8px 12px;
    margin-bottom: 12px;
    font-size: 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.rs-selected-position .label {
    color: var(--text-muted, #666);
}

.rs-selected-position .value {
    font-weight: 600;
    color: var(--primary-color, #0066cc);
}

.rs-selected-position .clear-btn {
    background: none;
    border: none;
    color: var(--text-muted, #999);
    cursor: pointer;
    font-size: 16px;
}

.rs-selected-position .clear-btn:hover {
    color: var(--danger-color, #dc3545);
}

/* Line numbers in REQ card body (integrated view) */
.review-mode-active .req-card-content.rs-with-line-numbers {
    padding: 0;
}

.review-mode-active .req-card-content.rs-with-line-numbers .rs-lines-table {
    margin: 0;
    border: none;
    border-radius: 0;
    max-height: none;
}

.review-mode-active .rs-line-numbers-hint {
    font-size: 11px;
    color: var(--text-muted, #888);
    padding: 4px 8px;
    background: var(--bg-tertiary, #e9ecef);
    border-bottom: 1px solid var(--border-color, #ddd);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.review-mode-active .rs-line-numbers-hint .hint-text {
    font-style: italic;
}

.review-mode-active .rs-line-numbers-hint .selected-lines {
    font-weight: 600;
    color: var(--primary-color, #0066cc);
}

/* ============================================
   Review Packages Panel
   ============================================ */

.review-packages-panel {
    background: var(--bg-primary, #fff);
    border: 1px solid var(--border-color, #ddd);
    border-radius: 8px;
    margin-bottom: 16px;
    display: none;  /* Hidden until review mode is active */
}

body.review-mode-active .review-packages-panel {
    display: block;
}

.review-packages-panel.collapsed .packages-content {
    display: none;
}

.packages-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    background: var(--bg-tertiary, #e9ecef);
    border-radius: 8px 8px 0 0;
    cursor: pointer;
    user-select: none;
}

.review-packages-panel.collapsed .packages-header {
    border-radius: 8px;
}

.packages-header .collapse-icon {
    font-size: 12px;
    color: var(--text-muted, #666);
    transition: transform 0.2s;
}

.packages-header h3 {
    margin: 0;
    font-size: 14px;
    flex: 1;
}

.packages-header .create-btn {
    padding: 4px 12px;
    font-size: 12px;
}

.packages-content {
    padding: 12px;
}

.package-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.package-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    border-radius: 4px;
    cursor: pointer;
    background: var(--bg-secondary, #f8f9fa);
    transition: background 0.2s;
}

.package-item:hover {
    background: var(--bg-tertiary, #e9ecef);
}

.package-item.active {
    background: rgba(0, 102, 204, 0.1);
    border: 1px solid var(--primary-color, #0066cc);
}

.package-item.default {
    font-style: italic;
}

.package-item input[type="radio"] {
    margin: 0;
    flex-shrink: 0;
}

.package-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
}

.package-name {
    font-weight: 500;
    font-size: 13px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.package-desc {
    font-size: 11px;
    color: var(--text-muted, #666);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.package-count {
    background: var(--bg-tertiary, #e9ecef);
    color: var(--text-secondary, #666);
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    flex-shrink: 0;
}

.package-count::after {
    content: " REQs";
}

.package-actions {
    display: flex;
    gap: 4px;
    opacity: 0;
    transition: opacity 0.2s;
}

.package-item:hover .package-actions {
    opacity: 1;
}

#packageFilterIndicator {
    display: none;
    margin-left: 8px;
    padding: 4px 8px;
    background: rgba(0, 102, 204, 0.1);
    border-radius: 4px;
    font-size: 12px;
    color: var(--primary-color, #0066cc);
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
        js_dir / 'review-packages.js',
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
var currentReviewReqId = null;

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

    // Hook into the existing openReqPanel function to track selected requirement
    if (typeof window.openReqPanel === 'function') {{
        const originalOpenReqPanel = window.openReqPanel;
        window.openReqPanel = function(reqId) {{
            currentReviewReqId = reqId;
            originalOpenReqPanel(reqId);

            // If review mode is active, add line numbers to REQ body and update panel
            const reviewToggle = document.getElementById('review-mode-toggle');
            if (reviewToggle && reviewToggle.checked) {{
                addLineNumbersToReqCard(reqId);
                updateReviewPanelContent('comments');
            }}
        }};
    }}

    // Listen for review mode toggle
    const reviewToggle = document.getElementById('review-mode-toggle');
    if (reviewToggle) {{
        reviewToggle.addEventListener('change', function() {{
            document.body.classList.toggle('review-mode-active', this.checked);
            if (this.checked) {{
                showReviewPanel();
                // Initialize packages panel
                if (typeof ReviewSystem.initPackagesPanel === 'function') {{
                    ReviewSystem.initPackagesPanel();
                }}
                // Add line numbers to current REQ card if one is open
                if (currentReviewReqId) {{
                    addLineNumbersToReqCard(currentReviewReqId);
                    updateReviewPanelContent('comments');
                }}
            }} else {{
                hideReviewPanel();
                // Remove line numbers from cards when review mode is disabled
                removeLineNumbersFromCards();
            }}
        }});

        // If review mode is already checked on page load (e.g., when served by serve_review.sh),
        // initialize review mode immediately
        if (reviewToggle.checked) {{
            document.body.classList.add('review-mode-active');
            showReviewPanel();
            // Initialize packages panel
            if (typeof ReviewSystem.initPackagesPanel === 'function') {{
                ReviewSystem.initPackagesPanel();
            }}
        }}
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

    // Make Draft status badges clickable in review mode
    bindStatusBadgeClicks();
}}

function bindStatusBadgeClicks() {{
    // Bind click handlers to Draft status badges
    document.querySelectorAll('.status-badge.status-draft').forEach(function(badge) {{
        // Skip if already bound
        if (badge.hasAttribute('data-status-click-bound')) return;
        badge.setAttribute('data-status-click-bound', 'true');

        badge.addEventListener('click', async function(e) {{
            // Only handle in review mode
            const reviewToggle = document.getElementById('review-mode-toggle');
            if (!reviewToggle || !reviewToggle.checked) return;

            e.stopPropagation(); // Don't trigger row click

            // Find the REQ ID from the parent row or card
            const reqRow = badge.closest('[data-req-id]');
            const reqCard = badge.closest('.req-card');
            let reqId = null;

            if (reqRow) {{
                reqId = reqRow.getAttribute('data-req-id');
            }} else if (reqCard) {{
                // Extract from card ID like "req-card-d00001"
                const cardId = reqCard.id;
                if (cardId && cardId.startsWith('req-card-')) {{
                    reqId = cardId.replace('req-card-', '');
                }}
            }}

            if (!reqId) return;

            // Show loading state
            const originalText = badge.textContent;
            badge.textContent = '...';
            badge.style.pointerEvents = 'none';

            // Toggle to Review
            const result = await ReviewSystem.toggleToReview(reqId);
            if (result.success) {{
                badge.textContent = 'Review';
                badge.className = 'status-badge status-review';
            }} else {{
                badge.textContent = originalText;
                console.error('Failed to change status:', result.error);
            }}
            badge.style.pointerEvents = '';
        }});
    }});
}}

function showReviewPanel() {{
    // Use the dedicated review column (third column) instead of side panel
    const reviewColumn = document.getElementById('review-column');
    if (reviewColumn) {{
        // Show the review column
        reviewColumn.classList.remove('hidden');

        const existingPanel = reviewColumn.querySelector('.review-panel');
        if (!existingPanel) {{
            const panel = document.createElement('div');
            panel.className = 'review-panel';
            panel.innerHTML = `
                <div class="review-panel-header">
                    <span class="review-panel-title">Comments & Status</span>
                </div>
                <div class="review-panel-req-header" id="review-req-header" style="display: none;">
                    <span class="req-id-badge" id="review-req-id"></span>
                    <span class="req-title-text" id="review-req-title"></span>
                </div>
                <div class="review-panel-tabs">
                    <button class="review-panel-tab active" data-tab="comments">Comments</button>
                    <button class="review-panel-tab" data-tab="status">Status</button>
                </div>
                <div class="rs-user-selector">
                    <label>Your name:</label>
                    <input type="text" id="rs-current-user" value="${{ReviewSystem.state.currentUser}}"
                           onchange="ReviewSystem.state.currentUser = this.value">
                </div>
                <div class="review-panel-content" id="review-panel-content">
                    <div class="review-panel-no-selection">
                        <div class="icon">&#128196;</div>
                        <p><strong>No requirement selected</strong></p>
                        <p>Click a REQ ID in the grid to view and add comments.</p>
                    </div>
                </div>
            `;
            reviewColumn.appendChild(panel);

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
    // Hide the review column
    const reviewColumn = document.getElementById('review-column');
    if (reviewColumn) {{
        reviewColumn.classList.add('hidden');
        const panel = reviewColumn.querySelector('.review-panel');
        if (panel) {{
            panel.remove();
        }}
    }}
}}

// Track selected line for comments
var selectedLineNumber = null;
var selectedLineRange = null;

function updateReviewPanelContent(tab) {{
    const content = document.getElementById('review-panel-content');
    const reqHeader = document.getElementById('review-req-header');
    const reqIdEl = document.getElementById('review-req-id');
    const reqTitleEl = document.getElementById('review-req-title');
    const reqId = currentReviewReqId;

    if (!reqId) {{
        // Hide header, show no-selection message
        if (reqHeader) reqHeader.style.display = 'none';
        content.innerHTML = `
            <div class="review-panel-no-selection">
                <div class="icon">&#128196;</div>
                <p><strong>No requirement selected</strong></p>
                <p>Click a REQ ID in the grid to view and add comments.</p>
            </div>
        `;
        return;
    }}

    // Show header with REQ info
    const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
    if (reqHeader) {{
        reqHeader.style.display = 'flex';
        if (reqIdEl) reqIdEl.textContent = 'REQ-' + reqId;
        if (reqTitleEl) reqTitleEl.textContent = reqData ? reqData.title : '';
    }}

    if (tab === 'comments') {{
        ReviewSystem.renderThreadList(content, reqId);
        // Line numbers are now shown in the main REQ card - no separate body section needed
    }} else if (tab === 'status') {{
        const currentStatus = reqData ? reqData.status : 'Draft';
        ReviewSystem.renderStatusPanel(content, reqId, currentStatus);
    }}
}}

function addLineNumberedView(container, body, reqId) {{
    // Create line-numbered view using table layout for proper alignment
    const lines = body.split('\\n');

    // Build table rows - each row has line number cell and content cell
    const tableRowsHtml = lines.map((line, i) => {{
        const lineNum = i + 1;
        const escapedContent = escapeHtmlContent(line);
        return `<div class="rs-line-row" data-line="${{lineNum}}">
            <span class="rs-line-number" data-line="${{lineNum}}">${{lineNum}}</span>
            <span class="rs-line-text">${{escapedContent || ''}}</span>
        </div>`;
    }}).join('');

    const viewHtml = `
        <div class="rs-req-body-section" style="margin-top: 16px; border-top: 1px solid #ddd; padding-top: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                <h5 style="margin: 0; font-size: 12px; color: #666;">Requirement Body (click line # to select)</h5>
            </div>
            <div class="rs-selected-position" id="rs-selected-position" style="display: none;">
                <span><span class="label">Selected: </span><span class="value" id="rs-position-value"></span></span>
                <button class="clear-btn" onclick="clearLineSelection()" title="Clear selection">&times;</button>
            </div>
            <div class="rs-line-numbers-container">
                <div class="rs-lines-table">${{tableRowsHtml}}</div>
            </div>
        </div>
    `;

    container.insertAdjacentHTML('beforeend', viewHtml);

    // Bind click handlers for line number selection
    const lineNumbers = container.querySelectorAll('.rs-line-number');
    lineNumbers.forEach(ln => {{
        ln.addEventListener('click', (e) => {{
            e.stopPropagation();  // Prevent row click from also firing
            handleLineClick(e, ln, container);
        }});
    }});

    // Bind row clicks (clicking on the text content)
    const lineRows = container.querySelectorAll('.rs-line-row');
    lineRows.forEach(row => {{
        row.addEventListener('click', (e) => {{
            const lineNum = parseInt(row.getAttribute('data-line'), 10);
            selectLine(lineNum, container, e.shiftKey);
        }});
    }});
}}

function handleLineClick(e, lineEl, container) {{
    const lineNum = parseInt(lineEl.getAttribute('data-line'), 10);
    selectLine(lineNum, container, e.shiftKey);
}}

function selectLine(lineNum, container, isShift) {{
    if (isShift && selectedLineNumber) {{
        // Range selection
        const start = Math.min(selectedLineNumber, lineNum);
        const end = Math.max(selectedLineNumber, lineNum);
        selectedLineRange = [start, end];
        selectedLineNumber = start;
        updateLineSelectionUI(container, start, end);
    }} else {{
        // Single line selection
        selectedLineNumber = lineNum;
        selectedLineRange = null;
        updateLineSelectionUI(container, lineNum, lineNum);
    }}

    // Update the comment form if it exists
    updateCommentFormWithSelection();
}}

function updateLineSelectionUI(container, startLine, endLine) {{
    // Clear previous selection - only need to clear rows since number styling comes from parent
    container.querySelectorAll('.rs-line-row.selected').forEach(el => {{
        el.classList.remove('selected');
    }});

    // Add selection to line rows in range
    for (let i = startLine; i <= endLine; i++) {{
        const lineRow = container.querySelector(`.rs-line-row[data-line="${{i}}"]`);
        if (lineRow) lineRow.classList.add('selected');
    }}

    // Update position indicator
    const positionEl = document.getElementById('rs-selected-position');
    const positionValue = document.getElementById('rs-position-value');
    if (positionEl && positionValue) {{
        positionEl.style.display = 'flex';
        if (startLine === endLine) {{
            positionValue.textContent = `Line ${{startLine}}`;
        }} else {{
            positionValue.textContent = `Lines ${{startLine}}-${{endLine}}`;
        }}
    }}
}}

function clearLineSelection() {{
    selectedLineNumber = null;
    selectedLineRange = null;

    // Clear UI - only rows have selection class in new table structure
    document.querySelectorAll('.rs-line-row.selected').forEach(el => {{
        el.classList.remove('selected');
    }});

    const positionEl = document.getElementById('rs-selected-position');
    if (positionEl) positionEl.style.display = 'none';

    // Reset comment form
    updateCommentFormWithSelection();
}}

function updateCommentFormWithSelection() {{
    // If new comment form exists, update position fields
    const posType = document.querySelector('.rs-position-type');
    if (!posType) return;

    if (selectedLineRange) {{
        posType.value = 'block';
        posType.dispatchEvent(new Event('change'));
        const startInput = document.querySelector('.rs-block-start');
        const endInput = document.querySelector('.rs-block-end');
        if (startInput) startInput.value = selectedLineRange[0];
        if (endInput) endInput.value = selectedLineRange[1];
    }} else if (selectedLineNumber) {{
        posType.value = 'line';
        posType.dispatchEvent(new Event('change'));
        const lineNumberInput = document.querySelector('.rs-line-input');
        if (lineNumberInput) lineNumberInput.value = selectedLineNumber;
    }}
}}

function escapeHtmlContent(text) {{
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}}

// Add line numbers to the REQ card body in the side panel
function addLineNumbersToReqCard(reqId) {{
    // Find the current REQ card
    const card = document.getElementById(`req-card-${{reqId}}`);
    if (!card) return;

    const contentDiv = card.querySelector('.req-card-content');
    if (!contentDiv || contentDiv.classList.contains('rs-with-line-numbers')) return;

    // Get the raw body text from REQ_CONTENT_DATA
    const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
    if (!reqData || !reqData.body) return;

    const body = reqData.body;
    const lines = body.split('\\n');

    // Build table rows
    const tableRowsHtml = lines.map((line, i) => {{
        const lineNum = i + 1;
        const escapedContent = escapeHtmlContent(line);
        return `<div class="rs-line-row" data-line="${{lineNum}}">
            <span class="rs-line-number" data-line="${{lineNum}}">${{lineNum}}</span>
            <span class="rs-line-text">${{escapedContent || ''}}</span>
        </div>`;
    }}).join('');

    // Create the line-numbered view
    const lineNumberedHtml = `
        <div class="rs-line-numbers-hint">
            <span class="hint-text">Click line # or drag to select range</span>
            <span class="selected-lines" id="rs-card-selected-lines"></span>
        </div>
        <div class="rs-line-numbers-container">
            <div class="rs-lines-table">${{tableRowsHtml}}</div>
        </div>
    `;

    // Replace the content
    contentDiv.classList.add('rs-with-line-numbers');
    contentDiv.innerHTML = lineNumberedHtml;

    // Bind click handlers
    bindCardLineNumberHandlers(contentDiv);
}}

// Track drag selection state
var isDragging = false;
var dragStartLine = null;

function bindCardLineNumberHandlers(container) {{
    // Bind click handlers for line number selection
    const lineNumbers = container.querySelectorAll('.rs-line-number');
    lineNumbers.forEach(ln => {{
        ln.addEventListener('click', (e) => {{
            e.stopPropagation();
            const lineNum = parseInt(ln.getAttribute('data-line'), 10);
            selectLineInCard(lineNum, container, e.shiftKey);
        }});
    }});

    // Bind row events for click and drag selection
    const lineRows = container.querySelectorAll('.rs-line-row');
    lineRows.forEach(row => {{
        // Click to select single line (or shift-click for range)
        row.addEventListener('click', (e) => {{
            if (isDragging) return;  // Don't fire click after drag
            const lineNum = parseInt(row.getAttribute('data-line'), 10);
            selectLineInCard(lineNum, container, e.shiftKey);
        }});

        // Drag to select range
        row.addEventListener('mousedown', (e) => {{
            // Only start drag on left mouse button
            if (e.button !== 0) return;
            const lineNum = parseInt(row.getAttribute('data-line'), 10);
            isDragging = true;
            dragStartLine = lineNum;
            selectedLineNumber = lineNum;
            selectedLineRange = null;
            updateCardLineSelectionUI(container, lineNum, lineNum);
            e.preventDefault();  // Prevent text selection
        }});

        row.addEventListener('mousemove', (e) => {{
            if (!isDragging || dragStartLine === null) return;
            const lineNum = parseInt(row.getAttribute('data-line'), 10);
            const start = Math.min(dragStartLine, lineNum);
            const end = Math.max(dragStartLine, lineNum);
            selectedLineNumber = start;
            selectedLineRange = start !== end ? [start, end] : null;
            updateCardLineSelectionUI(container, start, end);
        }});

        row.addEventListener('mouseup', (e) => {{
            if (isDragging) {{
                isDragging = false;
                updateCommentFormWithSelection();
            }}
        }});
    }});

    // Handle mouseup outside the container
    document.addEventListener('mouseup', () => {{
        if (isDragging) {{
            isDragging = false;
            updateCommentFormWithSelection();
        }}
    }});
}}

function selectLineInCard(lineNum, container, isShift) {{
    if (isShift && selectedLineNumber) {{
        // Range selection
        const start = Math.min(selectedLineNumber, lineNum);
        const end = Math.max(selectedLineNumber, lineNum);
        selectedLineRange = [start, end];
        selectedLineNumber = start;
        updateCardLineSelectionUI(container, start, end);
    }} else {{
        // Single line selection
        selectedLineNumber = lineNum;
        selectedLineRange = null;
        updateCardLineSelectionUI(container, lineNum, lineNum);
    }}

    // Update comment form if open
    updateCommentFormWithSelection();
}}

function updateCardLineSelectionUI(container, startLine, endLine) {{
    // Clear previous selection
    container.querySelectorAll('.rs-line-row.selected').forEach(el => {{
        el.classList.remove('selected');
    }});

    // Add selection to line rows in range
    for (let i = startLine; i <= endLine; i++) {{
        const lineRow = container.querySelector(`.rs-line-row[data-line="${{i}}"]`);
        if (lineRow) lineRow.classList.add('selected');
    }}

    // Update hint display
    const selectedLinesEl = document.getElementById('rs-card-selected-lines');
    if (selectedLinesEl) {{
        if (startLine === endLine) {{
            selectedLinesEl.textContent = `Line ${{startLine}} selected`;
        }} else {{
            selectedLinesEl.textContent = `Lines ${{startLine}}-${{endLine}} selected`;
        }}
    }}
}}

// Remove line numbers and restore original markdown rendering
function removeLineNumbersFromCards() {{
    document.querySelectorAll('.req-card-content.rs-with-line-numbers').forEach(contentDiv => {{
        const card = contentDiv.closest('.req-card');
        if (!card) return;

        // Get the reqId from the card
        const cardId = card.id;  // e.g., "req-card-p00001"
        const reqId = cardId.replace('req-card-', '');

        // Get the original content from REQ_CONTENT_DATA
        const reqData = window.REQ_CONTENT_DATA && window.REQ_CONTENT_DATA[reqId];
        if (!reqData) return;

        // Re-render with markdown
        const bodyHtml = window.marked ? marked.parse(reqData.body) : reqData.body;
        const rationaleHtml = reqData.rationale ? (window.marked ? marked.parse(reqData.rationale) : reqData.rationale) : '';

        contentDiv.classList.remove('rs-with-line-numbers');
        contentDiv.innerHTML = `
            <div class="req-body">${{bodyHtml}}</div>
            ${{rationaleHtml ? `<div class="req-rationale"><strong>Rationale:</strong> ${{rationaleHtml}}</div>` : ''}}
        `;
    }});

    // Clear selection state
    selectedLineNumber = null;
    selectedLineRange = null;
}}
"""


# =============================================================================
# Data Loading
# =============================================================================

def load_review_data_for_reqs(
    repo_root: Path,
    req_ids: List[str],
    static_mode: bool = True
) -> Dict[str, Any]:
    """
    Load all review data for a list of requirements.

    Args:
        repo_root: Repository root path
        req_ids: List of requirement IDs
        static_mode: If True, disable push features (for static HTTP server)

    Returns:
        Dictionary with threads, flags, requests, sessions, config
    """
    config_dict = load_config(repo_root).to_dict()

    # In static mode, disable push features since there's no API server
    if static_mode:
        config_dict['pushOnComment'] = False
        config_dict['autoFetchOnOpen'] = False

    result = {
        'threads': {},
        'flags': {},
        'requests': {},
        'config': config_dict
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


def generate_embedded_review_data(
    repo_root: Path,
    req_ids: List[str],
    static_mode: bool = True
) -> str:
    """
    Generate JavaScript code to embed review data.

    Args:
        repo_root: Repository root path
        req_ids: List of requirement IDs
        static_mode: If True, disable push features (for static HTTP server)

    Returns:
        JavaScript code defining window.REVIEW_DATA
    """
    data = load_review_data_for_reqs(repo_root, req_ids, static_mode=static_mode)
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


def get_packages_panel_html() -> str:
    """Get HTML for review packages panel (collapsible, above tree)"""
    return """
    <div class="review-packages-panel" id="reviewPackagesPanel">
        <div class="packages-header" onclick="ReviewSystem.togglePackagesPanel()">
            <span class="collapse-icon">&#9660;</span>
            <h3>Review Packages</h3>
            <button class="rs-btn rs-btn-sm rs-btn-primary create-btn"
                    onclick="ReviewSystem.showCreatePackageDialog(event)">
                + New Package
            </button>
            <span id="packageFilterIndicator"></span>
        </div>
        <div class="packages-content">
            <div class="package-list">
                <p style="color: #666; text-align: center; padding: 16px;">
                    Loading packages...
                </p>
            </div>
        </div>
    </div>
    """
