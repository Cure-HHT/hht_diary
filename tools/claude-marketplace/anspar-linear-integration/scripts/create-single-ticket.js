#!/usr/bin/env node

/**
 * Create a single Linear ticket with custom title and description
 *
 * Usage:
 *   node create-single-ticket.js --token=<token> --team-id=<id> --title="Title" --description="Description" [--priority=<0-4>] [--labels="label1,label2"]
 */

const https = require('https');
const { validateEnvironment, getCredentialsFromArgs } = require('./lib/env-validation.js');

// Parse command line arguments
const args = process.argv.slice(2);
let title = '';
let description = '';
let priority = 0; // Default priority (no priority)
let labels = [];

args.forEach(arg => {
    if (arg.startsWith('--title=')) {
        title = arg.split('=')[1];
    } else if (arg.startsWith('--description=')) {
        description = arg.split('=')[1];
    } else if (arg.startsWith('--priority=')) {
        priority = parseInt(arg.split('=')[1]);
    } else if (arg.startsWith('--labels=')) {
        labels = arg.split('=')[1].split(',').map(l => l.trim());
    }
});

if (!title || !description) {
    console.error('Error: --title and --description are required');
    console.error('Usage: node create-single-ticket.js --title="Title" --description="Description" [--priority=<0-4>] [--labels="label1,label2"]');
    console.error('\nPriority values: 0=No priority, 1=Urgent, 2=High, 3=Normal, 4=Low');
    process.exit(1);
}

async function makeGraphQLRequest(query, variables, apiToken) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({ query, variables });

        const options = {
            hostname: 'api.linear.app',
            path: '/graphql',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': apiToken,
                'Content-Length': data.length
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(body);
                    if (parsed.errors) {
                        reject(new Error(JSON.stringify(parsed.errors)));
                    } else {
                        resolve(parsed);
                    }
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

async function getTeamLabels(apiToken, teamId) {
    const query = `
        query GetLabels($teamId: String!) {
            team(id: $teamId) {
                labels {
                    nodes {
                        id
                        name
                    }
                }
            }
        }
    `;

    const result = await makeGraphQLRequest(query, { teamId }, apiToken);
    return result.data.team.labels.nodes;
}

async function createTicket(apiToken, teamId, title, description, priority, labelNames) {
    console.log(`\n🎫 Creating Linear ticket...`);
    console.log(`   Title: ${title}`);
    console.log(`   Priority: ${priority === 1 ? 'P1 (Urgent)' : priority === 2 ? 'P2 (High)' : priority === 3 ? 'P3 (Normal)' : priority === 4 ? 'P4 (Low)' : 'No priority'}`);

    // Get available labels and map names to IDs
    const availableLabels = await getTeamLabels(apiToken, teamId);
    const labelIds = [];

    if (labelNames.length > 0) {
        console.log(`   Labels requested: ${labelNames.join(', ')}`);

        for (const labelName of labelNames) {
            const label = availableLabels.find(l => l.name.toLowerCase() === labelName.toLowerCase());
            if (label) {
                labelIds.push(label.id);
                console.log(`   ✓ Found label: ${label.name}`);
            } else {
                console.log(`   ⚠ Label not found: ${labelName}`);
            }
        }
    }

    const mutation = `
        mutation CreateIssue($teamId: String!, $title: String!, $description: String!, $priority: Int, $labelIds: [String!]) {
            issueCreate(
                input: {
                    teamId: $teamId
                    title: $title
                    description: $description
                    priority: $priority
                    labelIds: $labelIds
                }
            ) {
                success
                issue {
                    id
                    identifier
                    title
                    url
                }
            }
        }
    `;

    const variables = {
        teamId,
        title,
        description,
        priority: priority || 0,
        labelIds: labelIds.length > 0 ? labelIds : undefined
    };

    const result = await makeGraphQLRequest(mutation, variables, apiToken);

    if (result.data.issueCreate.success) {
        const issue = result.data.issueCreate.issue;
        console.log(`\n✅ Ticket created successfully!`);
        console.log(`   ID: ${issue.identifier}`);
        console.log(`   Title: ${issue.title}`);
        console.log(`   URL: ${issue.url}`);
        return issue;
    } else {
        throw new Error('Failed to create ticket');
    }
}

async function main() {
    // Parse credentials from command line or environment
    const credentials = getCredentialsFromArgs(process.argv);

    // Validate environment (checks LINEAR_API_TOKEN, auto-discovers LINEAR_TEAM_ID)
    const envCheck = await validateEnvironment({
        requireToken: true,
        requireTeamId: true,
        autoDiscover: true,
        silent: false
    });

    // Use credentials from command line if provided, otherwise from environment validation
    const apiToken = credentials.token || envCheck.token;
    const teamId = credentials.teamId || envCheck.teamId;

    if (!apiToken || !teamId) {
        console.error('Error: Missing required credentials');
        process.exit(1);
    }

    try {
        const ticket = await createTicket(apiToken, teamId, title, description, priority, labels);
        console.log(`\n📋 Next steps:`);
        console.log(`   1. Claim the ticket: tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh ${ticket.identifier}`);
        console.log(`   2. Start working on the implementation`);
    } catch (error) {
        console.error('Error creating ticket:', error.message);
        process.exit(1);
    }
}

main();
