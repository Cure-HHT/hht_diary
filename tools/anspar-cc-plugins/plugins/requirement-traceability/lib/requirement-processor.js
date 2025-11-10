#!/usr/bin/env node
/**
 * Requirement Processor for Linear Integration
 *
 * Handles requirement parsing and processing:
 * - Find requirements in spec files
 * - Parse requirement content
 * - Find sub-requirements
 * - Extract requirement metadata
 * - Generate requirement hierarchy
 */

const fs = require('fs');
const path = require('path');
const config = require('./config');

class RequirementProcessor {
    constructor() {
        this.specDir = path.join(config.getPath('..', '..', '..'), 'spec');
        this.requirementCache = new Map();
        this.hierarchyCache = null;
    }

    /**
     * Find a requirement by ID in spec files
     * @param {string} reqId - Requirement ID (e.g., "REQ-p00001")
     * @param {string} preferredTitle - If multiple found, prefer this title
     * @returns {Object|null} Requirement object or null
     */
    findRequirement(reqId, preferredTitle = null) {
        // Check cache first
        const cacheKey = `${reqId}:${preferredTitle || ''}`;
        if (this.requirementCache.has(cacheKey)) {
            return this.requirementCache.get(cacheKey);
        }

        // Search all spec files
        const specFiles = this.getSpecFiles();
        const foundRequirements = [];

        for (const file of specFiles) {
            const content = fs.readFileSync(file, 'utf-8');

            // Look for requirement header
            const reqPattern = new RegExp(`^### ${reqId}:(.*)$`, 'gmi');
            const matches = content.matchAll(reqPattern);

            for (const match of matches) {
                const requirement = this.extractRequirementSection(
                    content,
                    match.index,
                    reqId,
                    match[1].trim(),
                    path.basename(file)
                );
                foundRequirements.push(requirement);
            }
        }

        // Handle multiple requirements with same ID
        let selected = null;
        if (foundRequirements.length > 1 && preferredTitle) {
            selected = foundRequirements.find(req =>
                req.title.toLowerCase().includes(preferredTitle.toLowerCase())
            );
        }

        if (!selected && foundRequirements.length > 0) {
            selected = foundRequirements[0];
        }

        // Cache and return
        if (selected) {
            this.requirementCache.set(cacheKey, selected);
        }
        return selected;
    }

    /**
     * Extract requirement section from content
     * @private
     */
    extractRequirementSection(content, startIdx, reqId, title, fileName) {
        const lines = content.substring(startIdx).split('\n');
        const reqLines = [];
        let implementsList = [];
        let status = 'Active';
        let level = this.getRequirementLevel(reqId);

        // Collect lines until next requirement or section
        for (const line of lines) {
            // Stop at next requirement
            if (line.startsWith('### REQ-') && !line.startsWith(`### ${reqId}`)) {
                break;
            }
            // Stop at next major section
            if (line.startsWith('## ') && reqLines.length > 1) {
                break;
            }

            // Extract metadata
            if (line.includes('Implements:')) {
                const implMatch = line.match(/Implements:\s*(.*)/);
                if (implMatch) {
                    implementsList = implMatch[1].split(',').map(r => r.trim());
                }
            }

            if (line.includes('Status:')) {
                const statusMatch = line.match(/Status:\s*(\w+)/);
                if (statusMatch) {
                    status = statusMatch[1];
                }
            }

            reqLines.push(line);
        }

        return {
            id: reqId,
            title,
            content: reqLines.join('\n'),
            file: fileName,
            implements: implementsList,
            status,
            level
        };
    }

    /**
     * Parse requirement content to extract structured information
     * @param {Object} requirement - Requirement object
     * @returns {Object} Parsed requirement data
     */
    parseRequirementContent(requirement) {
        if (!requirement || !requirement.content) {
            return {
                statements: [],
                bulletPoints: [],
                acceptanceCriteria: [],
                technologies: [],
                subsystems: []
            };
        }

        const parsed = {
            statements: [],
            bulletPoints: [],
            acceptanceCriteria: [],
            technologies: [],
            subsystems: []
        };

        const lines = requirement.content.split('\n');
        let inAcceptanceCriteria = false;

        for (const line of lines) {
            const trimmed = line.trim();

            // Check for acceptance criteria section
            if (trimmed.toLowerCase().includes('acceptance criteria')) {
                inAcceptanceCriteria = true;
                continue;
            }

            // Extract SHALL/MUST statements
            if (trimmed.match(/\b(SHALL|MUST)\b/)) {
                const statement = trimmed
                    .replace(/^.*\b(SHALL|MUST)\b\s*/i, '')
                    .replace(/[.:;]$/, '');
                if (statement.length > 5) {
                    parsed.statements.push(statement);
                }
            }

            // Extract bullet points
            if (trimmed.match(/^[-*•]\s+/)) {
                const item = trimmed.replace(/^[-*•]\s+/, '').replace(/[.:;]$/, '');
                if (item.length > 3) {
                    if (inAcceptanceCriteria) {
                        parsed.acceptanceCriteria.push(item);
                    } else {
                        parsed.bulletPoints.push(item);
                    }
                }
            }

            // Extract numbered lists
            if (trimmed.match(/^\d+\.\s+/)) {
                const item = trimmed.replace(/^\d+\.\s+/, '').replace(/[.:;]$/, '');
                if (item.length > 3) {
                    parsed.bulletPoints.push(item);
                }
            }
        }

        // Extract technology mentions
        parsed.technologies = this.extractTechnologies(requirement.content);

        // Identify subsystems
        parsed.subsystems = this.identifySubsystems(requirement.content);

        return parsed;
    }

    /**
     * Extract technology mentions from content
     * @private
     */
    extractTechnologies(content) {
        const technologies = new Set();
        const patterns = [
            // Frontend
            /\b(React|Angular|Vue|Flutter|TypeScript|JavaScript)\b/gi,
            // Backend
            /\b(Node\.js|Python|Go|Java|\.NET|C#)\b/gi,
            // Databases
            /\b(PostgreSQL|MySQL|MongoDB|Redis|Supabase|Firebase)\b/gi,
            // Cloud/DevOps
            /\b(Docker|Kubernetes|AWS|GCP|Azure|Terraform)\b/gi,
            // Auth/Security
            /\b(OAuth|OAuth2|SAML|JWT|MFA|2FA|TOTP|OIDC)\b/gi,
            // APIs
            /\b(REST|GraphQL|gRPC|WebSocket|HTTP\/2)\b/gi,
            // CI/CD
            /\b(GitHub Actions|Jenkins|GitLab CI|CircleCI|Travis CI)\b/gi,
            // Monitoring
            /\b(Prometheus|Grafana|DataDog|New Relic|Sentry)\b/gi
        ];

        for (const pattern of patterns) {
            const matches = content.match(pattern);
            if (matches) {
                matches.forEach(tech => technologies.add(tech));
            }
        }

        return Array.from(technologies);
    }

    /**
     * Identify subsystems mentioned in content
     * @private
     */
    identifySubsystems(content) {
        const subsystems = new Set();
        const lowerContent = content.toLowerCase();

        const subsystemKeywords = {
            'Database': ['database', 'schema', 'table', 'migration', 'sql', 'rls'],
            'API': ['api', 'endpoint', 'rest', 'graphql', 'route', 'controller'],
            'Frontend': ['ui', 'frontend', 'component', 'page', 'form', 'display', 'portal'],
            'Mobile': ['mobile', 'app', 'flutter', 'ios', 'android'],
            'Authentication': ['auth', 'login', 'mfa', 'oauth', 'security', 'password', 'token'],
            'Infrastructure': ['docker', 'kubernetes', 'deployment', 'ci/cd', 'pipeline'],
            'Testing': ['test', 'testing', 'validation', 'quality', 'qa', 'e2e'],
            'Documentation': ['documentation', 'docs', 'readme', 'guide'],
            'Monitoring': ['monitoring', 'logging', 'metrics', 'observability', 'telemetry']
        };

        for (const [system, keywords] of Object.entries(subsystemKeywords)) {
            if (keywords.some(keyword => lowerContent.includes(keyword))) {
                subsystems.add(system);
            }
        }

        return Array.from(subsystems);
    }

    /**
     * Find all sub-requirements that implement a given requirement
     * @param {string} reqId - Parent requirement ID
     * @returns {Array} Array of sub-requirement objects
     */
    findSubRequirements(reqId) {
        const subReqs = [];
        const level = this.getRequirementLevel(reqId);

        // Determine what levels to look for
        let searchLevels = [];
        if (level === 'PRD') {
            searchLevels = ['Ops', 'Dev'];
        } else if (level === 'Ops') {
            searchLevels = ['Dev'];
        }

        if (searchLevels.length === 0) return subReqs;

        // Search spec files
        const specFiles = this.getSpecFiles();

        for (const file of specFiles) {
            const content = fs.readFileSync(file, 'utf-8');
            const lines = content.split('\n');

            for (let i = 0; i < lines.length; i++) {
                // Look for requirements that implement our requirement
                if (lines[i].includes('Implements:') && lines[i].includes(reqId)) {
                    // Find the requirement ID on previous lines
                    for (let j = i - 1; j >= Math.max(0, i - 10); j--) {
                        const reqMatch = lines[j].match(/^### (REQ-[pod]\d{5}):\s*(.+)$/);
                        if (reqMatch) {
                            subReqs.push({
                                id: reqMatch[1],
                                title: reqMatch[2].trim(),
                                file: path.basename(file),
                                level: this.getRequirementLevel(reqMatch[1])
                            });
                            break;
                        }
                    }
                }
            }
        }

        return subReqs;
    }

    /**
     * Get all requirements from spec files
     * @param {Object} options
     * @param {string} options.level - Filter by level (PRD, Ops, Dev)
     * @param {string} options.status - Filter by status
     * @returns {Array} Array of all requirements
     */
    getAllRequirements(options = {}) {
        const { level = null, status = null } = options;
        const requirements = [];
        const specFiles = this.getSpecFiles();

        for (const file of specFiles) {
            const content = fs.readFileSync(file, 'utf-8');
            const reqPattern = /^### (REQ-[pod]\d{5}):\s*(.+)$/gm;
            const matches = content.matchAll(reqPattern);

            for (const match of matches) {
                const reqId = match[1];
                const reqLevel = this.getRequirementLevel(reqId);

                // Apply filters
                if (level && reqLevel !== level) continue;

                const requirement = this.findRequirement(reqId);
                if (!requirement) continue;

                if (status && requirement.status !== status) continue;

                requirements.push(requirement);
            }
        }

        return requirements;
    }

    /**
     * Build requirement hierarchy tree
     * @returns {Object} Hierarchy tree
     */
    buildHierarchy() {
        if (this.hierarchyCache) {
            return this.hierarchyCache;
        }

        const hierarchy = {
            PRD: [],
            Ops: [],
            Dev: []
        };

        // Get all requirements
        const allReqs = this.getAllRequirements();

        // Build parent-child relationships
        const reqMap = new Map();
        for (const req of allReqs) {
            reqMap.set(req.id, {
                ...req,
                children: []
            });
        }

        // Link children to parents
        for (const req of allReqs) {
            if (req.implements && req.implements.length > 0) {
                for (const parentId of req.implements) {
                    const parent = reqMap.get(parentId);
                    if (parent) {
                        parent.children.push(req.id);
                    }
                }
            }
        }

        // Organize by level
        for (const [id, req] of reqMap) {
            const level = this.getRequirementLevel(id);
            if (hierarchy[level]) {
                hierarchy[level].push(req);
            }
        }

        // Sort each level
        for (const level of Object.keys(hierarchy)) {
            hierarchy[level].sort((a, b) => a.id.localeCompare(b.id));
        }

        this.hierarchyCache = hierarchy;
        return hierarchy;
    }

    /**
     * Check if a requirement exists
     * @param {string} reqId - Requirement ID
     * @returns {boolean} True if exists
     */
    requirementExists(reqId) {
        return this.findRequirement(reqId) !== null;
    }

    /**
     * Get requirement level from ID
     * @param {string} reqId - Requirement ID
     * @returns {string} Level (PRD, Ops, Dev)
     */
    getRequirementLevel(reqId) {
        if (!reqId) return 'Unknown';

        if (reqId.includes('REQ-p')) return 'PRD';
        if (reqId.includes('REQ-o')) return 'Ops';
        if (reqId.includes('REQ-d')) return 'Dev';

        return 'Unknown';
    }

    /**
     * Get all spec files in the spec directory
     * @private
     * @returns {Array<string>} Array of file paths
     */
    getSpecFiles() {
        if (!fs.existsSync(this.specDir)) {
            console.warn(`Spec directory not found: ${this.specDir}`);
            return [];
        }

        return fs.readdirSync(this.specDir)
            .filter(f => f.endsWith('.md'))
            .map(f => path.join(this.specDir, f));
    }

    /**
     * Clear all caches
     */
    clearCache() {
        this.requirementCache.clear();
        this.hierarchyCache = null;
    }

    /**
     * Display requirement summary
     * @param {Object} requirement - Requirement object
     * @param {Object} options - Display options
     */
    displayRequirement(requirement, options = {}) {
        const { showContent = false, showChildren = true } = options;

        console.log(`\n📋 ${requirement.id}: ${requirement.title}`);
        console.log(`   File: ${requirement.file}`);
        console.log(`   Level: ${requirement.level}`);
        console.log(`   Status: ${requirement.status}`);

        if (requirement.implements && requirement.implements.length > 0) {
            console.log(`   Implements: ${requirement.implements.join(', ')}`);
        }

        if (showChildren) {
            const children = this.findSubRequirements(requirement.id);
            if (children.length > 0) {
                console.log(`   Sub-requirements (${children.length}):`);
                for (const child of children) {
                    console.log(`     - ${child.id}: ${child.title}`);
                }
            }
        }

        if (showContent) {
            console.log('\n   Content:');
            const lines = requirement.content.split('\n').slice(1); // Skip header
            for (const line of lines.slice(0, 10)) {
                if (line.trim()) {
                    console.log(`     ${line}`);
                }
            }
            if (lines.length > 10) {
                console.log(`     ... (${lines.length - 10} more lines)`);
            }
        }
    }
}

// Export singleton instance
module.exports = new RequirementProcessor();