#!/usr/bin/env node
/**
 * Checklist Generator for Linear Integration
 *
 * Generates implementation checklists from various sources:
 * - Requirement content parsing
 * - Subsystem-specific tasks
 * - Acceptance criteria
 * - Technology-specific setup tasks
 */

const requirementProcessor = require('./requirement-processor');

class ChecklistGenerator {
    constructor() {
        this.subsystemTasks = {
            'Database': [
                'Update database schema',
                'Create migration scripts',
                'Update RLS policies',
                'Add indexes for performance',
                'Update seed data if needed'
            ],
            'API': [
                'Implement API endpoints',
                'Add request validation',
                'Update API documentation',
                'Add error handling',
                'Implement rate limiting if needed'
            ],
            'Frontend': [
                'Create UI components',
                'Add form validation',
                'Implement responsive design',
                'Update user documentation',
                'Add loading states and error handling'
            ],
            'Mobile': [
                'Update mobile app screens',
                'Handle offline functionality',
                'Test on different devices',
                'Update app store descriptions if needed'
            ],
            'Authentication': [
                'Implement authentication flow',
                'Add security validations',
                'Configure session management',
                'Set up token refresh',
                'Update security documentation'
            ],
            'Infrastructure': [
                'Update deployment configurations',
                'Modify CI/CD pipelines',
                'Update infrastructure as code',
                'Configure monitoring',
                'Update operational runbooks'
            ],
            'Testing': [
                'Write unit tests',
                'Create integration tests',
                'Add E2E test scenarios',
                'Update test documentation',
                'Verify test coverage'
            ],
            'Documentation': [
                'Update technical documentation',
                'Create/update user guides',
                'Update API documentation',
                'Add code comments',
                'Update README files'
            ],
            'Monitoring': [
                'Add logging statements',
                'Configure metrics collection',
                'Set up alerts',
                'Create dashboards',
                'Document monitoring procedures'
            ]
        };

        this.technologyTasks = {
            // Frontend
            'React': ['Set up React components', 'Configure state management', 'Add React Router if needed'],
            'Flutter': ['Create Flutter widgets', 'Configure navigation', 'Set up state management'],
            'TypeScript': ['Add type definitions', 'Configure TypeScript compiler', 'Update tsconfig.json'],

            // Backend
            'Node.js': ['Set up Node.js server', 'Configure middleware', 'Add error handlers'],
            'Python': ['Set up Python environment', 'Install dependencies', 'Configure WSGI/ASGI'],

            // Databases
            'PostgreSQL': ['Create PostgreSQL schema', 'Set up connections', 'Configure connection pooling'],
            'Supabase': ['Configure Supabase client', 'Set up RLS policies', 'Configure real-time subscriptions'],
            'MongoDB': ['Define MongoDB schemas', 'Set up indexes', 'Configure replication'],

            // DevOps
            'Docker': ['Create Dockerfile', 'Configure docker-compose', 'Optimize image size'],
            'Kubernetes': ['Create deployment manifests', 'Configure services', 'Set up ingress'],
            'GitHub Actions': ['Create workflow files', 'Configure secrets', 'Set up matrix builds'],

            // Auth
            'OAuth': ['Configure OAuth provider', 'Set up redirect URIs', 'Handle token exchange'],
            'OAuth2': ['Configure OAuth2 flow', 'Set up scopes', 'Implement token refresh'],
            'JWT': ['Configure JWT signing', 'Set up token validation', 'Handle token expiry'],
            'MFA': ['Set up MFA provider', 'Configure backup codes', 'Handle recovery flows'],
            'TOTP': ['Implement TOTP generation', 'Set up QR code display', 'Handle time drift']
        };
    }

    /**
     * Generate a comprehensive checklist from a requirement
     * @param {string|Object} requirement - Requirement ID or object
     * @param {Object} options
     * @param {boolean} options.includeAcceptance - Include acceptance criteria
     * @param {boolean} options.includeSubsystems - Include subsystem tasks
     * @param {boolean} options.includeChildren - Include sub-requirements
     * @param {boolean} options.includeTechnologies - Include technology setup
     * @returns {Object} Checklist object with sections
     */
    async generateFromRequirement(requirement, options = {}) {
        const {
            includeAcceptance = true,
            includeSubsystems = true,
            includeChildren = true,
            includeTechnologies = true
        } = options;

        // Get requirement object if ID was passed
        let req = requirement;
        if (typeof requirement === 'string') {
            req = requirementProcessor.findRequirement(requirement);
            if (!req) {
                throw new Error(`Requirement ${requirement} not found`);
            }
        }

        const checklist = {
            requirementId: req.id,
            requirementTitle: req.title,
            sections: []
        };

        // Parse requirement content
        const parsed = requirementProcessor.parseRequirementContent(req);

        // Add main implementation tasks from requirement
        if (parsed.statements.length > 0 || parsed.bulletPoints.length > 0) {
            const mainTasks = [];

            // Add SHALL/MUST statements
            for (const statement of parsed.statements) {
                mainTasks.push(`Implement: ${statement}`);
            }

            // Add bullet points
            for (const point of parsed.bulletPoints) {
                mainTasks.push(point);
            }

            if (mainTasks.length > 0) {
                checklist.sections.push({
                    title: 'Implementation Tasks',
                    tasks: mainTasks
                });
            }
        }

        // Add acceptance criteria
        if (includeAcceptance && parsed.acceptanceCriteria.length > 0) {
            checklist.sections.push({
                title: 'Acceptance Criteria',
                tasks: parsed.acceptanceCriteria.map(c => `Verify: ${c}`)
            });
        }

        // Add sub-requirements
        if (includeChildren) {
            const children = requirementProcessor.findSubRequirements(req.id);
            if (children.length > 0) {
                checklist.sections.push({
                    title: 'Sub-Requirements',
                    tasks: children.map(child =>
                        `Complete ${child.id}: ${child.title}`
                    )
                });
            }
        }

        // Add subsystem-specific tasks
        if (includeSubsystems && parsed.subsystems.length > 0) {
            for (const subsystem of parsed.subsystems) {
                const tasks = this.getSubsystemTasks(subsystem, req);
                if (tasks.length > 0) {
                    checklist.sections.push({
                        title: `${subsystem} Tasks`,
                        tasks
                    });
                }
            }
        }

        // Add technology-specific tasks
        if (includeTechnologies && parsed.technologies.length > 0) {
            const techTasks = [];
            for (const tech of parsed.technologies) {
                const tasks = this.getTechnologyTasks(tech);
                if (tasks.length > 0) {
                    // Add only the first task as a setup task
                    techTasks.push(`Configure ${tech}`);
                }
            }

            if (techTasks.length > 0) {
                checklist.sections.push({
                    title: 'Technology Setup',
                    tasks: techTasks
                });
            }
        }

        // Add general validation tasks
        checklist.sections.push({
            title: 'Validation',
            tasks: [
                'Run tests to verify implementation',
                'Update documentation',
                'Review code changes',
                'Verify requirement compliance'
            ]
        });

        return checklist;
    }

    /**
     * Get subsystem-specific tasks
     * @private
     */
    getSubsystemTasks(subsystem, requirement) {
        const baseTasks = this.subsystemTasks[subsystem] || [];

        // Customize tasks based on requirement content
        const customTasks = [];
        const content = requirement.content.toLowerCase();

        if (subsystem === 'Database' && content.includes('migration')) {
            customTasks.push('Test migration rollback procedures');
        }

        if (subsystem === 'API' && content.includes('graphql')) {
            customTasks.push('Update GraphQL schema', 'Generate GraphQL types');
        }

        if (subsystem === 'Frontend' && content.includes('accessibility')) {
            customTasks.push('Run accessibility audit', 'Add ARIA labels');
        }

        if (subsystem === 'Authentication' && content.includes('sso')) {
            customTasks.push('Configure SSO provider', 'Test SSO flow');
        }

        return [...baseTasks, ...customTasks];
    }

    /**
     * Get technology-specific tasks
     * @private
     */
    getTechnologyTasks(technology) {
        return this.technologyTasks[technology] || [`Set up ${technology}`];
    }

    /**
     * Generate checklist from text analysis
     * @param {string} text - Text to analyze
     * @returns {Array<string>} Checklist items
     */
    generateFromText(text) {
        const checklist = [];

        // Extract action items (starts with action verbs)
        const actionVerbs = [
            'implement', 'create', 'update', 'add', 'remove', 'configure',
            'set up', 'deploy', 'test', 'verify', 'validate', 'document',
            'refactor', 'optimize', 'fix', 'debug', 'review', 'approve'
        ];

        const lines = text.split('\n');
        for (const line of lines) {
            const lower = line.toLowerCase().trim();
            if (actionVerbs.some(verb => lower.startsWith(verb))) {
                checklist.push(line.trim());
            }
        }

        // Extract numbered lists
        const numberedPattern = /^\d+\.\s+(.+)$/gm;
        const numberedMatches = text.matchAll(numberedPattern);
        for (const match of numberedMatches) {
            checklist.push(match[1]);
        }

        // Extract bullet points
        const bulletPattern = /^[-*•]\s+(.+)$/gm;
        const bulletMatches = text.matchAll(bulletPattern);
        for (const match of bulletMatches) {
            checklist.push(match[1]);
        }

        // Remove duplicates
        return [...new Set(checklist)];
    }

    /**
     * Format checklist as markdown
     * @param {Object} checklist - Checklist object from generateFromRequirement
     * @returns {string} Markdown formatted checklist
     */
    formatAsMarkdown(checklist) {
        let markdown = '';

        if (checklist.requirementId) {
            markdown += `## Implementation Checklist for ${checklist.requirementId}\n\n`;
            if (checklist.requirementTitle) {
                markdown += `**${checklist.requirementTitle}**\n\n`;
            }
        }

        for (const section of checklist.sections) {
            if (section.tasks.length === 0) continue;

            markdown += `### ${section.title}\n\n`;
            for (const task of section.tasks) {
                markdown += `- [ ] ${task}\n`;
            }
            markdown += '\n';
        }

        return markdown;
    }

    /**
     * Merge multiple checklists
     * @param {Array<Object>} checklists - Array of checklist objects
     * @returns {Object} Merged checklist
     */
    mergeChecklists(...checklists) {
        const merged = {
            sections: []
        };

        // Group sections by title
        const sectionMap = new Map();

        for (const checklist of checklists) {
            for (const section of checklist.sections || []) {
                if (!sectionMap.has(section.title)) {
                    sectionMap.set(section.title, new Set());
                }
                const taskSet = sectionMap.get(section.title);
                for (const task of section.tasks || []) {
                    taskSet.add(task);
                }
            }
        }

        // Convert back to sections array
        for (const [title, taskSet] of sectionMap) {
            merged.sections.push({
                title,
                tasks: Array.from(taskSet)
            });
        }

        return merged;
    }

    /**
     * Generate a simple task list from keywords
     * @param {Array<string>} keywords - Keywords to generate tasks from
     * @returns {Array<string>} Task list
     */
    generateFromKeywords(keywords) {
        const tasks = [];

        for (const keyword of keywords) {
            const lower = keyword.toLowerCase();

            // Map keywords to common tasks
            if (lower.includes('api')) {
                tasks.push('Design API endpoints', 'Implement API handlers', 'Add API tests');
            }
            if (lower.includes('database') || lower.includes('db')) {
                tasks.push('Design database schema', 'Create migrations', 'Add database indexes');
            }
            if (lower.includes('ui') || lower.includes('frontend')) {
                tasks.push('Design UI mockups', 'Implement UI components', 'Add UI tests');
            }
            if (lower.includes('auth')) {
                tasks.push('Implement authentication', 'Add authorization checks', 'Test security');
            }
            if (lower.includes('test')) {
                tasks.push('Write unit tests', 'Create integration tests', 'Perform manual testing');
            }
            if (lower.includes('deploy')) {
                tasks.push('Prepare deployment package', 'Update deployment scripts', 'Deploy to environment');
            }
            if (lower.includes('document')) {
                tasks.push('Write technical documentation', 'Update user guides', 'Add code comments');
            }
        }

        // Remove duplicates
        return [...new Set(tasks)];
    }

    /**
     * Estimate effort for a checklist
     * @param {Object} checklist - Checklist object
     * @returns {Object} Effort estimate
     */
    estimateEffort(checklist) {
        let totalTasks = 0;
        let estimatedHours = 0;

        const taskEstimates = {
            'implement': 4,
            'create': 3,
            'update': 2,
            'configure': 2,
            'test': 2,
            'verify': 1,
            'document': 1,
            'review': 1,
            'complete req': 8  // Sub-requirements
        };

        for (const section of checklist.sections || []) {
            for (const task of section.tasks || []) {
                totalTasks++;

                // Estimate based on task keywords
                const lower = task.toLowerCase();
                let taskHours = 2; // Default

                for (const [keyword, hours] of Object.entries(taskEstimates)) {
                    if (lower.includes(keyword)) {
                        taskHours = hours;
                        break;
                    }
                }

                estimatedHours += taskHours;
            }
        }

        return {
            totalTasks,
            estimatedHours,
            estimatedDays: Math.ceil(estimatedHours / 6), // 6 productive hours per day
            complexity: totalTasks > 20 ? 'High' : totalTasks > 10 ? 'Medium' : 'Low'
        };
    }
}

// Export singleton instance
module.exports = new ChecklistGenerator();