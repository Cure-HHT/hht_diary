#!/usr/bin/env node
/**
 * Create Linear tickets for requirements that don't have tickets
 *
 * IMPLEMENTS REQUIREMENTS:
 *   (Supporting tool for requirement traceability - no specific REQ-* yet)
 *
 * FUTURE ENHANCEMENT: Environment variables will be fetched from Doppler
 * or similar secret management system instead of local env vars.
 *
 * Usage:
 *   node create-requirement-tickets.js --token=<token> [options]
 *
 * Options:
 *   --token=<token>     Linear API token (required)
 *   --team-id=<id>      Linear team ID (required, or auto-discovered)
 *   --project-id=<id>   Linear project ID (optional, for grouping)
 *   --dry-run           Show what would be created without creating
 *   --refresh-cache     Force refresh of requirement-ticket cache from Linear
 *   --level=<level>     Only create tickets for level (PRD, Ops, or Dev)
 */

const { validateEnvironment, getCredentialsFromArgs } = require('./lib/env-validation');
const { getExcludedRequirements } = require('./lib/requirement-cache');
const reqLocator = require('./lib/req-locator');
const fs = require('fs');
const path = require('path');

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// Parse command line arguments
// Note: Token and team-id validation is handled by env-validation module
function parseArgs() {
    const args = {
        token: null,
        teamId: null,
        projectId: null,
        dryRun: false,
        refreshCache: false,
        level: null,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--token=')) {
            args.token = arg.split('=')[1];
        } else if (arg.startsWith('--team-id=')) {
            args.teamId = arg.split('=')[1];
        } else if (arg.startsWith('--project-id=')) {
            args.projectId = arg.split('=')[1];
        } else if (arg === '--dry-run') {
            args.dryRun = true;
        } else if (arg === '--refresh-cache') {
            args.refreshCache = true;
        } else if (arg.startsWith('--level=')) {
            args.level = arg.split('=')[1];
        }
    }

    // Token and team-id are validated by env-validation module in main()
    return args;
}

/**
 * Execute GraphQL mutation/query against Linear API
 */
async function executeMutation(apiToken, mutation, variables) {
    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': apiToken,
        },
        body: JSON.stringify({ query: mutation, variables }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    return result.data;
}

/**
 * Fetch all labels for a team
 */
async function fetchLabels(apiToken, teamId) {
    const query = `
        query GetLabels($teamId: String!) {
            team(id: $teamId) {
                labels {
                    nodes {
                        id
                        name
                        color
                    }
                }
            }
        }
    `;

    const data = await executeMutation(apiToken, query, { teamId });
    return data.team.labels.nodes;
}

/**
 * Create a new label
 */
async function createLabel(apiToken, teamId, name, color = "#5E6AD2") {
    const mutation = `
        mutation CreateLabel($teamId: String!, $name: String!, $color: String!) {
            issueLabelCreate(input: {
                teamId: $teamId
                name: $name
                color: $color
            }) {
                success
                issueLabel {
                    id
                    name
                    color
                }
            }
        }
    `;

    const data = await executeMutation(apiToken, mutation, { teamId, name, color });
    return data.issueLabelCreate.issueLabel;
}

/**
 * Parse requirements from spec files
 */
function parseRequirements(specDir) {
    const requirements = [];
    const reqHeaderPattern = /^###\s+REQ-([pod]\d{5}):\s+(.+)$/gm;
    const metadataPattern = /\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)/;

    const specFiles = fs.readdirSync(specDir).filter(f => f.endsWith('.md'));

    for (const file of specFiles) {
        const content = fs.readFileSync(path.join(specDir, file), 'utf-8');
        let match;

        while ((match = reqHeaderPattern.exec(content)) !== null) {
            const reqId = match[1];
            const title = match[2].trim();
            const remainingContent = content.slice(match.index + match[0].length);
            const metadataMatch = remainingContent.match(metadataPattern);

            if (metadataMatch) {
                const level = metadataMatch[1];
                const implementsStr = metadataMatch[2].trim();
                const status = metadataMatch[3];

                const implements = implementsStr === '-'
                    ? []
                    : implementsStr.split(',').map(s => s.trim());

                requirements.push({
                    id: reqId,
                    title,
                    level,
                    implements,
                    status,
                    file
                });
            }
        }
    }

    return requirements;
}

/**
 * Create Linear issue
 */
async function createIssue(apiToken, teamId, title, description, projectId = null, priority = 0, labelIds = []) {
    const mutation = `
        mutation CreateIssue($teamId: String!, $title: String!, $description: String, $projectId: String, $priority: Int, $labelIds: [String!]) {
            issueCreate(input: {
                teamId: $teamId
                title: $title
                description: $description
                projectId: $projectId
                priority: $priority
                labelIds: $labelIds
            }) {
                success
                issue {
                    id
                    identifier
                    url
                }
            }
        }
    `;

    const variables = {
        teamId,
        title,
        description,
        projectId,
        priority,
        labelIds
    };

    const data = await executeMutation(apiToken, mutation, variables);
    return data.issueCreate;
}

/**
 * Determine appropriate labels for a requirement
 */
function getLabelsForRequirement(req, availableLabels, aiNewLabelId) {
    const labelIds = [aiNewLabelId]; // Always include ai:new
    const reqText = (req.id + ' ' + req.title + ' ' + req.file).toLowerCase();

    // Match labels based on keywords in requirement
    for (const label of availableLabels) {
        const labelName = label.name.toLowerCase();

        // Skip ai:new since we already added it
        if (labelName === 'ai:new') continue;

        // Check if label keyword appears in requirement
        if (reqText.includes(labelName)) {
            labelIds.push(label.id);
            continue;
        }

        // Special keyword mappings
        const keywordMappings = {
            'security': ['auth', 'rbac', 'encryption', 'mfa', 'access', 'privilege', 'isolation'],
            'compliance': ['fda', 'alcoa', 'audit', 'validation', 'traceability', 'retention'],
            'database': ['schema', 'supabase', 'postgres', 'sql', 'rls'],
            'mobile': ['app', 'flutter', 'dart', 'offline'],
            'backend': ['api', 'server', 'endpoint'],
            'infrastructure': ['deployment', 'terraform', 'cicd', 'docker'],
            'documentation': ['adr', 'spec', 'requirements'],
        };

        // Check if any keywords for this label match the requirement
        const keywords = keywordMappings[labelName] || [];
        for (const keyword of keywords) {
            if (reqText.includes(keyword)) {
                labelIds.push(label.id);
                break;
            }
        }
    }

    return labelIds;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();

    // Validate environment and get credentials
    // Checks for LINEAR_API_TOKEN (required) and LINEAR_TEAM_ID (auto-discovers if missing)
    // Command-line args override environment variables
    const credentials = getCredentialsFromArgs(process.argv.slice(2));

    // Override environment with command-line args temporarily
    if (credentials.token) process.env.LINEAR_API_TOKEN = credentials.token;
    if (credentials.teamId) process.env.LINEAR_TEAM_ID = credentials.teamId;

    const env = await validateEnvironment({
        requireToken: true,
        requireTeamId: true,
        autoDiscover: true,
        silent: false
    });

    // Override args with validated credentials
    args.token = env.token;
    args.teamId = env.teamId;

    console.log('================================================================================');
    console.log('CREATE LINEAR TICKETS FOR REQUIREMENTS');
    console.log('================================================================================');
    console.log('');

    // Parse requirements from spec directory (repo root)
    const specDir = path.join(__dirname, '../../../../spec');

    if (!fs.existsSync(specDir)) {
        console.error(`Error: spec directory not found: ${specDir}`);
        process.exit(1);
    }

    console.log(`Reading requirements from: ${specDir}`);
    const allRequirements = parseRequirements(specDir);

    console.log(`Found ${allRequirements.length} requirements`);
    console.log('');

    // Filter by level if specified
    let requirements = allRequirements;
    if (args.level) {
        requirements = requirements.filter(r => r.level === args.level);
        console.log(`Filtered to ${requirements.length} ${args.level} requirements`);
        console.log('');
    }

    // Skip requirements that already have tickets (dynamically fetched from Linear)
    // Cache is automatically refreshed if older than 24 hours
    // Use --refresh-cache to force immediate refresh
    const excludedRequirements = await getExcludedRequirements(args.token, {
        forceRefresh: args.refreshCache,
        silent: false
    });

    const beforeFilter = requirements.length;
    requirements = requirements.filter(r => !excludedRequirements.has(r.id));
    const excluded = beforeFilter - requirements.length;

    if (excluded > 0) {
        console.log(`Skipped ${excluded} requirements that already have tickets`);
        console.log('');
    }

    console.log(`Creating tickets for ${requirements.length} requirements`);
    console.log('');

    // Fetch available labels
    console.log('Fetching available labels...');
    const availableLabels = await fetchLabels(args.token, args.teamId);
    console.log(`Found ${availableLabels.length} existing labels`);
    console.log('');

    // Ensure ai:new label exists
    let aiNewLabel = availableLabels.find(l => l.name === 'ai:new');
    if (!aiNewLabel) {
        console.log('Creating "ai:new" label...');
        aiNewLabel = await createLabel(args.token, args.teamId, 'ai:new', '#10B981');
        availableLabels.push(aiNewLabel);
        console.log('✅ Created "ai:new" label');
        console.log('');
    } else {
        console.log('✅ "ai:new" label already exists');
        console.log('');
    }

    if (args.dryRun) {
        console.log('🔍 DRY RUN MODE - No tickets will be created');
        console.log('');
    }

    let created = 0;
    let failed = 0;

    for (const req of requirements) {
        const ticketTitle = req.title;

        // Build ticket description with GitHub link to requirement
        const reqLocation = await reqLocator.findReqLocation(req.id);
        const ticketDescription = reqLocation
            ? `**Requirement**: ${reqLocator.formatReqLink(req.id, reqLocation.file, reqLocation.lineNumber)}`
            : `**Requirement**: REQ-${req.id} (location not found in spec/)`;

        // Set priority based on level
        // PRD = P1 (Urgent), Ops = P2 (High), Dev = P3 (Normal)
        const priority = req.level === 'PRD' ? 1 : req.level === 'Ops' ? 2 : 3;

        // Determine labels for this requirement
        const labelIds = getLabelsForRequirement(req, availableLabels, aiNewLabel.id);
        const labelNames = labelIds.map(id => {
            const label = availableLabels.find(l => l.id === id);
            return label ? label.name : id;
        });

        if (args.dryRun) {
            console.log(`Would create: ${ticketTitle}`);
            console.log(`  Level: ${req.level} | Priority: P${priority} | Implements: ${req.implements.length > 0 ? req.implements.join(', ') : 'none'}`);
            console.log(`  Labels: ${labelNames.join(', ')}`);
        } else {
            try {
                const result = await createIssue(
                    args.token,
                    args.teamId,
                    ticketTitle,
                    ticketDescription,
                    args.projectId,
                    priority,
                    labelIds
                );

                if (result.success) {
                    console.log(`✅ Created ${result.issue.identifier}: ${ticketTitle}`);
                    console.log(`   ${result.issue.url}`);
                    console.log(`   Labels: ${labelNames.join(', ')}`);
                    created++;
                } else {
                    console.log(`❌ Failed to create: ${ticketTitle}`);
                    failed++;
                }

                // Rate limit: Wait 100ms between requests
                await new Promise(resolve => setTimeout(resolve, 100));
            } catch (error) {
                console.error(`❌ Error creating ticket for REQ-${req.id}: ${error.message}`);
                failed++;
            }
        }
    }

    console.log('');
    console.log('================================================================================');
    console.log('SUMMARY');
    console.log('================================================================================');
    console.log(`Total requirements: ${requirements.length}`);
    if (!args.dryRun) {
        console.log(`Successfully created: ${created}`);
        console.log(`Failed: ${failed}`);
    }
    console.log('');
}

// Run
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
