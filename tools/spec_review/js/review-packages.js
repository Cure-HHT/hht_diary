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
     * Set the active package
     */
    async function setActivePackage(packageId) {
        try {
            const response = await fetch('/api/reviews/packages/active', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ packageId })
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const result = await response.json();
            if (result.success) {
                RS.packages.activeId = packageId;
                applyPackageFilter();
            }
            return result;
        } catch (error) {
            console.error('Failed to set active package:', error);
            return { success: false, error: error.message };
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
     * Apply package filter to the requirement tree
     */
    function applyPackageFilter() {
        const activeId = RS.packages.activeId;

        // Get REQ IDs in the active package
        let filterReqIds = null;
        if (activeId) {
            const pkg = RS.packages.items.find(p => p.packageId === activeId);
            if (pkg) {
                filterReqIds = new Set(pkg.reqIds || []);
            }
        }

        // Apply filter to tree items
        const treeItems = document.querySelectorAll('.tree-item[data-req-id]');
        treeItems.forEach(item => {
            const reqId = item.getAttribute('data-req-id');
            if (!filterReqIds) {
                // No filter - show all
                item.style.display = '';
            } else if (filterReqIds.has(reqId)) {
                // In package - show
                item.style.display = '';
            } else {
                // Not in package - hide
                item.style.display = 'none';
            }
        });

        // Update filter indicator
        updateFilterIndicator(activeId);
    }

    /**
     * Update filter indicator in UI
     */
    function updateFilterIndicator(activeId) {
        const indicator = document.getElementById('packageFilterIndicator');
        if (!indicator) return;

        if (activeId) {
            const pkg = RS.packages.items.find(p => p.packageId === activeId);
            const name = pkg ? pkg.name : 'Unknown';
            indicator.textContent = `Filtered by: ${name}`;
            indicator.style.display = 'inline-block';
        } else {
            indicator.style.display = 'none';
        }
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

})();
