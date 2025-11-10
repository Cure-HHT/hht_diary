#!/usr/bin/env node
/**
 * Enhance REQ Links in Linear Tickets
 *
 * Updates Linear ticket descriptions to add clickable GitHub links
 * for requirement references (REQ-xxxxx).
 *
 * IMPLEMENTS REQUIREMENTS:
 *   Supporting CUR-329: Link REQ references to spec/ files
 *
 * Usage:
 *   node enhance-req-links.js [options]
 *
 * Options:
 *   --ticket-id=CUR-329     Update specific ticket
 *   --all                   Update all tickets with REQ references
 *   --dry-run               Preview changes without updating
 *   --force                 Update even if links already exist
 */

const config = require('../../linear-api/lib/config');
const ticketFetcher = require('../../linear-api/lib/ticket-fetcher');
const ticketUpdater = require('../../linear-api/lib/ticket-updater');
const reqLocator = require('./lib/req-locator');

// Parse command line arguments
function parseArgs() {
    const args = {
        ticketId: null,
        all: false,
        dryRun: false,
        force: false
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--ticket-id=')) {
            args.ticketId = arg.split('=')[1];
        } else if (arg === '--all') {
            args.all = true;
        } else if (arg === '--dry-run') {
            args.dryRun = true;
        } else if (arg === '--force') {
            args.force = true;
        }
    }

    return args;
}

/**
 * Sleep for specified milliseconds
 * @param {number} ms - Milliseconds to sleep
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Check if a REQ reference already has a properly formatted link in the text
 * @param {string} text - Text to check
 * @param {string} reqRef - REQ reference (e.g., "REQ-d00014")
 * @returns {boolean} True if properly formatted link already exists
 */
function hasExistingLink(text, reqRef) {
    // New format: Requirement: REQ-xxx | Title | [file](url)
    // Only skip if it matches the new format exactly
    const pattern = new RegExp(`Requirement:\\s*${reqRef}\\s*\\|.+?\\|\\s*\\[.+?\\]\\(`, 'i');
    return pattern.test(text);
}

/**
 * Find and extract the old requirement section to replace
 * @param {string} text - Text to search in
 * @param {string} reqRef - REQ reference (e.g., "REQ-d00014")
 * @returns {string|null} The old requirement section to replace, or null if not found
 */
function findOldRequirementSection(text, reqRef) {
    // Look for lines containing "Requirement" and the specific REQ reference
    // Split into lines and find the line containing both
    const lines = text.split('\n');

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Check if this line contains both "Requirement" and the REQ reference
        if (line.match(/\*?\*?Requirement\*?\*?:/i) && line.match(new RegExp(reqRef, 'i'))) {
            // Return the entire line (this will be the old requirement section)
            return line;
        }
    }

    // If not found in a Requirement line, look for old format: REQ-xxx - [file](url)
    const oldFormatPattern = new RegExp(`${reqRef}\\s*-\\s*\\[[^\\]]+\\]\\([^)]+\\)`, 'i');
    const match = text.match(oldFormatPattern);
    if (match) {
        return match[0];
    }

    return null;
}

/**
 * Enhance a single ticket with REQ links
 * @param {string} ticketId - Ticket ID or identifier
 * @param {Object} options
 * @param {boolean} options.dryRun - Preview only, don't update
 * @param {boolean} options.force - Update even if links exist
 * @returns {Promise<Object>} Result object
 */
async function enhanceTicket(ticketId, options = {}) {
    const { dryRun = false, force = false } = options;

    console.log(`\n${'='.repeat(80)}`);
    console.log(`Processing ticket: ${ticketId}`);
    console.log(`${'='.repeat(80)}\n`);

    // 1. Fetch ticket from Linear
    const ticket = await ticketFetcher.getTicketById(ticketId);

    if (!ticket) {
        console.log(`❌ Ticket ${ticketId} not found`);
        return {
            ticketId,
            success: false,
            error: 'Ticket not found'
        };
    }

    console.log(`Title: ${ticket.title}`);
    console.log(`URL: ${ticket.url}\n`);

    if (!ticket.description || ticket.description.trim() === '') {
        console.log(`⚠️  No description found`);
        return {
            ticketId,
            success: false,
            error: 'No description'
        };
    }

    // 2. Extract all REQ-xxxxx from description
    const reqPattern = /REQ-[pod]\d{5}/gi;
    const reqRefs = ticket.description.match(reqPattern);

    if (!reqRefs || reqRefs.length === 0) {
        console.log(`  No REQ references found in description`);
        return {
            ticketId,
            success: true,
            reqCount: 0,
            enhanced: 0
        };
    }

    // Get unique REQ references
    const uniqueReqs = [...new Set(reqRefs.map(r => r.toUpperCase()))];
    console.log(`Found ${uniqueReqs.length} unique REQ reference(s): ${uniqueReqs.join(', ')}\n`);

    // 3. Process each REQ and build new requirement lines
    const enhancedRequirements = [];
    let enhancedCount = 0;
    const results = [];

    for (const reqRef of uniqueReqs) {
        console.log(`  ${reqRef}:`);

        // Check if already has properly formatted link
        if (!force && hasExistingLink(ticket.description, reqRef)) {
            console.log(`    ✓ Already has proper format, skipping`);
            results.push({
                reqRef,
                status: 'skipped',
                reason: 'Already properly formatted'
            });
            continue;
        }

        // Find location
        const reqId = reqRef.replace(/^REQ-/i, '');
        const location = await reqLocator.findReqLocation(reqId);

        if (!location) {
            console.log(`    ❌ NOT FOUND in spec/`);
            results.push({
                reqRef,
                status: 'not_found'
            });
            continue;
        }

        console.log(`    ✓ Found at ${location.file}:${location.lineNumber}`);
        console.log(`    📌 Title: ${location.title}`);
        console.log(`    📌 Anchor: #${location.anchor}`);

        // Build enhanced link
        const enhancedLink = reqLocator.formatReqLink(reqId, location.file, location.anchor, location.title);
        enhancedRequirements.push(enhancedLink);

        enhancedCount++;
        results.push({
            reqRef,
            status: 'enhanced',
            location: location
        });
    }

    // 4. Build new description
    let newDescription = ticket.description;

    if (enhancedCount > 0) {
        // Remove all old Requirement lines (both properly formatted and malformed)
        const lines = newDescription.split('\n');
        const cleanedLines = [];

        for (const line of lines) {
            // Skip lines that contain "Requirement:" or "**Requirement**:"
            if (line.match(/\*?\*?Requirement\*?\*?:/i)) {
                console.log(`    🗑️  Removing old requirement line`);
                continue;
            }
            cleanedLines.push(line);
        }

        // Trim leading empty lines
        while (cleanedLines.length > 0 && cleanedLines[0].trim() === '') {
            cleanedLines.shift();
        }

        // Prepend new requirement lines
        newDescription = enhancedRequirements.join('\n\n') + '\n\n' + cleanedLines.join('\n');
    }

    // 4. Update ticket if changed
    if (newDescription !== ticket.description) {
        console.log(`\nSummary: ${enhancedCount}/${uniqueReqs.length} REQ(s) enhanced`);

        if (dryRun) {
            console.log(`\n[DRY RUN] Would update ${ticketId} description:`);
            console.log(`${'─'.repeat(80)}`);
            console.log(newDescription);
            console.log(`${'─'.repeat(80)}`);
        } else {
            console.log(`\nUpdating ticket...`);
            await ticketUpdater.updateTicket(ticketId, {
                description: newDescription
            }, { silent: true });
            console.log(`✅ Updated ${ticketId}`);
        }

        return {
            ticketId,
            success: true,
            reqCount: uniqueReqs.length,
            enhanced: enhancedCount,
            results: results
        };
    } else {
        console.log(`\n  No changes needed`);
        return {
            ticketId,
            success: true,
            reqCount: uniqueReqs.length,
            enhanced: 0
        };
    }
}

/**
 * Enhance all tickets with REQ references
 * @param {Object} options
 * @param {boolean} options.dryRun - Preview only
 * @param {boolean} options.force - Update even if links exist
 */
async function enhanceAllTickets(options = {}) {
    const { dryRun = false, force = false } = options;

    console.log(`\n${'='.repeat(80)}`);
    console.log(`Fetching all tickets with REQ references...`);
    console.log(`(This may take a few minutes for large teams)`);
    console.log(`${'='.repeat(80)}\n`);

    // Fetch all tickets (both active and completed)
    // Uses pagination to retrieve all tickets across multiple API calls
    const tickets = await ticketFetcher.getTickets({
        limit: 100,  // Per page
        includeCompleted: true
    });

    console.log(`Fetched ${tickets.length} total tickets`);

    // Filter tickets with REQ references
    const ticketsWithReqs = tickets.filter(t =>
        t.description && t.description.match(/REQ-[pod]\d{5}/i)
    );

    console.log(`Found ${ticketsWithReqs.length} tickets with REQ references\n`);

    if (ticketsWithReqs.length === 0) {
        console.log(`No tickets to process`);
        return {
            total: 0,
            processed: 0,
            enhanced: 0,
            failed: 0
        };
    }

    // Process each ticket
    const summary = {
        total: ticketsWithReqs.length,
        processed: 0,
        enhanced: 0,
        failed: 0,
        results: []
    };

    for (let i = 0; i < ticketsWithReqs.length; i++) {
        const ticket = ticketsWithReqs[i];

        console.log(`\n[${i + 1}/${ticketsWithReqs.length}]`);

        try {
            const result = await enhanceTicket(ticket.identifier, {
                dryRun,
                force
            });

            summary.processed++;
            if (result.enhanced > 0) {
                summary.enhanced++;
            }
            summary.results.push(result);

        } catch (error) {
            console.log(`❌ Failed: ${error.message}`);
            summary.failed++;
            summary.results.push({
                ticketId: ticket.identifier,
                success: false,
                error: error.message
            });
        }

        // Rate limiting: pause between requests
        if (i < ticketsWithReqs.length - 1) {
            await sleep(500);
        }
    }

    // Final summary
    console.log(`\n${'='.repeat(80)}`);
    console.log(`FINAL SUMMARY`);
    console.log(`${'='.repeat(80)}`);
    console.log(`Total tickets with REQs: ${summary.total}`);
    console.log(`Successfully processed: ${summary.processed}`);
    console.log(`Tickets enhanced: ${summary.enhanced}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`${'='.repeat(80)}\n`);

    return summary;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();

    // Validate configuration
    config.getToken(true); // Will throw if token not found

    if (args.dryRun) {
        console.log(`\n⚠️  DRY RUN MODE - No changes will be made\n`);
    }

    if (args.force) {
        console.log(`\n⚠️  FORCE MODE - Will update tickets even if links exist\n`);
    }

    // Single ticket mode
    if (args.ticketId) {
        const result = await enhanceTicket(args.ticketId, {
            dryRun: args.dryRun,
            force: args.force
        });

        if (!result.success) {
            process.exit(1);
        }

        return;
    }

    // Bulk mode
    if (args.all) {
        const summary = await enhanceAllTickets({
            dryRun: args.dryRun,
            force: args.force
        });

        if (summary.failed > 0) {
            process.exit(1);
        }

        return;
    }

    // No mode specified
    console.error('❌ Please specify --ticket-id=CUR-XXX or --all');
    console.error('');
    console.error('Usage:');
    console.error('  node enhance-req-links.js --ticket-id=CUR-329');
    console.error('  node enhance-req-links.js --all');
    console.error('  node enhance-req-links.js --all --dry-run');
    process.exit(1);
}

// Run if called directly
if (require.main === module) {
    main().catch(error => {
        console.error('❌ Error:', error.message);
        if (process.env.DEBUG) {
            console.error(error.stack);
        }
        process.exit(1);
    });
}

module.exports = { enhanceTicket, enhanceAllTickets };
