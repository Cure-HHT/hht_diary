#!/usr/bin/env node
/**
 * List all available labels in the Linear workspace
 *
 * This is a thin wrapper around the label-manager module
 */

const labelManager = require('../lib/label-manager');

// Parse command line arguments
function parseArgs() {
    const args = {
        filter: null,
        format: 'list'  // 'list' or 'json'
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--filter=')) {
            args.filter = arg.split('=')[1];
        } else if (arg.startsWith('--format=')) {
            args.format = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            console.log('Usage: node list-labels.js [options]');
            console.log('Options:');
            console.log('  --filter=PREFIX  Filter labels by prefix (e.g., "ai:")');
            console.log('  --format=FORMAT  Output format: list (default) or json');
            process.exit(0);
        }
    }

    return args;
}

async function main() {
    const args = parseArgs();

    try {
        // Fetch labels using the manager
        let labels;
        if (args.filter) {
            labels = await labelManager.getLabelsByPrefix(args.filter);
        } else {
            labels = await labelManager.getAllLabels();
        }

        // Display results
        if (args.format === 'json') {
            console.log(JSON.stringify(labels, null, 2));
        } else {
            labelManager.displayLabels(labels, {
                showDescription: true,
                showColor: true
            });

            if (!args.filter && labels.length > 0) {
                console.log('💡 Tip: Use --filter="prefix" to filter labels');
                console.log('   Example: --filter="ai:" to see only AI-related labels\n');
            }
        }

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        process.exit(1);
    }
}

// Run
main().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});