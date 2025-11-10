#!/usr/bin/env node
/**
 * Update a Linear ticket (status, description, checklist, requirements)
 *
 * Consolidated update script supporting:
 *   - Status updates (todo, in-progress, done, backlog, canceled)
 *   - Description updates
 *   - Checklist additions
 *   - Requirement references
 *
 * Usage:
 *   node update-ticket.js --ticketId=CUR-XXX [options]
 *
 * Options:
 *   --ticketId=ID            Ticket identifier (required)
 *   --status=STATUS          Change status (todo, in-progress, done, backlog, canceled)
 *   --description=TEXT       Replace entire description
 *   --checklist=JSON         Add checklist (JSON array or markdown)
 *   --add-requirement=REQ-ID Add requirement reference
 */

const config = require('../lib/config');

/**
 * Parse command line arguments
 */
function parseArgs() {
    const args = {
        ticketId: null,
        status: null,
        description: null,
        checklist: null,
        addRequirement: null
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--ticketId=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--status=')) {
            args.status = arg.split('=')[1].toLowerCase();
        } else if (arg.startsWith('--description=')) {
            args.description = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--checklist=')) {
            args.checklist = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--add-requirement=')) {
            args.addRequirement = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            showHelp();
            process.exit(0);
        }
    }

    // Validation
    if (!args.ticketId) {
        console.error('Error: --ticketId is required');
        showHelp();
        process.exit(1);
    }

    if (!args.status && !args.description && !args.checklist && !args.addRequirement) {
        console.error('Error: At least one update option is required');
        showHelp();
        process.exit(1);
    }

    // Validate status if provided
    if (args.status) {
        const validStatuses = ['todo', 'in-progress', 'done', 'backlog', 'canceled'];
        if (!validStatuses.includes(args.status)) {
            console.error(`Error: Invalid status "${args.status}"`);
            console.error(`Valid options: ${validStatuses.join(', ')}`);
            process.exit(1);
        }
    }

    return args;
}

/**
 * Show help message
 */
function showHelp() {
    console.log(`
Update a Linear ticket

Usage:
  node update-ticket.js --ticketId=CUR-XXX [options]

Required:
  --ticketId=ID          Ticket identifier

Options:
  --status=STATUS        Change status (todo, in-progress, done, backlog, canceled)
  --description=TEXT     Replace entire description
  --checklist=JSON       Add checklist (JSON array or markdown)
  --add-requirement=ID   Add requirement reference (e.g., REQ-p00001)

Examples:
  # Update status
  node update-ticket.js --ticketId=CUR-240 --status=in-progress

  # Add checklist
  node update-ticket.js --ticketId=CUR-240 --checklist='- [ ] Task 1\\n- [ ] Task 2'

  # Add requirement reference
  node update-ticket.js --ticketId=CUR-240 --add-requirement=REQ-p00001

  # Multiple updates
  node update-ticket.js --ticketId=CUR-240 --status=done --add-requirement=REQ-p00001
`);
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
 * Get ticket with workflow states
 */
async function getTicketWithStates(token, apiEndpoint, ticketId) {
    const query = `
        query GetIssue($id: String!) {
            issue(id: $id) {
                id
                identifier
                title
                description
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

    const response = await fetch(apiEndpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': token,
        },
        body: JSON.stringify({
            query,
            variables: { id: ticketId }
        }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    return result.data?.issue;
}

/**
 * Update ticket
 */
async function updateTicket(token, apiEndpoint, issueId, updateInput) {
    const mutation = `
        mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
            issueUpdate(id: $id, input: $input) {
                success
                issue {
                    id
                    identifier
                    title
                    description
                    url
                    state {
                        name
                        type
                    }
                }
            }
        }
    `;

    const response = await fetch(apiEndpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': token,
        },
        body: JSON.stringify({
            query: mutation,
            variables: {
                id: issueId,
                input: updateInput
            }
        }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    return result.data?.issueUpdate;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();

    try {
        // Get configuration
        const token = config.getToken(true);
        const apiEndpoint = config.getApiEndpoint();

        // Fetch ticket
        console.log(`🔍 Fetching ticket ${args.ticketId}...`);
        const ticket = await getTicketWithStates(token, apiEndpoint, args.ticketId);

        if (!ticket) {
            throw new Error(`Ticket ${args.ticketId} not found`);
        }

        console.log(`📋 Ticket: ${ticket.identifier} - ${ticket.title}`);
        console.log(`📊 Current status: ${ticket.state.name} (${ticket.state.type})`);

        // Build update input
        const updateInput = {};

        // Handle status update
        if (args.status) {
            const targetType = getStateType(args.status);
            const targetState = ticket.team.states.nodes.find(state => state.type === targetType);

            if (!targetState) {
                console.error(`❌ No state found for type "${targetType}"`);
                console.error('Available states:');
                ticket.team.states.nodes.forEach(state => {
                    console.error(`  - ${state.name} (${state.type})`);
                });
                process.exit(1);
            }

            if (ticket.state.id === targetState.id) {
                console.log(`✅ Already in "${targetState.name}" status`);
            } else {
                updateInput.stateId = targetState.id;
                console.log(`🎯 Target status: ${targetState.name} (${targetType})`);
            }
        }

        // Handle description/checklist/requirement updates
        if (args.description || args.checklist || args.addRequirement) {
            let newDescription = args.description || ticket.description || '';

            // Add requirement reference
            if (args.addRequirement) {
                const reqLine = `**Requirement**: ${args.addRequirement}\n\n`;
                if (!newDescription.includes(args.addRequirement)) {
                    newDescription = reqLine + newDescription;
                    console.log(`📎 Adding requirement: ${args.addRequirement}`);
                } else {
                    console.log(`✅ Requirement ${args.addRequirement} already referenced`);
                }
            }

            // Add checklist
            if (args.checklist) {
                if (newDescription && !newDescription.endsWith('\n\n')) {
                    newDescription += '\n\n';
                }
                newDescription += '### Checklist\n' + args.checklist;
                console.log(`✅ Adding checklist`);
            }

            updateInput.description = newDescription;
        }

        // Perform update if there's anything to change
        if (Object.keys(updateInput).length === 0) {
            console.log('\n✅ No changes needed');
            return;
        }

        console.log('\n🔄 Updating ticket...');
        const result = await updateTicket(token, apiEndpoint, ticket.id, updateInput);

        if (result.success) {
            console.log(`\n✅ Successfully updated ${result.issue.identifier}`);
            if (updateInput.stateId) {
                console.log(`   Status: ${result.issue.state.name}`);
            }
            console.log(`   URL: ${result.issue.url}`);
        } else {
            throw new Error('Update failed');
        }

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        process.exit(1);
    }
}

// Run
main().catch(error => {
    console.error('Fatal error:', error.message);
    process.exit(1);
});
