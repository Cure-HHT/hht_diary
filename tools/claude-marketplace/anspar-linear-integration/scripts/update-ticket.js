#!/usr/bin/env node
/**
 * Update a Linear ticket (add checklist, update description, etc.)
 */

const config = require('./lib/config');

async function updateTicket() {
    // Parse command line arguments
    const args = process.argv.slice(2);
    let ticketId = '';
    let description = null;
    let addChecklist = null;
    let addRequirement = null;

    for (const arg of args) {
        if (arg.startsWith('--ticketId=')) {
            ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--description=')) {
            description = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--addChecklist=')) {
            addChecklist = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--addRequirement=')) {
            addRequirement = arg.split('=')[1];
        }
    }

    if (!ticketId) {
        console.error('❌ Ticket ID required: --ticketId=<identifier>');
        process.exit(1);
    }

    if (!description && !addChecklist && !addRequirement) {
        console.error('❌ Nothing to update. Provide --description, --addChecklist, or --addRequirement');
        process.exit(1);
    }

    // Get configuration
    const token = config.getToken(true);
    const apiEndpoint = config.getApiEndpoint();

    // First, get the current ticket
    const getQuery = `
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
        const getResponse = await fetch(apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({
                query: getQuery,
                variables: { id: ticketId }
            }),
        });

        if (!getResponse.ok) {
            throw new Error(`Linear API error: ${getResponse.status} ${getResponse.statusText}`);
        }

        const getResult = await getResponse.json();
        if (getResult.errors) {
            throw new Error(`Failed to get ticket: ${JSON.stringify(getResult.errors)}`);
        }

        const ticket = getResult.data?.issue;
        if (!ticket) {
            throw new Error(`Ticket ${ticketId} not found`);
        }

        // Build updated description
        let newDescription = description || ticket.description || '';

        // Prepend requirement reference if specified
        if (addRequirement) {
            const reqLine = `**Requirement**: ${addRequirement}\n\n`;
            // Check if requirement already exists in description
            if (!newDescription.includes(addRequirement)) {
                newDescription = reqLine + newDescription;
            }
        }

        if (addChecklist) {
            // Add checklist to the description
            if (newDescription && !newDescription.endsWith('\n\n')) {
                newDescription += '\n\n';
            }
            newDescription += '### Checklist\n' + addChecklist;
        }

        // Update the ticket
        const updateQuery = `
            mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
                issueUpdate(id: $id, input: $input) {
                    success
                    issue {
                        id
                        identifier
                        title
                        description
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
                    input: {
                        description: newDescription
                    }
                }
            }),
        });

        if (!updateResponse.ok) {
            throw new Error(`Linear API error: ${updateResponse.status} ${updateResponse.statusText}`);
        }

        const updateResult = await updateResponse.json();
        if (updateResult.errors) {
            throw new Error(`Failed to update ticket: ${JSON.stringify(updateResult.errors)}`);
        }

        if (updateResult.data?.issueUpdate?.success) {
            const updated = updateResult.data.issueUpdate.issue;
            console.log(`✅ Updated ticket ${updated.identifier}: ${updated.title}`);
            console.log(`   URL: ${updated.url}`);
        } else {
            throw new Error('Update failed for unknown reason');
        }

    } catch (error) {
        console.error(`❌ Update failed: ${error.message}`);
        process.exit(1);
    }
}

// Run update
updateTicket().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});