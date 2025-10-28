#!/usr/bin/env node
/**
 * Update Linear ticket status (Todo, In Progress, Done, Backlog, Canceled)
 *
 * Usage:
 *   node update-ticket-status.js --token=<token> --ticket-id=<id> --status=<status>
 *
 * Status options:
 *   - todo, in-progress, done, backlog, canceled
 */

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// Parse command line arguments
function parseArgs() {
    const args = {
        token: null,
        ticketId: null,
        status: null,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--token=')) {
            args.token = arg.split('=')[1];
        } else if (arg.startsWith('--ticket-id=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--status=')) {
            args.status = arg.split('=')[1].toLowerCase();
        }
    }

    if (!args.token || !args.ticketId || !args.status) {
        console.error('Error: --token, --ticket-id, and --status are required');
        console.error('');
        console.error('Usage: node update-ticket-status.js --token=<token> --ticket-id=<ticket-id> --status=<status>');
        console.error('');
        console.error('Status options: todo, in-progress, done, backlog, canceled');
        console.error('');
        console.error('Example: node update-ticket-status.js --token=lin_api_xxx --ticket-id=CUR-127 --status=done');
        process.exit(1);
    }

    // Validate status
    const validStatuses = ['todo', 'in-progress', 'done', 'backlog', 'canceled'];
    if (!validStatuses.includes(args.status)) {
        console.error(`Error: Invalid status "${args.status}"`);
        console.error(`Valid options: ${validStatuses.join(', ')}`);
        process.exit(1);
    }

    return args;
}

/**
 * Get workflow states for the team
 */
async function getWorkflowStates(apiToken, ticketId) {
    const query = `
        query GetIssueStates($issueId: String!) {
            issue(id: $issueId) {
                id
                identifier
                title
                state {
                    id
                    name
                    type
                }
                team {
                    id
                    states {
                        nodes {
                            id
                            name
                            type
                        }
                    }
                }
            }
        }
    `;

    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': apiToken,
        },
        body: JSON.stringify({
            query,
            variables: { issueId: ticketId }
        }),
    });

    const result = await response.json();

    if (result.errors) {
        console.error('GraphQL errors:', JSON.stringify(result.errors, null, 2));
        throw new Error('Failed to fetch workflow states: ' + JSON.stringify(result.errors, null, 2));
    }

    return result.data.issue;
}

/**
 * Map status name to Linear state type
 */
function getStateType(status) {
    const mapping = {
        'backlog': 'backlog',
        'todo': 'unstarted',
        'in-progress': 'started',
        'done': 'completed',
        'canceled': 'canceled'
    };
    return mapping[status];
}

/**
 * Update ticket status
 */
async function updateTicketStatus(apiToken, issueId, stateId) {
    const mutation = `
        mutation UpdateIssue($issueId: String!, $stateId: String!) {
            issueUpdate(
                id: $issueId,
                input: {
                    stateId: $stateId
                }
            ) {
                success
                issue {
                    id
                    identifier
                    title
                    state {
                        name
                        type
                    }
                }
            }
        }
    `;

    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': apiToken,
        },
        body: JSON.stringify({
            query: mutation,
            variables: {
                issueId,
                stateId
            }
        }),
    });

    const result = await response.json();

    if (result.errors) {
        console.error('GraphQL errors:', JSON.stringify(result.errors, null, 2));
        throw new Error('Failed to update issue status');
    }

    return result.data.issueUpdate;
}

/**
 * Main execution
 */
async function main() {
    const args = parseArgs();

    console.log(`🔍 Fetching issue ${args.ticketId}...`);

    // Get issue and available states
    const issue = await getWorkflowStates(args.token, args.ticketId);

    console.log(`📋 Issue: ${issue.identifier} - ${issue.title}`);
    console.log(`📊 Current status: ${issue.state.name} (${issue.state.type})`);

    // Find matching state by type
    const targetType = getStateType(args.status);
    const targetState = issue.team.states.nodes.find(state => state.type === targetType);

    if (!targetState) {
        console.error(`❌ No state found for type "${targetType}"`);
        console.error('Available states:');
        issue.team.states.nodes.forEach(state => {
            console.error(`  - ${state.name} (${state.type})`);
        });
        process.exit(1);
    }

    console.log(`🎯 Target status: ${targetState.name} (${targetState.type})`);

    // Check if already in target state
    if (issue.state.id === targetState.id) {
        console.log(`✅ Issue is already in "${targetState.name}" status`);
        return;
    }

    // Update status
    console.log(`🔄 Updating status...`);
    const result = await updateTicketStatus(args.token, issue.id, targetState.id);

    if (result.success) {
        console.log(`✅ Successfully updated ${result.issue.identifier} to "${result.issue.state.name}"`);
    } else {
        console.error('❌ Failed to update issue status');
        process.exit(1);
    }
}

// Run main function
main().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});
