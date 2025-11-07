#!/usr/bin/env node
/**
 * Fetch Linear ticket details by ID or current active ticket
 *
 * IMPLEMENTS REQUIREMENTS:
 *   (Supporting tool for project management - no specific REQ-* yet)
 *
 * Usage:
 *   node ticket-fetch.js                  # Fetch current active ticket
 *   node ticket-fetch.js CUR-240          # Fetch specific ticket
 *   node ticket-fetch.js CUR-240 CUR-241  # Fetch multiple tickets
 */

const fs = require('fs');
const path = require('path');
const ticketFetcher = require('./lib/ticket-fetcher');
const { validateEnvironment } = require('./lib/env-validation');

/**
 * Get the current active ticket ID from workflow state
 * @returns {string|null} Ticket ID or null if not found
 */
function getCurrentTicketId() {
    try {
        // Find .git directory by traversing up from current directory
        let currentDir = process.cwd();
        let gitDir = null;

        while (currentDir !== '/') {
            const testPath = path.join(currentDir, '.git');
            if (fs.existsSync(testPath)) {
                gitDir = testPath;
                break;
            }
            currentDir = path.dirname(currentDir);
        }

        if (!gitDir) {
            return null;
        }

        const workflowStatePath = path.join(gitDir, 'WORKFLOW_STATE');

        if (!fs.existsSync(workflowStatePath)) {
            return null;
        }

        const stateContent = fs.readFileSync(workflowStatePath, 'utf8');
        const state = JSON.parse(stateContent);

        return state.activeTicket?.id || null;
    } catch (error) {
        console.error('Warning: Could not read workflow state:', error.message);
        return null;
    }
}

/**
 * Display a single ticket in detailed format
 * @param {Object} ticket - Ticket object
 */
function displayTicketDetails(ticket) {
    console.log('\n' + '='.repeat(80));
    console.log(`${ticket.identifier}: ${ticket.title}`);
    console.log('='.repeat(80));
    console.log();

    // Basic info
    console.log('BASIC INFORMATION:');
    console.log(`  Identifier:    ${ticket.identifier}`);
    console.log(`  Title:         ${ticket.title}`);
    console.log(`  Status:        ${ticket.state?.name || 'Unknown'} (${ticket.state?.type || 'unknown'})`);
    console.log(`  URL:           ${ticket.url}`);
    console.log();

    // Priority and assignment
    console.log('PRIORITY & ASSIGNMENT:');
    if (ticket.priorityLabel) {
        console.log(`  Priority:      ${ticket.priority} - ${ticket.priorityLabel}`);
    } else {
        console.log(`  Priority:      ${ticket.priority}`);
    }

    if (ticket.assignee) {
        console.log(`  Assignee:      ${ticket.assignee.name} <${ticket.assignee.email}>`);
    } else {
        console.log(`  Assignee:      Unassigned`);
    }

    if (ticket.creator) {
        console.log(`  Creator:       ${ticket.creator.name} <${ticket.creator.email}>`);
    }
    console.log();

    // Team and project
    console.log('ORGANIZATION:');
    if (ticket.team) {
        console.log(`  Team:          ${ticket.team.name} (${ticket.team.key})`);
    }
    if (ticket.project) {
        console.log(`  Project:       ${ticket.project.name}`);
    }
    console.log();

    // Labels
    if (ticket.labels?.nodes?.length > 0) {
        console.log('LABELS:');
        for (const label of ticket.labels.nodes) {
            const desc = label.description ? ` - ${label.description}` : '';
            console.log(`  - ${label.name}${desc}`);
        }
        console.log();
    }

    // Parent/children
    if (ticket.parent) {
        console.log('PARENT TICKET:');
        console.log(`  ${ticket.parent.identifier}: ${ticket.parent.title}`);
        console.log();
    }

    if (ticket.children?.nodes?.length > 0) {
        console.log('SUBTASKS:');
        for (const child of ticket.children.nodes) {
            const status = child.state?.type || 'unknown';
            console.log(`  - ${child.identifier}: ${child.title} [${status}]`);
        }
        console.log();
    }

    // Requirements
    const requirements = ticketFetcher.extractRequirements(ticket.description);
    if (requirements.length > 0) {
        console.log('REQUIREMENTS:');
        for (const req of requirements) {
            console.log(`  - ${req}`);
        }
        console.log();
    }

    // Dates
    console.log('TIMELINE:');
    console.log(`  Created:       ${new Date(ticket.createdAt).toLocaleString()}`);
    console.log(`  Updated:       ${new Date(ticket.updatedAt).toLocaleString()}`);

    if (ticket.startedAt) {
        console.log(`  Started:       ${new Date(ticket.startedAt).toLocaleString()}`);
    }
    if (ticket.dueDate) {
        console.log(`  Due:           ${new Date(ticket.dueDate).toLocaleDateString()}`);
    }
    if (ticket.completedAt) {
        console.log(`  Completed:     ${new Date(ticket.completedAt).toLocaleString()}`);
    }
    if (ticket.canceledAt) {
        console.log(`  Canceled:      ${new Date(ticket.canceledAt).toLocaleString()}`);
    }
    console.log();

    // Description
    if (ticket.description) {
        console.log('DESCRIPTION:');
        console.log('-'.repeat(80));
        console.log(ticket.description);
        console.log('-'.repeat(80));
        console.log();
    }

    // Comments
    if (ticket.comments?.nodes?.length > 0) {
        console.log('RECENT COMMENTS:');
        console.log('-'.repeat(80));
        const displayComments = ticket.comments.nodes.slice(0, 5);
        for (const comment of displayComments) {
            const date = new Date(comment.createdAt).toLocaleString();
            console.log(`[${date}] ${comment.user?.name || 'Unknown'}:`);
            console.log(comment.body);
            console.log();
        }
        if (ticket.comments.nodes.length > 5) {
            console.log(`... and ${ticket.comments.nodes.length - 5} more comments`);
        }
        console.log('-'.repeat(80));
        console.log();
    }
}

/**
 * Main function
 */
async function main() {
    try {
        // Validate environment (requires LINEAR_API_TOKEN)
        await validateEnvironment({
            requireToken: true,
            requireTeamId: false,
            autoDiscover: false,
            silent: true
        });

        const args = process.argv.slice(2);
        let ticketIds = [];

        // Determine which tickets to fetch
        if (args.length === 0) {
            // No arguments - fetch current active ticket
            const currentTicketId = getCurrentTicketId();

            if (!currentTicketId) {
                console.error('Error: No active ticket found in workflow state.');
                console.error('Either claim a ticket first, or provide ticket ID(s) as arguments.');
                console.error('\nUsage:');
                console.error('  node ticket-fetch.js                # Fetch current active ticket');
                console.error('  node ticket-fetch.js CUR-240        # Fetch specific ticket');
                console.error('  node ticket-fetch.js CUR-240 CUR-241  # Fetch multiple tickets');
                process.exit(1);
            }

            ticketIds = [currentTicketId];
            console.error(`Fetching current active ticket: ${currentTicketId}...`);
        } else {
            // Arguments provided - use them as ticket IDs
            ticketIds = args;
            console.error(`Fetching ${ticketIds.length} ticket(s)...`);
        }

        // Fetch and display each ticket
        let successCount = 0;
        let failCount = 0;

        for (const ticketId of ticketIds) {
            try {
                const ticket = await ticketFetcher.getTicketById(ticketId);

                if (!ticket) {
                    console.error(`\nError: Ticket '${ticketId}' not found.`);
                    failCount++;
                    continue;
                }

                displayTicketDetails(ticket);
                successCount++;
            } catch (error) {
                console.error(`\nError fetching ticket '${ticketId}':`, error.message);
                failCount++;
            }
        }

        // Summary
        if (ticketIds.length > 1) {
            console.log('='.repeat(80));
            console.log(`SUMMARY: ${successCount} fetched, ${failCount} failed`);
            console.log('='.repeat(80));
        }

        // Exit with error if any tickets failed
        if (failCount > 0) {
            process.exit(1);
        }

    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

main();
