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
     * @returns {Promise<{file: string, lineNumber: number, heading: string, anchor: string} | null>}
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
     * @returns {Promise<{file: string, lineNumber: number, heading: string, anchor: string} | null>}
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
            const match = firstMatch.match(/^(.+?):(\d+):(.+)$/);

            if (!match) {
                return null;
            }

            const absolutePath = match[1];
            const lineNumber = parseInt(match[2], 10);
            const headingText = match[3].trim();

            // Convert absolute path to repo-relative path
            const relativePath = path.relative(this.repoRoot, absolutePath);

            // Normalize path separators to forward slashes (for URLs)
            const normalizedPath = relativePath.replace(/\\/g, '/');

            // Generate GitHub anchor from heading
            const anchor = this.generateGitHubAnchor(headingText);

            // Extract title from heading
            const title = this.extractTitle(headingText);

            if (lines.length > 1) {
                console.warn(`⚠️  Multiple matches for REQ-${normalizedId}, using first: ${normalizedPath}:${lineNumber}`);
            }

            return {
                file: normalizedPath,
                lineNumber: lineNumber,
                heading: headingText,
                title: title,
                anchor: anchor
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
     * Generate GitHub anchor from markdown heading
     * GitHub converts headings to anchors by:
     * - Removing the leading # and whitespace
     * - Converting to lowercase
     * - Replacing spaces with hyphens
     * - Removing special characters (except hyphens)
     * @param {string} heading - e.g., "# REQ-o00009: Portal Deployment Per-Sponsor"
     * @returns {string} Anchor - e.g., "req-o00009-portal-deployment-per-sponsor"
     */
    generateGitHubAnchor(heading) {
        return heading
            .replace(/^#+\s*/, '')           // Remove leading # and spaces
            .toLowerCase()                    // Convert to lowercase
            .replace(/[:\(\)\[\]\{\}]/g, '') // Remove special chars: : ( ) [ ] { }
            .replace(/\s+/g, '-')            // Replace spaces with hyphens
            .replace(/[^a-z0-9\-]/g, '')     // Remove anything not alphanumeric or hyphen
            .replace(/-+/g, '-')             // Collapse multiple hyphens
            .replace(/^-|-$/g, '');          // Trim leading/trailing hyphens
    }

    /**
     * Build GitHub URL for a spec file location using anchor
     * @param {string} file - Relative path from repo root (e.g., "spec/dev-foo.md")
     * @param {string} anchor - GitHub heading anchor (e.g., "req-o00009-portal-deployment-per-sponsor")
     * @returns {string} Full GitHub URL
     */
    buildGitHubUrl(file, anchor) {
        const baseUrl = `https://github.com/${this.githubOwner}/${this.githubRepo}/blob/${this.githubBranch}`;
        return `${baseUrl}/${file}#${anchor}`;
    }

    /**
     * Extract title from requirement heading
     * @param {string} heading - e.g., "# REQ-o00009: Portal Deployment Per-Sponsor"
     * @returns {string} Title - e.g., "Portal Deployment Per-Sponsor"
     */
    extractTitle(heading) {
        // Extract everything after the colon and space
        const match = heading.match(/:\s*(.+)$/);
        return match ? match[1].trim() : '';
    }

    /**
     * Format REQ link for Linear ticket (markdown)
     * @param {string} reqId - e.g., "d00014" or "REQ-d00014"
     * @param {string} file - e.g., "spec/dev-foo.md"
     * @param {string} anchor - GitHub heading anchor
     * @param {string} title - Requirement title (optional)
     * @returns {string} Formatted markdown link
     *
     * Example output:
     *   Requirement: REQ-d00027 | Containerized Development Environments | [dev-environment.md](https://github.com/.../spec/dev-environment.md#req-d00027-containerized-development-environments)
     */
    formatReqLink(reqId, file, anchor, title = '') {
        const normalizedId = this.normalizeReqId(reqId);
        const url = this.buildGitHubUrl(file, anchor);

        // Extract just the filename from the path (e.g., "dev-environment.md" from "spec/dev-environment.md")
        const basename = file.split('/').pop();

        // Format: Requirement: REQ-d00027 | Title | [filename](url)
        if (title) {
            return `Requirement: REQ-${normalizedId} | ${title} | [${basename}](${url})`;
        } else {
            // Fallback if no title provided
            return `Requirement: REQ-${normalizedId} | [${basename}](${url})`;
        }
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
