#!/usr/bin/env node
/**
 * Fetch Linear tickets by label
 *
 * Usage:
 *   node fetch-tickets-by-label.js --token=<token> --label=<label-name>
 */

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// Parse command line arguments
function parseArgs() {
    const args = {
        token: null,
        label: null,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--token=')) {
            args.token = arg.split('=')[1];
        } else if (arg.startsWith('--label=')) {
            args.label = arg.split('=')[1];
        }
    }

    if (!args.token || !args.label) {
        console.error('Error: --token and --label are required');
        console.error('Usage: node fetch-tickets-by-label.js --token=<token> --label=<label-name>');
        process.exit(1);
    }

    return args;
}

async function fetchTicketsByLabel(apiToken, labelName) {
    const query = `
        query GetTicketsByLabel {
            issues(
                filter: {
                    labels: { name: { eq: "${labelName}" } }
                }
                first: 250
            ) {
                nodes {
                    id
                    identifier
                    title
                    description
                    url
                    priority
                    createdAt
                    updatedAt
                    state {
                        name
                        type
                    }
                    labels {
                        nodes {
                            name
                            color
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
        body: JSON.stringify({ query }),
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

async function main() {
    const args = parseArgs();

    const data = await fetchTicketsByLabel(args.token, args.label);

    const tickets = data.issues.nodes;

    if (!tickets || tickets.length === 0) {
        console.error(`No tickets found with label: ${args.label}`);
        process.exit(1);
    }

    console.log(JSON.stringify(tickets, null, 2));
}

main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
