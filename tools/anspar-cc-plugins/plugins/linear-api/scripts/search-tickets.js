#!/usr/bin/env node
/**
 * Search Linear tickets by requirement ID or keyword
 */

const config = require('./lib/config');

async function searchTickets() {
    // Parse command line arguments
    const args = process.argv.slice(2);
    let query = '';
    let format = 'summary';

    for (const arg of args) {
        if (arg.startsWith('--query=')) {
            query = arg.split('=')[1];
        } else if (arg.startsWith('--format=')) {
            format = arg.split('=')[1];
        }
    }

    if (!query) {
        console.error('❌ Query required: --query=<search term>');
        process.exit(1);
    }

    // Get configuration
    const token = config.getToken(true);
    const apiEndpoint = config.getApiEndpoint();

    // Search query using issues with filter
    // Note: Linear's issueSearch was deprecated. We now use issues query with filter.
    const graphqlQuery = `
        query SearchIssues($filter: IssueFilter!) {
            issues(filter: $filter, first: 50, orderBy: updatedAt) {
                nodes {
                    id
                    identifier
                    title
                    description
                    url
                    state {
                        name
                        type
                    }
                    project {
                        name
                    }
                    labels {
                        nodes {
                            name
                        }
                    }
                }
            }
        }
    `;

    try {
        // Create filter for searching in title and description
        // Linear's filter uses 'or' to search across multiple fields
        const filter = {
            or: [
                { title: { containsIgnoreCase: query } },
                { description: { containsIgnoreCase: query } }
            ]
        };

        const response = await fetch(apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token,
            },
            body: JSON.stringify({
                query: graphqlQuery,
                variables: { filter }
            }),
        });

        if (!response.ok) {
            throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();

        if (result.errors) {
            throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
        }

        const tickets = result.data?.issues?.nodes || [];

        if (format === 'json') {
            console.log(JSON.stringify(tickets, null, 2));
        } else {
            if (tickets.length === 0) {
                console.log(`No tickets found for query: "${query}"`);
            } else {
                console.log(`Found ${tickets.length} ticket(s) for query: "${query}"
`);
                tickets.forEach(ticket => {
                    console.log(`${ticket.identifier}: ${ticket.title}`);
                    console.log(`  Status: ${ticket.state.name}`);
                    console.log(`  URL: ${ticket.url}`);
                    if (ticket.project) {
                        console.log(`  Project: ${ticket.project.name}`);
                    }

                    // Check for requirement references
                    if (ticket.description) {
                        const reqMatches = ticket.description.match(/REQ-[pdo]\d{5}/g);
                        if (reqMatches) {
                            console.log(`  Requirements: ${[...new Set(reqMatches)].join(', ')}`);
                        }
                    }
                    console.log('');
                });
            }
        }

    } catch (error) {
        console.error(`❌ Search failed: ${error.message}`);
        process.exit(1);
    }
}

// Run search
searchTickets().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});