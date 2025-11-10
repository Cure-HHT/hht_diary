#!/usr/bin/env node
/**
 * Create Linear Verification Ticket for Changed Requirement
 *
 * Creates a ticket to verify that implementation matches a requirement
 * that has been modified. Designed to integrate with requirement tracking
 * system in simple-requirements plugin.
 *
 * Usage:
 *   # From changed requirement JSON:
 *   node create-verification.js '{"req_id":"d00027","old_hash":"abc123","new_hash":"def456","title":"...","file":"..."}'
 *
 *   # From file:
 *   node create-verification.js --input changed-req.json
 *
 *   # Interactive:
 *   node create-verification.js --req-id d00027 --old-hash abc123 --new-hash def456
 *
 * Output:
 *   Ticket URL and identifier for tracking
 */

const fs = require('fs');
const ticketCreator = require('../../linear-api/lib/ticket-creator');
const reqLocator = require('../../requirement-traceability/lib/req-locator');

/**
 * Parse command line arguments
 */
function parseArgs() {
    const args = {
        input: null,
        reqId: null,
        oldHash: null,
        newHash: null,
        reqJson: null,
        priority: 'high', // Changed requirements are high priority by default
        assignee: null
    };

    // Check if first arg is JSON (for pipe usage)
    if (process.argv[2] && !process.argv[2].startsWith('--')) {
        try {
            args.reqJson = JSON.parse(process.argv[2]);
            return args;
        } catch (error) {
            // Not JSON, continue parsing as flags
        }
    }

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--input=')) {
            args.input = arg.split('=')[1];
        } else if (arg.startsWith('--req-id=')) {
            args.reqId = arg.split('=')[1];
        } else if (arg.startsWith('--old-hash=')) {
            args.oldHash = arg.split('=')[1];
        } else if (arg.startsWith('--new-hash=')) {
            args.newHash = arg.split('=')[1];
        } else if (arg.startsWith('--priority=')) {
            args.priority = arg.split('=')[1];
        } else if (arg.startsWith('--assignee=')) {
            args.assignee = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            showHelp();
            process.exit(0);
        }
    }

    // Load from input file if specified
    if (args.input) {
        try {
            args.reqJson = JSON.parse(fs.readFileSync(args.input, 'utf-8'));
        } catch (error) {
            console.error(`Error reading input file: ${error.message}`);
            process.exit(1);
        }
    }

    return args;
}

function showHelp() {
    console.log(`
Create Linear verification ticket for changed requirement

Usage:
  # From JSON string (for piping):
  node create-verification.js '{"req_id":"d00027",...}'

  # From file:
  node create-verification.js --input changed-req.json

  # Interactive:
  node create-verification.js --req-id d00027 --old-hash abc123 --new-hash def456

Options:
  --input=FILE       JSON file with requirement change data
  --req-id=ID        Requirement ID (e.g., d00027)
  --old-hash=HASH    Previous hash value
  --new-hash=HASH    Current hash value
  --priority=VALUE   Priority (default: high)
  --assignee=EMAIL   Assignee email or ID

Expected JSON format:
  {
    "req_id": "d00027",
    "old_hash": "abc12345",
    "new_hash": "def67890",
    "file": "dev-database.md",
    "title": "Requirement Title"
  }

Examples:
  # From detect-changes.py output:
  echo '{"req_id":"d00027",...}' | node create-verification.js

  # From file:
  node create-verification.js --input /tmp/changed-req.json

  # Manual creation:
  node create-verification.js --req-id d00027 --old-hash abc123 --new-hash def456
`);
}

/**
 * Build ticket title from requirement data
 */
function buildTicketTitle(reqData) {
    return `[Verification] REQ-${reqData.req_id}: ${reqData.title}`;
}

/**
 * Build ticket description from requirement data
 */
async function buildTicketDescription(reqData) {
    const lines = [];

    lines.push('## Requirement Change Detected');
    lines.push('');
    lines.push('A requirement has been modified and needs verification that implementations still satisfy it.');
    lines.push('');

    // Find requirement location and build GitHub link
    const reqLocation = await reqLocator.findReqLocation(reqData.req_id);
    const reqLink = reqLocation
        ? reqLocator.formatReqLink(reqData.req_id, reqLocation.file, reqLocation.anchor)
        : `REQ-${reqData.req_id}`;

    lines.push('### Changed Requirement');
    lines.push(`- **ID**: ${reqLink}`);
    lines.push(`- **Title**: ${reqData.title}`);
    lines.push(`- **File**: \`spec/${reqData.file}\``);
    lines.push(`- **Hash Change**: \`${reqData.old_hash}\` → \`${reqData.new_hash}\``);
    lines.push('');

    lines.push('### Verification Steps');
    lines.push('');
    lines.push('1. **Review Requirement**');
    lines.push(`   \`\`\`bash`);
    lines.push(`   # View full requirement text:`);
    lines.push(`   python3 tools/anspar-cc-plugins/plugins/simple-requirements/scripts/get-requirement.py ${reqData.req_id}`);
    lines.push(`   \`\`\``);
    lines.push('');

    lines.push('2. **Find Implementations**');
    lines.push(`   \`\`\`bash`);
    lines.push(`   # Search for REQ references in code:`);
    lines.push(`   git grep -n "REQ-${reqData.req_id}"`);
    lines.push(`   \`\`\``);
    lines.push('');

    lines.push('3. **Verify Compliance**');
    lines.push('   - Review each implementation against updated requirement');
    lines.push('   - Update code if requirement changed significantly');
    lines.push('   - Update tests to match new requirement');
    lines.push('   - Verify all acceptance criteria are met');
    lines.push('');

    lines.push('4. **Mark as Verified**');
    lines.push(`   \`\`\`bash`);
    lines.push(`   # After verification, remove from tracking:`);
    lines.push(`   python3 tools/anspar-cc-plugins/plugins/simple-requirements/scripts/mark-verified.py ${reqData.req_id}`);
    lines.push(`   \`\`\``);
    lines.push('');

    lines.push('### Context');
    lines.push('');
    lines.push('This ticket was automatically created by the requirement tracking system when the');
    lines.push('requirement was modified. The implementation may need to be updated to match the');
    lines.push('new requirement specification.');
    lines.push('');

    lines.push('### Related');
    lines.push(`- Requirement file: \`spec/${reqData.file}\``);
    lines.push(`- Tracking file: \`untracked-notes/outdated-implementations.json\``);

    return lines.join('\n');
}

/**
 * Validate requirement data
 */
function validateReqData(reqData) {
    if (!reqData.req_id) {
        throw new Error('Missing required field: req_id');
    }
    if (!reqData.old_hash) {
        throw new Error('Missing required field: old_hash');
    }
    if (!reqData.new_hash) {
        throw new Error('Missing required field: new_hash');
    }
    if (!reqData.title) {
        throw new Error('Missing required field: title');
    }
    if (!reqData.file) {
        throw new Error('Missing required field: file');
    }
}

/**
 * Main execution
 */
async function main() {
    const args = parseArgs();

    // Build requirement data from args
    let reqData = args.reqJson;

    if (!reqData && args.reqId && args.oldHash && args.newHash) {
        // Build from individual args
        reqData = {
            req_id: args.reqId.replace(/^REQ-/i, ''),
            old_hash: args.oldHash,
            new_hash: args.newHash,
            title: `Requirement ${args.reqId}`,
            file: 'unknown.md'
        };

        console.warn('⚠️  Warning: Manual mode - title and file are placeholders');
        console.warn('   Use JSON input for full metadata');
    }

    if (!reqData) {
        console.error('❌ Error: No requirement data provided');
        console.error('   Use --help for usage information');
        process.exit(1);
    }

    try {
        // Validate data
        validateReqData(reqData);

        console.log(`\n📋 Creating verification ticket for REQ-${reqData.req_id}...`);

        // Build ticket data
        const title = buildTicketTitle(reqData);
        const description = await buildTicketDescription(reqData);

        // Create the ticket
        const ticket = await ticketCreator.createTicket({
            title: title,
            description: description,
            priority: args.priority,
            labels: ['verification', 'requirement-change', `REQ-${reqData.req_id}`],
            assigneeId: args.assignee
        }, {
            silent: false,
            returnFull: false
        });

        // Output result (can be parsed by tracking system)
        const result = {
            req_id: reqData.req_id,
            ticket_id: ticket.id,
            ticket_identifier: ticket.identifier,
            ticket_url: ticket.url,
            created_at: new Date().toISOString()
        };

        console.log('\n✅ Verification ticket created successfully!');
        console.log(`   Ticket: ${ticket.identifier}`);
        console.log(`   URL: ${ticket.url}`);
        console.log('');
        console.log('📤 JSON output (for tracking system):');
        console.log(JSON.stringify(result, null, 2));

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

// Run if called directly
if (require.main === module) {
    main().catch(error => {
        console.error('Fatal error:', error.message);
        process.exit(1);
    });
}

module.exports = { buildTicketTitle, buildTicketDescription };
