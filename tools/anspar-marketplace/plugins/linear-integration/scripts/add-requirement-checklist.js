#!/usr/bin/env node
/**
 * Add requirement-based implementation checklists to Linear tickets
 *
 * This is now a thin wrapper using the new helper modules
 *
 * Usage:
 *   node add-requirement-checklist.js --ticketId=<id> [options]
 */

const ticketFetcher = require('./lib/ticket-fetcher');
const ticketUpdater = require('./lib/ticket-updater');
const requirementProcessor = require('./lib/requirement-processor');
const checklistGenerator = require('./lib/checklist-generator');

// Parse command line arguments
function parseArgs() {
    const args = {
        ticketId: null,
        fromRequirement: false,
        requirement: null,
        includeAcceptance: false,
        includeSubsystems: false,
        includeChildren: false,
        includeTechnologies: false,
        dryRun: false,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--ticketId=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg.startsWith('--requirement=')) {
            args.requirement = arg.split('=')[1];
        } else if (arg === '--fromRequirement' || arg === '--from-requirement') {
            args.fromRequirement = true;
        } else if (arg === '--includeAcceptance' || arg === '--include-acceptance') {
            args.includeAcceptance = true;
        } else if (arg === '--includeSubsystems' || arg === '--include-subsystems') {
            args.includeSubsystems = true;
        } else if (arg === '--includeChildren' || arg === '--include-children') {
            args.includeChildren = true;
        } else if (arg === '--includeTechnologies' || arg === '--include-technologies') {
            args.includeTechnologies = true;
        } else if (arg === '--dry-run' || arg === '--dryRun') {
            args.dryRun = true;
        } else if (arg === '--help' || arg === '-h') {
            showHelp();
            process.exit(0);
        }
    }

    if (!args.ticketId) {
        console.error('❌ --ticketId is required');
        showHelp();
        process.exit(1);
    }

    return args;
}

function showHelp() {
    console.log(`
Add requirement-based checklist to a Linear ticket

Usage:
  node add-requirement-checklist.js --ticketId=<id> [options]

Required:
  --ticketId=ID        Linear ticket ID or identifier (e.g., CUR-312)

Options:
  --fromRequirement       Extract REQ from ticket description
  --requirement=REQ-xxx   Specify requirement explicitly
  --includeAcceptance     Include acceptance criteria as tasks
  --includeSubsystems     Include subsystem-specific tasks
  --includeChildren       Include sub-requirements
  --includeTechnologies   Include technology setup tasks
  --dry-run              Preview without updating ticket

Examples:
  # Add checklist from ticket's requirement
  node add-requirement-checklist.js --ticketId=CUR-312 --fromRequirement

  # Full checklist with all options
  node add-requirement-checklist.js \\
    --ticketId=CUR-312 \\
    --fromRequirement \\
    --includeAcceptance \\
    --includeSubsystems \\
    --includeChildren

  # Specific requirement
  node add-requirement-checklist.js \\
    --ticketId=CUR-312 \\
    --requirement=REQ-p00024
`);
}

async function main() {
    const args = parseArgs();

    try {
        // Get ticket details
        console.log(`\n📋 Processing ticket: ${args.ticketId}`);
        const ticket = await ticketFetcher.getTicketById(args.ticketId);

        if (!ticket) {
            throw new Error(`Ticket ${args.ticketId} not found`);
        }

        console.log(`   Title: ${ticket.title}`);

        // Determine which requirement to use
        let reqId = args.requirement;

        if (!reqId && args.fromRequirement) {
            // Extract from ticket description
            const requirements = ticketFetcher.extractRequirements(ticket.description);
            if (requirements.length > 0) {
                reqId = requirements[0];
                console.log(`   Found requirement: ${reqId}`);

                if (requirements.length > 1) {
                    console.log(`   ⚠️  Multiple requirements found, using first: ${requirements.join(', ')}`);
                }
            } else {
                console.error('❌ No requirement found in ticket description');
                console.error('   Make sure the ticket description contains a REQ-xxxxx reference');
                process.exit(1);
            }
        }

        if (!reqId) {
            console.error('❌ No requirement specified. Use --requirement or --fromRequirement');
            process.exit(1);
        }

        // Find the requirement
        // For REQ-d00027, prefer the "Development Environment and Tooling Setup" version
        const preferredTitle = reqId === 'REQ-d00027' ? 'Development Environment and Tooling Setup' : null;
        const requirement = requirementProcessor.findRequirement(reqId, preferredTitle);

        if (!requirement) {
            console.error(`❌ Requirement ${reqId} not found in spec files`);
            process.exit(1);
        }

        console.log(`   Requirement: ${requirement.title}`);
        console.log(`   Source: ${requirement.file}`);

        // Generate comprehensive checklist
        console.log('\n📝 Generating checklist...');

        const checklist = await checklistGenerator.generateFromRequirement(requirement, {
            includeAcceptance: args.includeAcceptance,
            includeSubsystems: args.includeSubsystems,
            includeChildren: args.includeChildren,
            includeTechnologies: args.includeTechnologies
        });

        // Format as markdown
        const checklistMarkdown = checklistGenerator.formatAsMarkdown(checklist);

        // Display preview
        console.log('\n📋 Generated Checklist:');
        console.log('------------------------');
        console.log(checklistMarkdown);
        console.log('------------------------');

        // Calculate effort estimate
        const effort = checklistGenerator.estimateEffort(checklist);
        console.log(`\n📊 Effort Estimate:`);
        console.log(`   Tasks: ${effort.totalTasks}`);
        console.log(`   Hours: ~${effort.estimatedHours}`);
        console.log(`   Days: ~${effort.estimatedDays}`);
        console.log(`   Complexity: ${effort.complexity}`);

        if (args.dryRun) {
            console.log('\n✅ Dry run complete (no changes made)');
            return;
        }

        // Update ticket with checklist
        console.log('\n📝 Updating ticket...');

        await ticketUpdater.addChecklist(ticket.id, checklistMarkdown, {
            title: `Implementation Checklist for ${reqId}`,
            append: true,
            silent: false
        });

        console.log(`\n✅ Ticket updated successfully!`);
        console.log(`   View ticket: ${ticket.url}`);

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);

        if (error.message.includes('token')) {
            console.error('\nMake sure your LINEAR_API_TOKEN is set:');
            console.error('  export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"');
        }

        process.exit(1);
    }
}

// Run
main().catch(error => {
    console.error('Fatal error:', error.message);
    process.exit(1);
});