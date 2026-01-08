/**
 * TraceView Review Help System
 *
 * Provides:
 * - Contextual tooltips loaded from tooltips.json
 * - Onboarding wizard loaded from onboarding.json
 * - Help panel loaded from help-panel.json
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-tv-d00016: Review JavaScript Integration
 */

// Ensure TraceView.review namespace exists
window.TraceView = window.TraceView || {};
TraceView.review = TraceView.review || {};

(function(review) {
    'use strict';

    // Help data loaded from JSON files
    let tooltipsData = null;
    let onboardingData = null;
    let helpPanelData = null;

    // State
    let onboardingStep = 0;
    let helpPanelVisible = false;

    // ==========================================================================
    // Data Loading
    // ==========================================================================

    /**
     * Load help data from JSON files
     * @param {string} baseUrl - Base URL for help files
     */
    async function loadHelpData(baseUrl = '/help') {
        try {
            const [tooltipsResp, onboardingResp, helpPanelResp] = await Promise.all([
                fetch(`${baseUrl}/tooltips.json`),
                fetch(`${baseUrl}/onboarding.json`),
                fetch(`${baseUrl}/help-panel.json`)
            ]);

            if (tooltipsResp.ok) {
                tooltipsData = await tooltipsResp.json();
            }
            if (onboardingResp.ok) {
                onboardingData = await onboardingResp.json();
            }
            if (helpPanelResp.ok) {
                helpPanelData = await helpPanelResp.json();
            }

            console.log('Help data loaded successfully');
        } catch (e) {
            console.warn('Failed to load help data:', e);
        }
    }

    // ==========================================================================
    // Tooltips
    // ==========================================================================

    /**
     * Get tooltip content for an element
     * @param {string} helpId - Help ID (e.g., "header.review-mode-toggle")
     * @returns {object|null} Tooltip data with title and text
     */
    function getTooltip(helpId) {
        if (!tooltipsData?.tooltips) return null;

        const parts = helpId.split('.');
        if (parts.length !== 2) return null;

        const [section, id] = parts;
        return tooltipsData.tooltips[section]?.[id] || null;
    }

    /**
     * Initialize tooltips for elements with data-help-id attribute
     * @param {Element} container - Container to search within
     */
    function initTooltips(container = document) {
        container.querySelectorAll('[data-help-id]').forEach(el => {
            const helpId = el.getAttribute('data-help-id');
            const tooltip = getTooltip(helpId);

            if (tooltip) {
                // Set title attribute for native tooltip
                el.setAttribute('title', `${tooltip.title}: ${tooltip.text}`);

                // Add help indicator
                if (!el.querySelector('.rs-help-indicator')) {
                    const indicator = document.createElement('span');
                    indicator.className = 'rs-help-indicator';
                    indicator.textContent = '?';
                    indicator.setAttribute('title', tooltip.text);
                    el.appendChild(indicator);
                }
            }
        });
    }

    // ==========================================================================
    // Onboarding Wizard
    // ==========================================================================

    /**
     * Check if onboarding should be shown
     * @returns {boolean} True if onboarding should be shown
     */
    function shouldShowOnboarding() {
        if (!onboardingData?.wizard) return false;

        const settings = onboardingData.wizard.settings;
        if (!settings.showOnFirstVisit) return false;

        const storageKey = settings.storageKey || 'traceview-review-onboarding-complete';
        return localStorage.getItem(storageKey) !== 'true';
    }

    /**
     * Show onboarding wizard
     */
    function showOnboarding() {
        if (!onboardingData?.wizard) {
            console.warn('Onboarding data not loaded');
            return;
        }

        onboardingStep = 0;
        renderOnboardingStep();
    }

    /**
     * Render current onboarding step
     */
    function renderOnboardingStep() {
        const wizard = onboardingData.wizard;
        const steps = wizard.steps;

        // Remove any existing overlay
        const existingOverlay = document.querySelector('.rs-onboarding-overlay');
        if (existingOverlay) {
            existingOverlay.remove();
        }

        // Check if completed
        if (onboardingStep >= steps.length) {
            renderOnboardingCompletion();
            return;
        }

        const step = steps[onboardingStep];
        const overlay = document.createElement('div');
        overlay.className = 'rs-onboarding-overlay';

        overlay.innerHTML = `
            <div class="rs-onboarding-modal rs-onboarding-${step.position || 'center'}">
                <div class="rs-onboarding-header">
                    <span class="rs-onboarding-step-indicator">
                        Step ${onboardingStep + 1} of ${steps.length}
                    </span>
                    ${wizard.settings.canSkip ? `
                        <button class="rs-btn rs-btn-link rs-onboarding-skip">Skip Tour</button>
                    ` : ''}
                </div>
                <h3 class="rs-onboarding-title">${step.title}</h3>
                <div class="rs-onboarding-content">
                    ${formatMarkdownSimple(step.content)}
                </div>
                <div class="rs-onboarding-actions">
                    ${step.buttons.back ? `
                        <button class="rs-btn rs-onboarding-back">${step.buttons.back}</button>
                    ` : ''}
                    ${step.buttons.next ? `
                        <button class="rs-btn rs-btn-primary rs-onboarding-next">${step.buttons.next}</button>
                    ` : ''}
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        // Highlight target element if specified
        if (step.highlight) {
            const target = document.querySelector(step.highlight);
            if (target) {
                target.classList.add('rs-onboarding-highlight');
            }
        }

        // Bind events
        overlay.querySelector('.rs-onboarding-next')?.addEventListener('click', nextOnboardingStep);
        overlay.querySelector('.rs-onboarding-back')?.addEventListener('click', prevOnboardingStep);
        overlay.querySelector('.rs-onboarding-skip')?.addEventListener('click', completeOnboarding);
    }

    /**
     * Render onboarding completion screen
     */
    function renderOnboardingCompletion() {
        const completion = onboardingData.wizard.completion;
        const overlay = document.createElement('div');
        overlay.className = 'rs-onboarding-overlay';

        overlay.innerHTML = `
            <div class="rs-onboarding-modal rs-onboarding-center">
                <h3 class="rs-onboarding-title">${completion.title}</h3>
                <div class="rs-onboarding-content">
                    ${formatMarkdownSimple(completion.content)}
                </div>
                <div class="rs-onboarding-actions">
                    <button class="rs-btn rs-btn-primary rs-onboarding-close">${completion.buttons.close}</button>
                    ${completion.buttons.docs ? `
                        <button class="rs-btn rs-onboarding-docs">${completion.buttons.docs}</button>
                    ` : ''}
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        overlay.querySelector('.rs-onboarding-close')?.addEventListener('click', completeOnboarding);
        overlay.querySelector('.rs-onboarding-docs')?.addEventListener('click', () => {
            window.open('docs/traceview-review-user-guide.md', '_blank');
            completeOnboarding();
        });
    }

    function nextOnboardingStep() {
        clearOnboardingHighlights();
        onboardingStep++;
        renderOnboardingStep();
    }

    function prevOnboardingStep() {
        clearOnboardingHighlights();
        onboardingStep = Math.max(0, onboardingStep - 1);
        renderOnboardingStep();
    }

    function completeOnboarding() {
        clearOnboardingHighlights();
        const overlay = document.querySelector('.rs-onboarding-overlay');
        if (overlay) {
            overlay.remove();
        }

        // Mark as completed
        const storageKey = onboardingData.wizard.settings.storageKey || 'traceview-review-onboarding-complete';
        localStorage.setItem(storageKey, 'true');
    }

    function clearOnboardingHighlights() {
        document.querySelectorAll('.rs-onboarding-highlight').forEach(el => {
            el.classList.remove('rs-onboarding-highlight');
        });
    }

    // ==========================================================================
    // Help Panel
    // ==========================================================================

    /**
     * Toggle help panel visibility
     */
    function toggleHelpPanel() {
        if (helpPanelVisible) {
            hideHelpPanel();
        } else {
            showHelpPanel();
        }
    }

    /**
     * Show help panel
     */
    function showHelpPanel() {
        if (!helpPanelData?.helpPanel) {
            console.warn('Help panel data not loaded');
            return;
        }

        // Remove existing panel
        const existing = document.querySelector('.rs-help-panel');
        if (existing) {
            existing.remove();
        }

        const panel = helpPanelData.helpPanel;
        const panelEl = document.createElement('div');
        panelEl.className = 'rs-help-panel';

        let sectionsHtml = panel.sections.map(section => `
            <div class="rs-help-section" data-section-id="${section.id}">
                <h4 class="rs-help-section-header" ${panel.settings.collapsible ? 'style="cursor: pointer;"' : ''}>
                    <span>${section.title}</span>
                    ${panel.settings.collapsible ? '<span class="rs-help-expand-icon">V</span>' : ''}
                </h4>
                <div class="rs-help-section-content" ${panel.settings.defaultExpanded?.includes(section.id) ? '' : 'style="display: none;"'}>
                    ${section.items.map(item => `
                        <div class="rs-help-item" data-item-id="${item.id}">
                            <div class="rs-help-question">${item.question}</div>
                            <div class="rs-help-answer">${formatMarkdownSimple(item.answer)}</div>
                        </div>
                    `).join('')}
                </div>
            </div>
        `).join('');

        panelEl.innerHTML = `
            <div class="rs-help-panel-header">
                <h3>${panel.title}</h3>
                <button class="rs-btn rs-btn-sm rs-help-close">x</button>
            </div>
            ${panel.settings.searchable ? `
                <div class="rs-help-search">
                    <input type="text" class="rs-help-search-input" placeholder="Search help...">
                </div>
            ` : ''}
            <div class="rs-help-sections">
                ${sectionsHtml}
            </div>
            <div class="rs-help-footer">
                <p>${panel.footer.text}</p>
                <div class="rs-help-links">
                    ${panel.footer.links.map(link => `
                        <a href="${link.url}" class="rs-help-link">${link.label}</a>
                    `).join('')}
                </div>
            </div>
        `;

        document.body.appendChild(panelEl);
        helpPanelVisible = true;

        // Bind events
        panelEl.querySelector('.rs-help-close').addEventListener('click', hideHelpPanel);

        // Collapsible sections
        if (panel.settings.collapsible) {
            panelEl.querySelectorAll('.rs-help-section-header').forEach(header => {
                header.addEventListener('click', () => {
                    const content = header.nextElementSibling;
                    const icon = header.querySelector('.rs-help-expand-icon');
                    if (content.style.display === 'none') {
                        content.style.display = 'block';
                        if (icon) icon.textContent = 'V';
                    } else {
                        content.style.display = 'none';
                        if (icon) icon.textContent = '>';
                    }
                });
            });
        }

        // Search functionality
        if (panel.settings.searchable) {
            const searchInput = panelEl.querySelector('.rs-help-search-input');
            searchInput.addEventListener('input', (e) => {
                const query = e.target.value.toLowerCase();
                filterHelpItems(panelEl, query);
            });
        }
    }

    /**
     * Hide help panel
     */
    function hideHelpPanel() {
        const panel = document.querySelector('.rs-help-panel');
        if (panel) {
            panel.remove();
        }
        helpPanelVisible = false;
    }

    /**
     * Filter help items based on search query
     */
    function filterHelpItems(panelEl, query) {
        panelEl.querySelectorAll('.rs-help-item').forEach(item => {
            const question = item.querySelector('.rs-help-question').textContent.toLowerCase();
            const answer = item.querySelector('.rs-help-answer').textContent.toLowerCase();

            if (query === '' || question.includes(query) || answer.includes(query)) {
                item.style.display = 'block';
            } else {
                item.style.display = 'none';
            }
        });

        // Show/hide sections based on whether they have visible items
        panelEl.querySelectorAll('.rs-help-section').forEach(section => {
            const visibleItems = section.querySelectorAll('.rs-help-item[style="display: block;"], .rs-help-item:not([style])');
            const content = section.querySelector('.rs-help-section-content');
            if (query && visibleItems.length > 0) {
                content.style.display = 'block';
            }
        });
    }

    // ==========================================================================
    // Utilities
    // ==========================================================================

    /**
     * Simple markdown-like formatting
     */
    function formatMarkdownSimple(text) {
        if (!text) return '';

        // Bold
        text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');

        // Code blocks
        text = text.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');

        // Inline code
        text = text.replace(/`([^`]+)`/g, '<code>$1</code>');

        // Line breaks
        text = text.replace(/\n/g, '<br>');

        return text;
    }

    /**
     * Create help button for header
     */
    function createHelpButton() {
        const btn = document.createElement('button');
        btn.className = 'rs-btn rs-btn-sm rs-help-btn';
        btn.innerHTML = '?';
        btn.title = 'Help';
        btn.addEventListener('click', toggleHelpPanel);
        return btn;
    }

    /**
     * Create replay onboarding button
     */
    function createReplayOnboardingButton() {
        const btn = document.createElement('button');
        btn.className = 'rs-btn rs-btn-sm rs-replay-onboarding-btn';
        btn.textContent = 'Tour';
        btn.title = 'Replay onboarding tour';
        btn.addEventListener('click', () => {
            // Reset onboarding state
            const storageKey = onboardingData?.wizard?.settings?.storageKey || 'traceview-review-onboarding-complete';
            localStorage.removeItem(storageKey);
            showOnboarding();
        });
        return btn;
    }

    // ==========================================================================
    // Help Menu
    // ==========================================================================

    let helpMenuOpen = false;

    /**
     * Create help menu dropdown
     * @returns {HTMLElement} The complete help menu container
     */
    function createHelpMenu() {
        const container = document.createElement('div');
        container.className = 'rs-help-menu-container';
        container.id = 'rs-help-menu';

        container.innerHTML = `
            <button class="rs-help-menu-btn" id="rs-help-menu-btn">
                <span>? Help</span>
                <span class="rs-menu-arrow">V</span>
            </button>
            <div class="rs-help-menu-dropdown" id="rs-help-menu-dropdown">
                <div class="rs-help-menu-section">
                    <button class="rs-help-menu-item" id="rs-menu-tour">
                        <span class="rs-menu-icon">[T]</span>
                        <span class="rs-menu-label">Take Tour</span>
                    </button>
                    <button class="rs-help-menu-item" id="rs-menu-help-panel">
                        <span class="rs-menu-icon">[?]</span>
                        <span class="rs-menu-label">Help Panel</span>
                        <span class="rs-menu-shortcut">?</span>
                    </button>
                </div>
                <div class="rs-help-menu-section">
                    <div class="rs-help-menu-section-label">Documentation</div>
                    <a href="docs/traceview-review-quick-start.md" target="_blank" class="rs-help-menu-item">
                        <span class="rs-menu-icon">[Q]</span>
                        <span class="rs-menu-label">Quick Start</span>
                    </a>
                    <a href="docs/traceview-review-user-guide.md" target="_blank" class="rs-help-menu-item">
                        <span class="rs-menu-icon">[U]</span>
                        <span class="rs-menu-label">User Guide</span>
                    </a>
                </div>
            </div>
        `;

        // Bind events after DOM is created
        const btn = container.querySelector('#rs-help-menu-btn');
        const dropdown = container.querySelector('#rs-help-menu-dropdown');

        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            toggleHelpMenu(btn, dropdown);
        });

        container.querySelector('#rs-menu-tour').addEventListener('click', () => {
            closeHelpMenu(btn, dropdown);
            // Reset onboarding state and show
            const storageKey = onboardingData?.wizard?.settings?.storageKey || 'traceview-review-onboarding-complete';
            localStorage.removeItem(storageKey);
            showOnboarding();
        });

        container.querySelector('#rs-menu-help-panel').addEventListener('click', () => {
            closeHelpMenu(btn, dropdown);
            showHelpPanel();
        });

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!container.contains(e.target)) {
                closeHelpMenu(btn, dropdown);
            }
        });

        // Close menu on ESC key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && helpMenuOpen) {
                closeHelpMenu(btn, dropdown);
            }
        });

        return container;
    }

    /**
     * Toggle help menu open/closed
     */
    function toggleHelpMenu(btn, dropdown) {
        helpMenuOpen = !helpMenuOpen;
        btn.classList.toggle('open', helpMenuOpen);
        dropdown.classList.toggle('open', helpMenuOpen);
    }

    /**
     * Close help menu
     */
    function closeHelpMenu(btn, dropdown) {
        helpMenuOpen = false;
        btn?.classList.remove('open');
        dropdown?.classList.remove('open');
    }

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /**
     * Initialize help system
     * @param {object} options - Configuration options
     */
    async function init(options = {}) {
        const baseUrl = options.helpBaseUrl || '/help';

        await loadHelpData(baseUrl);

        // Initialize tooltips
        initTooltips(document);

        // Show onboarding if first visit
        if (shouldShowOnboarding()) {
            showOnboarding();
        }

        console.log('Help system initialized');
    }

    // ==========================================================================
    // Exports
    // ==========================================================================

    review.help = {
        init,
        loadHelpData,
        initTooltips,
        getTooltip,
        showOnboarding,
        showHelpPanel,
        hideHelpPanel,
        toggleHelpPanel,
        createHelpButton,
        createReplayOnboardingButton,
        createHelpMenu
    };

})(TraceView.review);
