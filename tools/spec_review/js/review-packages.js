/**
 * Review Packages UI Module
 *
 * Provides UI for managing review packages:
 * - Display collapsible packages panel
 * - Create, edit, delete packages
 * - Select active package for filtering
 * - Add/remove REQs from packages
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00092: HTML Report Integration (package management)
 */

(function() {
    'use strict';

    // Initialize ReviewSystem if not exists
    window.ReviewSystem = window.ReviewSystem || { state: {} };
    const RS = window.ReviewSystem;

    // Package state
    RS.packages = {
        items: [],
        activeId: null,
        defaultId: 'default',
        panelExpanded: true
    };

    // ==========================================================================
    // Toast Notification
    // ==========================================================================

    let toastElement = null;

    /**
     * Show a toast notification positioned near the packages panel
     */
    function showToast(message, showSpinner = false) {
        if (!toastElement) {
            toastElement = document.createElement('div');
            toastElement.className = 'rs-toast';
            document.body.appendChild(toastElement);
        }

        toastElement.innerHTML = showSpinner
            ? `<div class="rs-toast-spinner"></div><span>${message}</span>`
            : `<span>${message}</span>`;

        // Position near the packages panel header
        const packagesPanel = document.getElementById('reviewPackagesPanel');
        if (packagesPanel) {
            const rect = packagesPanel.getBoundingClientRect();
            toastElement.style.top = `${rect.top + window.scrollY + 8}px`;
            toastElement.style.left = `${rect.left + rect.width / 2}px`;
            toastElement.style.transform = 'translateX(-50%) scale(0.9)';
        } else {
            // Fallback to fixed position
            toastElement.style.position = 'fixed';
            toastElement.style.top = '80px';
            toastElement.style.left = '50%';
            toastElement.style.transform = 'translateX(-50%) scale(0.9)';
        }

        // Force reflow then show
        toastElement.offsetHeight;
        toastElement.classList.add('visible');
        if (packagesPanel) {
            toastElement.style.transform = 'translateX(-50%) scale(1)';
        } else {
            toastElement.style.transform = 'translateX(-50%) scale(1)';
        }
    }

    /**
     * Hide the toast notification
     */
    function hideToast() {
        if (toastElement) {
            toastElement.classList.remove('visible');
        }
    }

    // ==========================================================================
    // API Functions
    // ==========================================================================

    /**
     * Fetch all packages from the API
     */
    async function fetchPackages() {
        try {
            const response = await fetch('/api/reviews/packages');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            const data = await response.json();
            RS.packages.items = data.packages || [];
            RS.packages.activeId = data.activePackageId || null;

            // Find default package
            const defaultPkg = RS.packages.items.find(p => p.isDefault);
            if (defaultPkg) {
                RS.packages.defaultId = defaultPkg.packageId;
            }

            return RS.packages;
        } catch (error) {
            console.error('Failed to fetch packages:', error);
            return { items: [], activeId: null };
        }
    }

    /**
     * Create a new package
     */
    async function createPackage(name, description) {
        const user = RS.state.currentUser || 'anonymous';
        try {
            const response = await fetch('/api/reviews/packages', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, description, user })
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                await fetchPackages();
                renderPackagesPanel();
            }
            return result;
        } catch (error) {
            console.error('Failed to create package:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Update a package's name or description
     */
    async function updatePackage(packageId, updates) {
        try {
            const response = await fetch(`/api/reviews/packages/${packageId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(updates)
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                await fetchPackages();
                renderPackagesPanel();
            }
            return result;
        } catch (error) {
            console.error('Failed to update package:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Delete a package
     */
    async function deletePackage(packageId) {
        try {
            const response = await fetch(`/api/reviews/packages/${packageId}`, {
                method: 'DELETE'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                await fetchPackages();
                renderPackagesPanel();
            }
            return result;
        } catch (error) {
            console.error('Failed to delete package:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Set the active package and switch to its git branch
     */
    async function setActivePackage(packageId) {
        const user = RS.state.currentUser || 'anonymous';

        // Show toast when switching to a package (not when selecting None)
        if (packageId) {
            showToast('Syncing with GitHub...', true);
        }

        try {
            // 1. Set the active package in packages.json
            const response = await fetch('/api/reviews/packages/active', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ packageId, user })
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (!result.success) {
                hideToast();
                return result;
            }

            RS.packages.activeId = packageId;

            // 2. Switch to package branch (creates branch if needed)
            if (packageId) {
                await switchToPackageBranch(packageId, user);
            }

            // 3. Re-render panel to update radio buttons and highlights
            renderPackagesPanel();

            // 4. Apply context styling
            applyPackageFilter();

            // 5. Update git sync indicator to show new branch
            if (RS.updateGitSyncIndicator) {
                RS.updateGitSyncIndicator();
            }

            // Toast is hidden in fetchConsolidatedPackageData after sync completes
            // But if no packageId, hide it now
            if (!packageId) {
                hideToast();
            }

            return result;
        } catch (error) {
            console.error('Failed to set active package:', error);
            hideToast();
            return { success: false, error: error.message };
        }
    }

    /**
     * Switch to a package branch for the current user
     */
    async function switchToPackageBranch(packageId, user) {
        try {
            const response = await fetch('/api/reviews/packages/switch', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ packageId, user })
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                console.log(`Switched to branch: ${result.branch}`);
                RS.packages.currentBranch = result.branch;

                // Fetch consolidated data from all package branches
                await fetchConsolidatedPackageData();
            } else {
                // Branch switch failed, hide the toast
                hideToast();
            }
            return result;
        } catch (error) {
            console.error('Failed to switch to package branch:', error);
            hideToast();
            return { success: false, error: error.message };
        }
    }

    /**
     * Fetch consolidated review data from all users' branches for current package
     */
    async function fetchConsolidatedPackageData() {
        // Toast already shown by setActivePackage

        try {
            const response = await fetch('/api/reviews/sync/fetch-all-package', {
                method: 'POST'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            RS.packages.contributors = data.contributors || [];

            // If there's merged thread data, update the state
            if (data.threads && Object.keys(data.threads).length > 0) {
                console.log(`Loaded threads from ${data.contributors.length} contributor(s)`);
                // Trigger refresh event so UI updates
                document.dispatchEvent(new CustomEvent('rs:data-fetched', {
                    detail: { data, timestamp: new Date() }
                }));
            }

            hideToast();
            return data;
        } catch (error) {
            console.error('Failed to fetch consolidated package data:', error);
            hideToast();
            return { threads: {}, flags: {}, contributors: [] };
        }
    }

    /**
     * Get package contributors (users who have branches for this package)
     */
    async function getPackageContributors(packageId) {
        try {
            const response = await fetch(`/api/reviews/packages/${packageId}/contributors`);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            const data = await response.json();
            return data.contributors || [];
        } catch (error) {
            console.error('Failed to get package contributors:', error);
            return [];
        }
    }

    /**
     * Get current package context from git branch
     */
    async function getCurrentPackageContext() {
        try {
            const response = await fetch('/api/reviews/context');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            const data = await response.json();
            return data; // { packageId, user, branch } or null
        } catch (error) {
            console.error('Failed to get package context:', error);
            return null;
        }
    }

    /**
     * Add a REQ to a package
     */
    async function addReqToPackage(packageId, reqId) {
        try {
            const response = await fetch(`/api/reviews/packages/${packageId}/reqs/${reqId}`, {
                method: 'POST'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                // Update local state
                const pkg = RS.packages.items.find(p => p.packageId === packageId);
                if (pkg && !pkg.reqIds.includes(reqId)) {
                    pkg.reqIds.push(reqId);
                }
                renderPackagesPanel();
            }
            return result;
        } catch (error) {
            console.error('Failed to add REQ to package:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Remove a REQ from a package
     */
    async function removeReqFromPackage(packageId, reqId) {
        try {
            const response = await fetch(`/api/reviews/packages/${packageId}/reqs/${reqId}`, {
                method: 'DELETE'
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                // Update local state
                const pkg = RS.packages.items.find(p => p.packageId === packageId);
                if (pkg) {
                    pkg.reqIds = pkg.reqIds.filter(id => id !== reqId);
                }
                renderPackagesPanel();
            }
            return result;
        } catch (error) {
            console.error('Failed to remove REQ from package:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Add REQ to active package (or default if none active)
     */
    async function addReqToActivePackage(reqId) {
        const packageId = RS.packages.activeId || RS.packages.defaultId;
        return addReqToPackage(packageId, reqId);
    }

    // ==========================================================================
    // UI Functions
    // ==========================================================================

    /**
     * Render the packages panel
     */
    function renderPackagesPanel() {
        const panel = document.getElementById('reviewPackagesPanel');
        if (!panel) return;

        const packagesContent = panel.querySelector('.packages-content');
        if (!packagesContent) return;

        const items = RS.packages.items;
        const activeId = RS.packages.activeId;

        // Build package list HTML
        let html = '<div class="package-list">';

        // "None" option (show all REQs)
        html += `
            <label class="package-item${!activeId ? ' active' : ''}">
                <input type="radio" name="activePackage" value=""
                       ${!activeId ? 'checked' : ''}
                       onchange="ReviewSystem.setActivePackage(null)">
                <span class="package-info">
                    <span class="package-name">None (Show All)</span>
                    <span class="package-desc">No package filter applied</span>
                </span>
            </label>
        `;

        // Package items
        for (const pkg of items) {
            const isActive = pkg.packageId === activeId;
            const reqCount = pkg.reqIds ? pkg.reqIds.length : 0;

            html += `
                <label class="package-item${isActive ? ' active' : ''}${pkg.isDefault ? ' default' : ''}">
                    <input type="radio" name="activePackage" value="${pkg.packageId}"
                           ${isActive ? 'checked' : ''}
                           onchange="ReviewSystem.setActivePackage('${pkg.packageId}')">
                    <span class="package-info">
                        <span class="package-name">${escapeHtml(pkg.name)}${pkg.isDefault ? ' (Default)' : ''}</span>
                        <span class="package-desc">${escapeHtml(pkg.description || '')}</span>
                    </span>
                    <span class="package-count">${reqCount}</span>
                    ${!pkg.isDefault ? `
                        <span class="package-actions">
                            <button class="rs-btn rs-btn-sm" onclick="ReviewSystem.editPackageDialog('${pkg.packageId}', event)" title="Edit">
                                &#9998;
                            </button>
                            <button class="rs-btn rs-btn-sm rs-btn-danger" onclick="ReviewSystem.confirmDeletePackage('${pkg.packageId}', event)" title="Delete">
                                &times;
                            </button>
                        </span>
                    ` : ''}
                </label>
            `;
        }

        html += '</div>';
        packagesContent.innerHTML = html;
    }

    /**
     * Toggle packages panel expansion
     */
    function togglePackagesPanel() {
        const panel = document.getElementById('reviewPackagesPanel');
        if (!panel) return;

        RS.packages.panelExpanded = !RS.packages.panelExpanded;
        panel.classList.toggle('collapsed', !RS.packages.panelExpanded);

        const icon = panel.querySelector('.collapse-icon');
        if (icon) {
            icon.textContent = RS.packages.panelExpanded ? '\u25BC' : '\u25B6';
        }
    }

    /**
     * Show create package dialog
     */
    function showCreatePackageDialog(event) {
        if (event) event.stopPropagation();

        const name = prompt('Package name:');
        if (!name || !name.trim()) return;

        const description = prompt('Package description (optional):') || '';
        createPackage(name.trim(), description.trim());
    }

    /**
     * Show edit package dialog
     */
    function editPackageDialog(packageId, event) {
        if (event) event.stopPropagation();

        const pkg = RS.packages.items.find(p => p.packageId === packageId);
        if (!pkg) return;

        const name = prompt('Package name:', pkg.name);
        if (!name || !name.trim()) return;

        const description = prompt('Package description:', pkg.description || '');
        updatePackage(packageId, {
            name: name.trim(),
            description: description ? description.trim() : ''
        });
    }

    /**
     * Confirm and delete package
     */
    function confirmDeletePackage(packageId, event) {
        if (event) event.stopPropagation();

        const pkg = RS.packages.items.find(p => p.packageId === packageId);
        if (!pkg) return;

        if (confirm(`Delete package "${pkg.name}"? REQs will not be deleted.`)) {
            deletePackage(packageId);
        }
    }

    /**
     * Apply package filter to the requirement tree.
     * When a package is selected, only REQs in that package are shown.
     * When "None" is selected, all REQs are visible.
     */
    function applyPackageContext() {
        const activeId = RS.packages.activeId;

        // Build a map of which package each REQ belongs to
        const reqPackageMap = new Map();
        for (const pkg of RS.packages.items) {
            for (const reqId of (pkg.reqIds || [])) {
                reqPackageMap.set(reqId, pkg.packageId);
            }
        }

        // Get REQ IDs in the active package
        let activeReqIds = new Set();
        if (activeId) {
            const pkg = RS.packages.items.find(p => p.packageId === activeId);
            if (pkg) {
                activeReqIds = new Set(pkg.reqIds || []);
            }
        }

        // Apply filter - hide items not in active package (when a package is selected)
        const treeItems = document.querySelectorAll('[data-req-id]');
        treeItems.forEach(item => {
            const reqId = item.getAttribute('data-req-id');

            // Remove old package classes
            item.classList.remove('in-active-package', 'in-other-package', 'not-in-package', 'package-filtered');

            if (!activeId) {
                // No package selected - show all, apply context styling
                item.classList.remove('package-filtered');
                if (reqPackageMap.has(reqId)) {
                    item.classList.add('in-other-package');
                } else {
                    item.classList.add('not-in-package');
                }
            } else if (activeReqIds.has(reqId)) {
                // In active package - show and highlight
                item.classList.remove('package-filtered');
                item.classList.add('in-active-package');
            } else {
                // Not in active package - hide
                item.classList.add('package-filtered');
            }
        });

        // Update context indicator
        updateContextIndicator(activeId);

        // Update icons for items with all children filtered
        if (typeof updateFilteredChildrenIcons === 'function') {
            updateFilteredChildrenIcons();
        }
    }

    /**
     * Update context indicator in UI
     */
    function updateContextIndicator(activeId) {
        const indicator = document.getElementById('packageFilterIndicator');
        if (!indicator) return;

        if (activeId) {
            const pkg = RS.packages.items.find(p => p.packageId === activeId);
            const name = pkg ? pkg.name : 'Unknown';
            indicator.textContent = `Context: ${name}`;
            indicator.style.display = 'inline-block';
        } else {
            indicator.textContent = 'Context: Default';
            indicator.style.display = 'inline-block';
        }
    }

    // Alias for backwards compatibility
    function applyPackageFilter() {
        applyPackageContext();
    }

    /**
     * Escape HTML special characters
     */
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Initialize packages panel when review mode is activated
     */
    async function initPackagesPanel() {
        await fetchPackages();
        renderPackagesPanel();
        applyPackageFilter();
    }

    // ==========================================================================
    // Export Functions
    // ==========================================================================

    RS.fetchPackages = fetchPackages;
    RS.createPackage = createPackage;
    RS.updatePackage = updatePackage;
    RS.deletePackage = deletePackage;
    RS.setActivePackage = setActivePackage;
    RS.switchToPackageBranch = switchToPackageBranch;
    RS.fetchConsolidatedPackageData = fetchConsolidatedPackageData;
    RS.getPackageContributors = getPackageContributors;
    RS.getCurrentPackageContext = getCurrentPackageContext;
    RS.addReqToPackage = addReqToPackage;
    RS.removeReqFromPackage = removeReqFromPackage;
    RS.addReqToActivePackage = addReqToActivePackage;
    RS.renderPackagesPanel = renderPackagesPanel;
    RS.togglePackagesPanel = togglePackagesPanel;
    RS.showCreatePackageDialog = showCreatePackageDialog;
    RS.editPackageDialog = editPackageDialog;
    RS.confirmDeletePackage = confirmDeletePackage;
    RS.initPackagesPanel = initPackagesPanel;
    RS.applyPackageFilter = applyPackageFilter;
    RS.applyPackageContext = applyPackageContext;

})();
