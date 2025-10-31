#!/usr/bin/env node
/**
 * Label Manager for Linear Integration
 *
 * Handles all label-related operations with:
 * - Label fetching and caching
 * - Name to ID mapping
 * - Label search and filtering
 * - Session-based caching for efficiency
 */

const config = require('./config');
const graphql = require('./graphql-client');
const teamResolver = require('./team-resolver');

class LabelManager {
    constructor() {
        this.labelsCache = null;
        this.cacheExpiry = null;
        this.cacheDuration = 5 * 60 * 1000; // Cache for 5 minutes
    }

    /**
     * Get all labels for the current team
     * @param {Object} options
     * @param {boolean} options.forceRefresh - Force refresh even if cached
     * @returns {Promise<Array>} Array of label objects
     */
    async getAllLabels(options = {}) {
        const { forceRefresh = false } = options;

        // Check if we have valid cached labels
        if (this.labelsCache && this.cacheExpiry && Date.now() < this.cacheExpiry && !forceRefresh) {
            return this.labelsCache;
        }

        // Get team ID
        const teamId = await teamResolver.getTeamId();

        // Fetch labels from API
        const query = `
            query GetLabels($teamId: String!) {
                team(id: $teamId) {
                    labels {
                        nodes {
                            id
                            name
                            description
                            color
                            createdAt
                            updatedAt
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(query, { teamId });
        const labels = data.team?.labels?.nodes || [];

        // Sort labels alphabetically by name
        labels.sort((a, b) => a.name.localeCompare(b.name));

        // Update cache
        this.labelsCache = labels;
        this.cacheExpiry = Date.now() + this.cacheDuration;

        return labels;
    }

    /**
     * Get labels filtered by prefix
     * @param {string} prefix - Prefix to filter by (e.g., "ai:", "m:")
     * @param {Object} options - Options for getAllLabels
     * @returns {Promise<Array>} Filtered array of labels
     */
    async getLabelsByPrefix(prefix, options = {}) {
        const allLabels = await this.getAllLabels(options);

        if (!prefix) {
            return allLabels;
        }

        const lowerPrefix = prefix.toLowerCase();
        return allLabels.filter(label =>
            label.name.toLowerCase().startsWith(lowerPrefix)
        );
    }

    /**
     * Search labels by partial name match
     * @param {string} searchTerm - Term to search for
     * @param {Object} options - Options for getAllLabels
     * @returns {Promise<Array>} Matching labels
     */
    async searchLabels(searchTerm, options = {}) {
        const allLabels = await this.getAllLabels(options);

        if (!searchTerm) {
            return allLabels;
        }

        const lowerSearch = searchTerm.toLowerCase();
        return allLabels.filter(label =>
            label.name.toLowerCase().includes(lowerSearch) ||
            (label.description && label.description.toLowerCase().includes(lowerSearch))
        );
    }

    /**
     * Get label IDs from label names
     * @param {Array<string>} labelNames - Array of label names
     * @param {Object} options
     * @param {boolean} options.strict - If true, throw error on missing labels
     * @param {boolean} options.silent - Suppress console warnings
     * @returns {Promise<Object>} Object with found IDs, missing names, and mapping
     */
    async getLabelIdsFromNames(labelNames, options = {}) {
        const { strict = false, silent = false } = options;

        if (!labelNames || labelNames.length === 0) {
            return { ids: [], missing: [], mapping: {} };
        }

        const allLabels = await this.getAllLabels();

        // Create name to label map for quick lookup
        const labelMap = new Map();
        for (const label of allLabels) {
            labelMap.set(label.name.toLowerCase(), label);
        }

        const foundIds = [];
        const missingNames = [];
        const mapping = {};

        for (const name of labelNames) {
            const normalizedName = name.trim().toLowerCase();
            const label = labelMap.get(normalizedName);

            if (label) {
                foundIds.push(label.id);
                mapping[name] = {
                    id: label.id,
                    actualName: label.name
                };
            } else {
                missingNames.push(name);
            }
        }

        // Report missing labels
        if (missingNames.length > 0) {
            if (!silent) {
                missingNames.forEach(name => {
                    console.log(`   ⚠️  Label not found: ${name}`);
                });
            }

            if (strict) {
                throw new Error(`Labels not found: ${missingNames.join(', ')}`);
            }
        }

        // Report found labels
        if (!silent && foundIds.length > 0) {
            for (const [name, info] of Object.entries(mapping)) {
                console.log(`   ✓ Found label: ${info.actualName}`);
            }
        }

        return {
            ids: foundIds,
            missing: missingNames,
            mapping
        };
    }

    /**
     * Get a single label by exact name match
     * @param {string} labelName - Exact label name
     * @returns {Promise<Object|null>} Label object or null
     */
    async getLabelByName(labelName) {
        const allLabels = await this.getAllLabels();
        const normalizedName = labelName.trim().toLowerCase();

        return allLabels.find(label =>
            label.name.toLowerCase() === normalizedName
        ) || null;
    }

    /**
     * Create a new label
     * @param {Object} labelData
     * @param {string} labelData.name - Label name (required)
     * @param {string} labelData.description - Label description
     * @param {string} labelData.color - Hex color code
     * @returns {Promise<Object>} Created label
     */
    async createLabel(labelData) {
        const { name, description = '', color = '#4EA7FC' } = labelData;

        if (!name) {
            throw new Error('Label name is required');
        }

        const teamId = await teamResolver.getTeamId();

        const mutation = `
            mutation CreateLabel($teamId: String!, $name: String!, $description: String, $color: String!) {
                issueLabelCreate(
                    input: {
                        teamId: $teamId
                        name: $name
                        description: $description
                        color: $color
                    }
                ) {
                    success
                    issueLabel {
                        id
                        name
                        description
                        color
                    }
                }
            }
        `;

        const variables = {
            teamId,
            name,
            description,
            color
        };

        const data = await graphql.execute(mutation, variables);

        if (!data.issueLabelCreate?.success) {
            throw new Error('Failed to create label');
        }

        // Clear cache so next fetch gets the new label
        this.clearCache();

        return data.issueLabelCreate.issueLabel;
    }

    /**
     * Display labels in a formatted way
     * @param {Array} labels - Array of label objects
     * @param {Object} options
     * @param {boolean} options.showDescription - Show descriptions
     * @param {boolean} options.showColor - Show color codes
     * @param {boolean} options.json - Output as JSON
     */
    displayLabels(labels, options = {}) {
        const { showDescription = true, showColor = true, json = false } = options;

        if (json) {
            console.log(JSON.stringify(labels, null, 2));
            return;
        }

        if (!labels || labels.length === 0) {
            console.log('No labels found');
            return;
        }

        console.log('\n📏 Available Linear labels:');
        console.log('━'.repeat(50));

        for (const label of labels) {
            let output = `  ${label.name}`;

            if (showDescription && label.description) {
                output += ` - ${label.description}`;
            }

            if (showColor && label.color) {
                output += ` [${label.color}]`;
            }

            console.log(output);
        }

        console.log('━'.repeat(50));
        console.log(`Total: ${labels.length} label${labels.length !== 1 ? 's' : ''}\n`);
    }

    /**
     * Clear the label cache
     */
    clearCache() {
        this.labelsCache = null;
        this.cacheExpiry = null;
    }

    /**
     * Get cache status
     * @returns {Object} Cache status information
     */
    getCacheStatus() {
        return {
            cached: !!this.labelsCache,
            expires: this.cacheExpiry ? new Date(this.cacheExpiry) : null,
            labelCount: this.labelsCache ? this.labelsCache.length : 0
        };
    }
}

// Export singleton instance
module.exports = new LabelManager();