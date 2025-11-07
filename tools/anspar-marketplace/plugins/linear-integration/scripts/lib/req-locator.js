#!/usr/bin/env node
/**
 * REQ Location Finder
 *
 * Finds where requirements are defined in spec/ files and generates
 * clickable GitHub links for Linear ticket descriptions.
 *
 * IMPLEMENTS REQUIREMENTS:
 *   Supporting CUR-329: Link REQ references to spec/ files
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class ReqLocator {
    constructor() {
        // In-memory cache for requirement locations
        this.cache = new Map();

        // GitHub configuration
        this.githubOwner = 'Cure-HHT';
        this.githubRepo = 'hht_diary';
        this.githubBranch = 'main';

        // Find repository root
        this.repoRoot = this.findRepoRoot();
    }

    /**
     * Find git repository root
     * @returns {string} Absolute path to repo root
     */
    findRepoRoot() {
        try {
            const root = execSync('git rev-parse --show-toplevel', {
                encoding: 'utf-8',
                stdio: ['pipe', 'pipe', 'ignore']
            }).trim();
            return root;
        } catch (error) {
            // Fallback: assume we're in the repo
            return process.cwd();
        }
    }

    /**
     * Normalize REQ ID (strip REQ- prefix if present, ensure lowercase)
     * @param {string} reqId - e.g., "REQ-d00014" or "d00014"
     * @returns {string} Normalized ID (e.g., "d00014")
     */
    normalizeReqId(reqId) {
        return reqId.replace(/^REQ-/i, '').toLowerCase();
    }

    /**
     * Find where a requirement is defined in spec/ files
     * @param {string} reqId - e.g., "d00014" or "REQ-d00014"
     * @returns {Promise<{file: string, lineNumber: number} | null>}
     */
    async findReqLocation(reqId) {
        const normalizedId = this.normalizeReqId(reqId);

        // Check cache first
        if (this.cache.has(normalizedId)) {
            return this.cache.get(normalizedId);
        }

        // Try grep search in spec/
        const location = await this.searchWithGrep(normalizedId);

        // Cache result (even if null)
        this.cache.set(normalizedId, location);

        return location;
    }

    /**
     * Search for REQ using grep
     * @param {string} normalizedId - e.g., "d00014"
     * @returns {Promise<{file: string, lineNumber: number} | null>}
     * @private
     */
    async searchWithGrep(normalizedId) {
        try {
            // Build grep pattern: "# REQ-d00014:" (case insensitive)
            const pattern = `^# REQ-${normalizedId}:`;
            const specDir = path.join(this.repoRoot, 'spec');

            // Run grep: -r (recursive), -n (line numbers), -i (case insensitive)
            const grepCmd = `grep -rni "${pattern}" "${specDir}" --include="*.md"`;

            const output = execSync(grepCmd, {
                encoding: 'utf-8',
                stdio: ['pipe', 'pipe', 'ignore']
            }).trim();

            if (!output) {
                return null;
            }

            // Parse grep output: "spec/dev-foo.md:29:# REQ-d00014: Title"
            const lines = output.split('\n');

            if (lines.length === 0) {
                return null;
            }

            // Use first match (if multiple)
            const firstMatch = lines[0];
            const match = firstMatch.match(/^(.+?):(\d+):/);

            if (!match) {
                return null;
            }

            const absolutePath = match[1];
            const lineNumber = parseInt(match[2], 10);

            // Convert absolute path to repo-relative path
            const relativePath = path.relative(this.repoRoot, absolutePath);

            // Normalize path separators to forward slashes (for URLs)
            const normalizedPath = relativePath.replace(/\\/g, '/');

            if (lines.length > 1) {
                console.warn(`⚠️  Multiple matches for REQ-${normalizedId}, using first: ${normalizedPath}:${lineNumber}`);
            }

            return {
                file: normalizedPath,
                lineNumber: lineNumber
            };

        } catch (error) {
            // grep returns exit code 1 if no matches found
            if (error.status === 1) {
                return null;
            }
            // Other errors (grep not found, permission issues, etc.)
            console.error(`Error searching for REQ-${normalizedId}:`, error.message);
            return null;
        }
    }

    /**
     * Build GitHub URL for a spec file location
     * @param {string} file - Relative path from repo root (e.g., "spec/dev-foo.md")
     * @param {number} lineNumber - Line number
     * @returns {string} Full GitHub URL
     */
    buildGitHubUrl(file, lineNumber) {
        const baseUrl = `https://github.com/${this.githubOwner}/${this.githubRepo}/blob/${this.githubBranch}`;
        return `${baseUrl}/${file}#L${lineNumber}`;
    }

    /**
     * Format REQ link for Linear ticket (markdown)
     * @param {string} reqId - e.g., "d00014" or "REQ-d00014"
     * @param {string} file - e.g., "spec/dev-foo.md"
     * @param {number} lineNumber - Line number
     * @returns {string} Formatted markdown link
     *
     * Example output:
     *   REQ-d00014 - spec/dev-requirements-management.md ([GitHub](https://github.com/.../spec/dev-requirements-management.md#L29))
     */
    formatReqLink(reqId, file, lineNumber) {
        const normalizedId = this.normalizeReqId(reqId);
        const url = this.buildGitHubUrl(file, lineNumber);

        // Format: REQ-d00014 - spec/file.md ([GitHub](url))
        return `REQ-${normalizedId} - ${file} ([GitHub](${url}))`;
    }

    /**
     * Clear the cache (useful for testing or after spec/ updates)
     */
    clearCache() {
        this.cache.clear();
    }

    /**
     * Get cache statistics
     * @returns {{size: number, entries: Array<{reqId: string, found: boolean}>}}
     */
    getCacheStats() {
        const entries = [];
        for (const [reqId, location] of this.cache.entries()) {
            entries.push({
                reqId: reqId,
                found: location !== null,
                location: location
            });
        }

        return {
            size: this.cache.size,
            entries: entries
        };
    }
}

// Export singleton instance
module.exports = new ReqLocator();
