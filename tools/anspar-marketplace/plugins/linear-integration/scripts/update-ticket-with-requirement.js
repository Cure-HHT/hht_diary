#!/usr/bin/env node
/**
 * Update an existing Linear ticket to add requirement reference
 *
 * Usage:
 *   node update-ticket-with-requirement.js --token=<token> --ticket-id=<id> --req-id=<req>
 */

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';
const reqLocator = require('./lib/req-locator');

// Parse command line arguments
function parseArgs() {
    const args = {
        token: null,
        ticketId: null,
        reqId: null,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--token=')) {
            args.token = arg.split('=')[1];
        } else if (arg.startsWith('--ticket-id=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--req-id=')) {
            args.reqId = arg.split('=')[1];
        }
    }

    if (!args.token || !args.ticketId || !args.reqId) {
        console.error('Error: --token, --ticket-id, and --req-id are required');
        console.error('');
        console.error('Usage: node update-ticket-with-requirement.js --token=<token> --ticket-id=<ticket-id> --req-id=<req-id>');
        console.error('');
        console.error('Example: node update-ticket-with-requirement.js --token=YOUR_LINEAR_TOKEN --ticket-id=CUR-92 --req-id=p00015');
        process.exit(1);
    }

    return args;
}

/**
 * Execute GraphQL mutation against Linear API
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
 * Get issue by identifier
 */
async function getIssue(apiToken, identifier) {
    const query = `
        query GetIssue($identifier: String!) {
            issue(id: $identifier) {
                id
                identifier
                title
                description
                url
            }
        }
    `;

    const data = await executeMutation(apiToken, query, { identifier });
    return data.issue;
}

/**
 * Update issue description
 */
async function updateIssue(apiToken, issueId, description) {
    const mutation = `
        mutation UpdateIssue($issueId: String!, $description: String!) {
            issueUpdate(id: $issueId, input: {
                description: $description
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

    const data = await executeMutation(apiToken, mutation, { issueId, description });
    return data.issueUpdate;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();

    console.log('================================================================================');
    console.log('UPDATE LINEAR TICKET WITH REQUIREMENT REFERENCE');
    console.log('================================================================================');
    console.log('');

    try {
        // Get existing issue
        console.log(`Fetching ticket ${args.ticketId}...`);
        const issue = await getIssue(args.token, args.ticketId);

        if (!issue) {
            console.error(`Error: Ticket ${args.ticketId} not found`);
            process.exit(1);
        }

        console.log(`Found: ${issue.title}`);
        console.log('');
        console.log('Current description:');
        console.log('---');
        console.log(issue.description || '(empty)');
        console.log('---');
        console.log('');

        // Find requirement location and build formatted link
        console.log(`Looking up REQ-${args.reqId} in spec/...`);
        const reqLocation = await reqLocator.findReqLocation(args.reqId);

        const reqReference = reqLocation
            ? reqLocator.formatReqLink(args.reqId, reqLocation.file, reqLocation.anchor, reqLocation.title)
            : `Requirement: REQ-${args.reqId} (location not found in spec/)`;

        let newDescription;
        if (issue.description) {
            // Check if requirement already exists
            if (issue.description.includes(`REQ-${args.reqId}`)) {
                console.log(`✅ Ticket already references REQ-${args.reqId}`);
                console.log('No update needed.');
                return;
            }

            // Prepend requirement reference
            newDescription = `${reqReference}\n\n---\n\n${issue.description}`;
        } else {
            newDescription = reqReference;
        }

        console.log('New description:');
        console.log('---');
        console.log(newDescription);
        console.log('---');
        console.log('');

        // Update the issue
        console.log('Updating ticket...');
        const result = await updateIssue(args.token, issue.id, newDescription);

        if (result.success) {
            console.log(`✅ Successfully updated ${result.issue.identifier}`);
            console.log(`   ${result.issue.url}`);
        } else {
            console.log(`❌ Failed to update ticket`);
            process.exit(1);
        }

    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }

    console.log('');
    console.log('================================================================================');
    console.log('DONE');
    console.log('================================================================================');
}

// Run
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
