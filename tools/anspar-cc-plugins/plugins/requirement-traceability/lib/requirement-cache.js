#!/usr/bin/env node
/**
 * Requirement-Ticket Cache Management
 *
 * This module maintains a local cache of requirement-to-ticket mappings
 * fetched from Linear. The cache refreshes automatically when stale or
 * can be manually refreshed with --refresh-cache flag.
 *
 * FUTURE: This will integrate with Doppler or similar secret management
 * systems for API credentials.
 */

const fs = require('fs');
const path = require('path');

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';
const CACHE_FILE = path.join(process.cwd(), '.requirement-cache.json');
const CACHE_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Read cache from disk
 * @returns {Object|null} Cache object or null if not found/invalid
 */
function readCache() {
    try {
        if (!fs.existsSync(CACHE_FILE)) {
            return null;
        }

        const data = fs.readFileSync(CACHE_FILE, 'utf8');
        const cache = JSON.parse(data);

        // Validate cache structure
        if (!cache.timestamp || !cache.mappings) {
            return null;
        }

        return cache;
    } catch (error) {
        console.error(`Warning: Failed to read cache: ${error.message}`);
        return null;
    }
}

/**
 * Write cache to disk
 * @param {Object} cache - Cache object to write
 */
function writeCache(cache) {
    try {
        const dir = path.dirname(CACHE_FILE);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2), 'utf8');
    } catch (error) {
        console.error(`Warning: Failed to write cache: ${error.message}`);
    }
}

/**
 * Check if cache is stale
 * @param {Object} cache - Cache object
 * @returns {boolean} True if cache is older than CACHE_MAX_AGE_MS
 */
function isCacheStale(cache) {
    if (!cache || !cache.timestamp) {
        return true;
    }

    const age = Date.now() - cache.timestamp;
    return age > CACHE_MAX_AGE_MS;
}

/**
 * Fetch all tickets with requirement references from Linear
 * @param {string} token - Linear API token
 * @returns {Object} Mapping of requirement ID to ticket identifier
 */
async function fetchRequirementMappings(token) {
    const query = `
        query GetAllIssues($cursor: String) {
            issues(
                first: 100
                after: $cursor
            ) {
                nodes {
                    identifier
                    title
                    description
                }
                pageInfo {
                    hasNextPage
                    endCursor
                }
            }
        }
    `;

    const mappings = {};
    let hasNextPage = true;
    let cursor = null;
    let totalIssues = 0;

    while (hasNextPage) {
        const response = await fetch(LINEAR_API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({
                query,
                variables: { cursor }
            }),
        });

        if (!response.ok) {
            throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();

        if (result.errors) {
            throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
        }

        const issues = result.data.issues.nodes;
        totalIssues += issues.length;

        // Extract requirement mappings from descriptions
        for (const issue of issues) {
            if (!issue.description) continue;

            // Match "**Requirement**: REQ-p00001" or "**Requirement**: REQ-d00014"
            const matches = issue.description.match(/\*\*Requirement\*\*:\s*REQ-([pod]\d+)/gi);
            if (matches) {
                for (const match of matches) {
                    const reqMatch = match.match(/REQ-([pod]\d+)/i);
                    if (reqMatch) {
                        const reqId = reqMatch[1];
                        if (!mappings[reqId]) {
                            mappings[reqId] = [];
                        }
                        mappings[reqId].push(issue.identifier);
                    }
                }
            }
        }

        hasNextPage = result.data.issues.pageInfo.hasNextPage;
        cursor = result.data.issues.pageInfo.endCursor;

        // Add delay to respect rate limits
        if (hasNextPage) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }

    return {
        mappings,
        totalIssues,
        timestamp: Date.now()
    };
}

/**
 * Get requirement-ticket mappings (from cache or fresh fetch)
 * @param {string} token - Linear API token
 * @param {Object} options - Options
 * @param {boolean} options.forceRefresh - Force cache refresh
 * @param {boolean} options.silent - Suppress output messages
 * @returns {Object} Mapping of requirement ID to ticket identifier(s)
 */
async function getRequirementMappings(token, options = {}) {
    const { forceRefresh = false, silent = false } = options;

    let cache = readCache();

    if (forceRefresh || !cache || isCacheStale(cache)) {
        if (!silent) {
            if (forceRefresh) {
                console.log('🔄 Refreshing requirement-ticket cache from Linear...');
            } else if (!cache) {
                console.log('📥 Cache not found, fetching from Linear...');
            } else {
                console.log('⏰ Cache is stale, refreshing from Linear...');
            }
        }

        try {
            const result = await fetchRequirementMappings(token);

            cache = {
                timestamp: result.timestamp,
                mappings: result.mappings,
                metadata: {
                    totalIssues: result.totalIssues,
                    totalMappings: Object.keys(result.mappings).length,
                    lastRefresh: new Date(result.timestamp).toISOString()
                }
            };

            writeCache(cache);

            if (!silent) {
                console.log(`✓ Cached ${cache.metadata.totalMappings} requirement mappings from ${cache.metadata.totalIssues} tickets`);
                console.log('');
            }
        } catch (error) {
            if (!silent) {
                console.error(`✗ Failed to fetch from Linear: ${error.message}`);
            }

            // Fall back to stale cache if available
            if (cache) {
                if (!silent) {
                    console.log('⚠️  Using stale cache as fallback');
                    console.log('');
                }
            } else {
                throw error;
            }
        }
    } else if (!silent) {
        const age = Date.now() - cache.timestamp;
        const ageHours = Math.floor(age / (60 * 60 * 1000));
        console.log(`✓ Using cached mappings (${ageHours}h old, ${cache.metadata.totalMappings} requirements)`);
        console.log('');
    }

    return cache.mappings;
}

/**
 * Get list of requirement IDs that already have tickets
 * @param {string} token - Linear API token
 * @param {Object} options - Options
 * @returns {Set} Set of requirement IDs with tickets
 */
async function getExcludedRequirements(token, options = {}) {
    const mappings = await getRequirementMappings(token, options);
    return new Set(Object.keys(mappings));
}

/**
 * Check if a requirement has an existing ticket
 * @param {string} reqId - Requirement ID (e.g., "p00001")
 * @param {Object} mappings - Mappings object from getRequirementMappings
 * @returns {boolean} True if requirement has a ticket
 */
function hasExistingTicket(reqId, mappings) {
    return reqId in mappings && mappings[reqId].length > 0;
}

/**
 * Get tickets for a requirement
 * @param {string} reqId - Requirement ID (e.g., "p00001")
 * @param {Object} mappings - Mappings object from getRequirementMappings
 * @returns {Array} Array of ticket identifiers
 */
function getTicketsForRequirement(reqId, mappings) {
    return mappings[reqId] || [];
}

module.exports = {
    getRequirementMappings,
    getExcludedRequirements,
    hasExistingTicket,
    getTicketsForRequirement,
    readCache,
    writeCache,
    isCacheStale,
    CACHE_FILE,
    CACHE_MAX_AGE_MS
};
