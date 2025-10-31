#!/usr/bin/env node
/**
 * List all available labels in the Linear workspace
 */

const config = require('./lib/config');

// Parse command line arguments
function parseArgs() {
    const args = {
        filter: null,
        format: 'list'  // 'list' or 'json'
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--filter=')) {
            args.filter = arg.split('=')[1];
        } else if (arg.startsWith('--format=')) {
            args.format = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            console.log('Usage: node list-labels.js [options]');
            console.log('Options:');
            console.log('  --filter=PREFIX  Filter labels by prefix (e.g., "ai:")');
            console.log('  --format=FORMAT  Output format: list (default) or json');
            process.exit(0);
        }
    }

    return args;
}

async function fetchLabels() {
    const args = parseArgs();
    const token = config.getToken(true);
    const apiEndpoint = config.getApiEndpoint();

    // Get team ID with auto-discovery
    let teamId = config.getTeamId(false); // Don't exit on failure

    if (!teamId) {
        // Auto-discover team ID
        console.log('⚡ LINEAR_TEAM_ID not set, auto-discovering...');

        const teamsQuery = `
            query {
                viewer {
                    teams {
                        nodes {
                            id
                            name
                            key
                        }
                    }
                }
            }
        `;

        const teamsResponse = await fetch(apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({ query: teamsQuery }),
        });

        const teamsResult = await teamsResponse.json();
        const teams = teamsResult.data?.viewer?.teams?.nodes || [];

        if (teams.length === 0) {
            throw new Error('No teams found for this API token');
        }

        teamId = teams[0].id;
        console.log(`  Found team: ${teams[0].name} (${teams[0].key})`);
        console.log(`✓ Successfully discovered LINEAR_TEAM_ID\n`);
    }

    const query = `
        query GetLabels($teamId: String!) {
            team(id: $teamId) {
                labels {
                    nodes {
                        id
                        name
                        description
                        color
                    }
                }
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
                query,
                variables: { teamId }
            }),
        });

        if (!response.ok) {
            throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();
        if (result.errors) {
            throw new Error(`GraphQL errors: ${JSON.stringify(result.errors)}`);
        }

        let labels = result.data?.team?.labels?.nodes || [];

        // Apply filter if specified
        if (args.filter) {
            labels = labels.filter(label =>
                label.name.toLowerCase().startsWith(args.filter.toLowerCase())
            );
        }

        // Sort labels by name
        labels.sort((a, b) => a.name.localeCompare(b.name));

        // Output in requested format
        if (args.format === 'json') {
            console.log(JSON.stringify(labels, null, 2));
        } else {
            if (labels.length === 0) {
                console.log(args.filter
                    ? `No labels found with prefix "${args.filter}"`
                    : 'No labels found');
            } else {
                console.log('\n📏 Available Linear labels:');
                console.log('━'.repeat(50));

                for (const label of labels) {
                    const description = label.description ? ` - ${label.description}` : '';
                    const color = label.color ? ` [${label.color}]` : '';
                    console.log(`  ${label.name}${description}${color}`);
                }

                console.log('━'.repeat(50));
                console.log(`Total: ${labels.length} label${labels.length !== 1 ? 's' : ''}\n`);

                if (!args.filter) {
                    console.log('💡 Tip: Use --filter="prefix" to filter labels');
                    console.log('   Example: --filter="ai:" to see only AI-related labels\n');
                }
            }
        }

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        process.exit(1);
    }
}

// Run
fetchLabels().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});