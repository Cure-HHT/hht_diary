#!/usr/bin/env node
/**
 * Add requirement-based implementation checklists to Linear tickets
 *
 * Parses requirement content from spec/ files to extract:
 * - SHALL/MUST statements as tasks
 * - Bullet points and lists as checklist items
 * - Sub-requirements and dependencies
 * - Acceptance criteria
 * - Technology mentions and subsystems
 */

const fs = require('fs');
const path = require('path');
const config = require('./lib/config');

// Parse command line arguments
function parseArgs() {
    const args = {
        ticketId: null,
        fromRequirement: false,
        requirement: null,
        includeAcceptance: false,
        includeSubsystems: false,
        dryRun: false,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--ticketId=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--requirement=')) {
            args.requirement = arg.split('=')[1];
        } else if (arg === '--fromRequirement' || arg === '--from-requirement') {
            args.fromRequirement = true;
        } else if (arg === '--includeAcceptance' || arg === '--include-acceptance') {
            args.includeAcceptance = true;
        } else if (arg === '--includeSubsystems' || arg === '--include-subsystems') {
            args.includeSubsystems = true;
        } else if (arg === '--dry-run' || arg === '--dryRun') {
            args.dryRun = true;
        }
    }

    if (!args.ticketId) {
        console.error('❌ --ticketId is required');
        console.error('Usage: node add-requirement-checklist.js --ticketId=<id> [options]');
        process.exit(1);
    }

    return args;
}

/**
 * Find and read requirement from spec files
 */
function findRequirement(reqId) {
    const projectRoot = path.resolve(__dirname, '../../..');
    const specDir = path.join(projectRoot, 'spec');

    // Search all spec files for the requirement
    const specFiles = fs.readdirSync(specDir)
        .filter(f => f.endsWith('.md'))
        .map(f => path.join(specDir, f));

    for (const file of specFiles) {
        const content = fs.readFileSync(file, 'utf-8');

        // Look for the requirement header
        const reqPattern = new RegExp(`^### ${reqId}:(.*)$`, 'mi');
        const match = content.match(reqPattern);

        if (match) {
            // Extract requirement section
            const startIdx = match.index;
            const lines = content.substring(startIdx).split('\n');
            const reqLines = [];

            // Collect lines until next requirement or section
            for (const line of lines) {
                if (line.startsWith('### REQ-') && !line.startsWith(`### ${reqId}`)) {
                    break;
                }
                if (line.startsWith('## ') && reqLines.length > 1) {
                    break;
                }
                reqLines.push(line);
            }

            return {
                id: reqId,
                title: match[1].trim(),
                content: reqLines.join('\n'),
                file: path.basename(file)
            };
        }
    }

    return null;
}

/**
 * Parse requirement content to extract checklist items
 */
function parseRequirementContent(requirement) {
    const checklist = [];
    const lines = requirement.content.split('\n');

    let inAcceptanceCriteria = false;
    let inBulletList = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();

        // Check for acceptance criteria section
        if (line.toLowerCase().includes('acceptance criteria')) {
            inAcceptanceCriteria = true;
            continue;
        }

        // Extract SHALL/MUST statements
        if (line.match(/\b(SHALL|MUST)\b/)) {
            const task = line
                .replace(/^.*\b(SHALL|MUST)\b\s*/i, '')
                .replace(/[.:;]$/, '');
            if (task.length > 5) {
                checklist.push(`Implement: ${task}`);
            }
        }

        // Extract bullet points
        if (line.match(/^[-*•]\s+/)) {
            const item = line.replace(/^[-*•]\s+/, '').replace(/[.:;]$/, '');
            if (item.length > 3) {
                checklist.push(item);
            }
            inBulletList = true;
        } else if (inBulletList && !line.match(/^\s*$/) && !line.match(/^[-*•]/)) {
            inBulletList = false;
        }

        // Extract numbered lists
        if (line.match(/^\d+\.\s+/)) {
            const item = line.replace(/^\d+\.\s+/, '').replace(/[.:;]$/, '');
            if (item.length > 3) {
                checklist.push(item);
            }
        }

        // Extract from acceptance criteria section
        if (inAcceptanceCriteria && line.match(/^[-*•]\s+/)) {
            const item = line.replace(/^[-*•]\s+/, '');
            if (item.length > 3) {
                checklist.push(`Verify: ${item}`);
            }
        }
    }

    // Extract technology mentions
    const techPatterns = [
        /\b(React|Angular|Vue|Flutter)\b/gi,
        /\b(PostgreSQL|MySQL|MongoDB|Supabase)\b/gi,
        /\b(Docker|Kubernetes|Terraform)\b/gi,
        /\b(OAuth|SAML|MFA|2FA)\b/gi,
        /\b(REST|GraphQL|WebSocket)\b/gi,
        /\b(CI\/CD|GitHub Actions|Jenkins)\b/gi
    ];

    const techMentions = new Set();
    for (const pattern of techPatterns) {
        const matches = requirement.content.match(pattern);
        if (matches) {
            matches.forEach(m => techMentions.add(m));
        }
    }

    if (techMentions.size > 0) {
        techMentions.forEach(tech => {
            checklist.push(`Configure ${tech}`);
        });
    }

    // Remove duplicates and clean up
    const uniqueChecklist = [...new Set(checklist.map(item =>
        item.charAt(0).toUpperCase() + item.slice(1)
    ))];

    return uniqueChecklist;
}

/**
 * Find sub-requirements that implement this requirement
 */
function findSubRequirements(reqId, specDir) {
    const subReqs = [];
    const level = reqId.substring(4, 5); // p, o, or d

    // Determine what level to look for
    let searchLevels = [];
    if (level === 'p') {
        searchLevels = ['o', 'd'];
    } else if (level === 'o') {
        searchLevels = ['d'];
    }

    if (searchLevels.length === 0) return subReqs;

    // Search spec files for requirements that implement this one
    const specFiles = fs.readdirSync(specDir)
        .filter(f => f.endsWith('.md'))
        .map(f => path.join(specDir, f));

    for (const file of specFiles) {
        const content = fs.readFileSync(file, 'utf-8');
        const lines = content.split('\n');

        for (let i = 0; i < lines.length; i++) {
            // Look for requirements that implement our requirement
            if (lines[i].includes(`Implements:`) && lines[i].includes(reqId)) {
                // Find the requirement ID on previous lines
                for (let j = i - 1; j >= Math.max(0, i - 10); j--) {
                    const reqMatch = lines[j].match(/^### (REQ-[pod]\d{5}):\s*(.+)$/);
                    if (reqMatch) {
                        subReqs.push({
                            id: reqMatch[1],
                            title: reqMatch[2].trim()
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
 * Generate subsystem tasks based on requirement content
 */
function generateSubsystemTasks(requirement) {
    const tasks = {};
    const content = requirement.content.toLowerCase();

    // Define subsystem patterns
    const subsystems = {
        'Database': {
            keywords: ['database', 'schema', 'table', 'postgres', 'sql', 'migration', 'rls'],
            tasks: [
                'Update database schema',
                'Create migration scripts',
                'Update RLS policies',
                'Add indexes for performance'
            ]
        },
        'API': {
            keywords: ['api', 'endpoint', 'rest', 'graphql', 'route', 'controller'],
            tasks: [
                'Implement API endpoints',
                'Add request validation',
                'Update API documentation',
                'Add error handling'
            ]
        },
        'Frontend': {
            keywords: ['ui', 'frontend', 'react', 'component', 'page', 'form', 'display'],
            tasks: [
                'Create UI components',
                'Add form validation',
                'Implement responsive design',
                'Update user documentation'
            ]
        },
        'Authentication': {
            keywords: ['auth', 'login', 'mfa', 'oauth', 'security', 'password', 'token'],
            tasks: [
                'Implement authentication flow',
                'Add security validations',
                'Configure session management',
                'Set up token refresh'
            ]
        },
        'Testing': {
            keywords: ['test', 'validation', 'quality', 'qa'],
            tasks: [
                'Write unit tests',
                'Create integration tests',
                'Add E2E test scenarios',
                'Update test documentation'
            ]
        }
    };

    // Check which subsystems are relevant
    for (const [system, config] of Object.entries(subsystems)) {
        const isRelevant = config.keywords.some(keyword => content.includes(keyword));
        if (isRelevant) {
            tasks[system] = config.tasks;
        }
    }

    return tasks;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();
    const token = config.getToken(true);
    const apiEndpoint = config.getApiEndpoint();

    // Get ticket details
    const getTicketQuery = `
        query GetIssue($id: String!) {
            issue(id: $id) {
                id
                identifier
                title
                description
            }
        }
    `;

    try {
        const response = await fetch(apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({
                query: getTicketQuery,
                variables: { id: args.ticketId }
            }),
        });

        const result = await response.json();
        if (result.errors) {
            throw new Error(`Failed to get ticket: ${JSON.stringify(result.errors)}`);
        }

        const ticket = result.data?.issue;
        if (!ticket) {
            throw new Error(`Ticket ${args.ticketId} not found`);
        }

        console.log(`\n📋 Processing ticket: ${ticket.identifier} - ${ticket.title}`);

        // Determine which requirement to use
        let reqId = args.requirement;

        if (!reqId && args.fromRequirement) {
            // Extract from ticket description
            const reqMatch = ticket.description?.match(/REQ-[pod]\d{5}/);
            if (reqMatch) {
                reqId = reqMatch[0];
                console.log(`   Found requirement: ${reqId}`);
            } else {
                console.error('❌ No requirement found in ticket description');
                process.exit(1);
            }
        }

        if (!reqId) {
            console.error('❌ No requirement specified. Use --requirement or --fromRequirement');
            process.exit(1);
        }

        // Find and parse the requirement
        const requirement = findRequirement(reqId);
        if (!requirement) {
            console.error(`❌ Requirement ${reqId} not found in spec files`);
            process.exit(1);
        }

        console.log(`   Requirement: ${requirement.title}`);
        console.log(`   Source: ${requirement.file}`);

        // Generate checklist items
        let checklistItems = [];

        // Add items from requirement content
        console.log('\n📝 Parsing requirement content...');
        const contentItems = parseRequirementContent(requirement);
        if (contentItems.length > 0) {
            checklistItems.push('### From Requirement Content');
            checklistItems = checklistItems.concat(contentItems.map(item => `- [ ] ${item}`));
        }

        // Add sub-requirements
        const projectRoot = path.resolve(__dirname, '../../..');
        const specDir = path.join(projectRoot, 'spec');
        const subReqs = findSubRequirements(reqId, specDir);

        if (subReqs.length > 0) {
            checklistItems.push('');
            checklistItems.push('### Sub-Requirements');
            subReqs.forEach(sub => {
                checklistItems.push(`- [ ] Complete ${sub.id}: ${sub.title}`);
            });
        }

        // Add subsystem tasks if requested
        if (args.includeSubsystems) {
            const subsystemTasks = generateSubsystemTasks(requirement);
            if (Object.keys(subsystemTasks).length > 0) {
                checklistItems.push('');
                checklistItems.push('### Subsystem Tasks');
                for (const [system, tasks] of Object.entries(subsystemTasks)) {
                    checklistItems.push(`\n#### ${system}`);
                    tasks.forEach(task => {
                        checklistItems.push(`- [ ] ${task}`);
                    });
                }
            }
        }

        if (checklistItems.length === 0) {
            console.log('⚠️  No checklist items generated');
            return;
        }

        // Display checklist
        console.log('\n📋 Generated Checklist:');
        console.log('------------------------');
        checklistItems.forEach(item => console.log(item));
        console.log('------------------------');

        if (args.dryRun) {
            console.log('\n✅ Dry run complete (no changes made)');
            return;
        }

        // Update ticket
        const newDescription = ticket.description + '\n\n' + checklistItems.join('\n');

        const updateQuery = `
            mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
                issueUpdate(id: $id, input: $input) {
                    success
                    issue {
                        id
                        identifier
                        url
                    }
                }
            }
        `;

        const updateResponse = await fetch(apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({
                query: updateQuery,
                variables: {
                    id: ticket.id,
                    input: { description: newDescription }
                }
            }),
        });

        const updateResult = await updateResponse.json();
        if (!updateResult.data?.issueUpdate?.success) {
            throw new Error('Failed to update ticket');
        }

        console.log(`\n✅ Updated ticket: ${updateResult.data.issueUpdate.issue.url}`);

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        process.exit(1);
    }
}

main();