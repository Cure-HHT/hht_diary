#!/usr/bin/env node
/**
 * Create a single Linear ticket
 *
 * This is now a thin wrapper around the ticket-creator module
 *
 * Usage:
 *   node create-single-ticket.js --title="Title" --description="Description" [options]
 *
 * Options:
 *   --title           Ticket title (required)
 *   --description     Ticket description
 *   --description-file  Read description from file
 *   --priority        Priority (0-4, urgent, high, normal, low, P1-P4)
 *   --labels          Comma-separated label names
 *   --project         Project name or ID
 *   --assignee        Assignee email or ID
 */

const fs = require('fs');
const ticketCreator = require('./lib/ticket-creator');

// Parse command line arguments
function parseArgs() {
    const args = {
        title: '',
        description: '',
        descriptionFile: '',
        priority: null,
        labels: [],
        projectId: null,
        assigneeId: null
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--title=')) {
            args.title = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--description=')) {
            args.description = arg.split('=').slice(1).join('=');
        } else if (arg.startsWith('--description-file=')) {
            args.descriptionFile = arg.split('=')[1];
        } else if (arg.startsWith('--priority=')) {
            args.priority = arg.split('=')[1];
        } else if (arg.startsWith('--labels=')) {
            args.labels = arg.split('=')[1].split(',').map(l => l.trim()).filter(l => l);
        } else if (arg.startsWith('--project=')) {
            args.projectId = arg.split('=')[1];
        } else if (arg.startsWith('--assignee=')) {
            args.assigneeId = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            showHelp();
            process.exit(0);
        }
    }

    // Read description from file if specified
    if (args.descriptionFile && !args.description) {
        try {
            args.description = fs.readFileSync(args.descriptionFile, 'utf-8');
        } catch (error) {
            console.error(`Error reading description file: ${error.message}`);
            process.exit(1);
        }
    }

    // Validate required fields
    if (!args.title) {
        console.error('Error: --title is required');
        showHelp();
        process.exit(1);
    }

    return args;
}

function showHelp() {
    console.log(`
Create a Linear ticket

Usage:
  node create-single-ticket.js --title="Title" [options]

Required:
  --title="..."        Ticket title

Optional:
  --description="..."     Ticket description
  --description-file=FILE Read description from file
  --priority=VALUE        Priority (see below)
  --labels="a,b,c"        Comma-separated label names
  --project=ID            Project ID
  --assignee=ID           Assignee ID or email

Priority values:
  Numbers: 0=None, 1=Urgent, 2=High, 3=Normal, 4=Low
  Names: urgent, high, normal, medium, low, none
  P-notation: P0, P1, P2, P3, P4

Examples:
  # Simple ticket
  node create-single-ticket.js --title="Fix login bug" --priority=high

  # With description from file
  node create-single-ticket.js \\
    --title="Implement new feature" \\
    --description-file=feature-spec.md \\
    --labels="enhancement,frontend" \\
    --priority=P2

  # Full example
  node create-single-ticket.js \\
    --title="Update API documentation" \\
    --description="Need to document new endpoints" \\
    --labels="documentation,api" \\
    --priority=normal
`);
}

async function main() {
    const args = parseArgs();

    try {
        // Create the ticket using our helper
        const ticket = await ticketCreator.createTicket({
            title: args.title,
            description: args.description,
            priority: args.priority,
            labels: args.labels,
            projectId: args.projectId,
            assigneeId: args.assigneeId
        }, {
            silent: false,
            returnFull: false
        });

        // Show next steps
        console.log(`\n📋 Next steps:`);
        console.log(`   1. View ticket: ${ticket.url}`);
        console.log(`   2. Claim for work: tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh ${ticket.identifier}`);

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);

        // Provide helpful error messages
        if (error.message.includes('token')) {
            console.error('\nMake sure your LINEAR_API_TOKEN is set:');
            console.error('  export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"');
        }

        if (error.message.includes('team')) {
            console.error('\nRun the initialization to discover your team:');
            console.error('  node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-config.js');
        }

        process.exit(1);
    }
}

// Run
main().catch(error => {
    console.error('Fatal error:', error.message);
    process.exit(1);
});