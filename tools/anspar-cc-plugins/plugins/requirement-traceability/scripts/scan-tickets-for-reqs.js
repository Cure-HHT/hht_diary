#!/usr/bin/env node
/**
 * Scan Linear tickets for missing REQ references
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00015: Traceability Matrix Auto-Generation
 *
 * Usage:
 *   node scan-tickets-for-reqs.js [--format=summary|json]
 */

const { executeGraphQL } = require('../../linear-api/lib/graphql-client');
const { validateEnvironment } = require('../../linear-api/lib/env-validation');
const config = require('../../linear-api/lib/config');
const fs = require('fs');
const path = require('path');

/**
 * GraphQL query to fetch all open issues
 */
const QUERY_OPEN_ISSUES = `
  query($teamId: String!) {
    team(id: $teamId) {
      issues(
        filter: {
          state: { type: { in: ["started", "unstarted"] } }
        }
        first: 100
      ) {
        nodes {
          id
          identifier
          title
          description
          priority
          priorityLabel
          state {
            name
            type
          }
          labels {
            nodes {
              name
            }
          }
          project {
            name
          }
        }
      }
    }
  }
`;

/**
 * Parse command line arguments
 */
function parseArgs() {
    const args = {
        format: 'summary'
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--format=')) {
            args.format = arg.split('=')[1];
        } else if (arg === '--help' || arg === '-h') {
            showHelp();
            process.exit(0);
        }
    }

    return args;
}

/**
 * Show help message
 */
function showHelp() {
    console.log(`
Scan Linear tickets for missing REQ references

Usage:
  node scan-tickets-for-reqs.js [--format=summary|json]

Options:
  --format=FORMAT    Output format (summary or json, default: summary)

Examples:
  node scan-tickets-for-reqs.js
  node scan-tickets-for-reqs.js --format=json
`);
}

/**
 * Check if ticket description contains REQ reference
 */
function hasRequirementReference(description) {
    if (!description) return false;

    // Look for REQ-{p|o|d}NNNNN pattern
    const reqPattern = /REQ-[pod]\d{5}/i;
    return reqPattern.test(description);
}

/**
 * Extract all REQ references from description
 */
function extractRequirements(description) {
    if (!description) return [];

    const reqPattern = /REQ-[pod]\d{5}/gi;
    const matches = description.match(reqPattern) || [];

    // Return unique requirements (uppercase)
    return [...new Set(matches.map(req => req.toUpperCase()))];
}

/**
 * Suggest requirement based on ticket title and labels
 */
function suggestRequirement(ticket, indexData) {
    const titleLower = ticket.title.toLowerCase();
    const labels = ticket.labels?.nodes?.map(l => l.name.toLowerCase()) || [];

    // Keyword-based matching
    const suggestions = [];

    // Database-related
    if (titleLower.includes('schema') || titleLower.includes('database') ||
        titleLower.includes('migration') || labels.includes('database')) {
        suggestions.push('REQ-d00007'); // Database Schema Implementation
    }

    // Authentication-related
    if (titleLower.includes('auth') || titleLower.includes('login') ||
        titleLower.includes('authentication') || labels.includes('security')) {
        suggestions.push('REQ-p00001'); // Multi-sponsor authentication
    }

    // MFA-related
    if (titleLower.includes('mfa') || titleLower.includes('multi-factor') ||
        titleLower.includes('2fa') || titleLower.includes('totp')) {
        suggestions.push('REQ-p00042'); // Multi-factor authentication
    }

    // Portal-related
    if (titleLower.includes('portal') || titleLower.includes('dashboard') ||
        titleLower.includes('admin') || labels.includes('portal')) {
        suggestions.push('REQ-p00024'); // Portal User Roles and Permissions
    }

    // Requirements/traceability-related
    if (titleLower.includes('requirement') || titleLower.includes('traceability') ||
        titleLower.includes('validation') || labels.includes('requirements')) {
        suggestions.push('REQ-d00015'); // Traceability Matrix Auto-Generation
    }

    // Event sourcing-related
    if (titleLower.includes('event') || titleLower.includes('sourcing') ||
        titleLower.includes('audit') || titleLower.includes('immutable')) {
        suggestions.push('REQ-p00004'); // Immutable Audit Trail via Event Sourcing
    }

    return suggestions.length > 0 ? suggestions[0] : null;
}

/**
 * Load INDEX.md data for requirement lookups
 */
function loadIndexData() {
    try {
        const indexPath = path.join(process.cwd(), 'spec', 'INDEX.md');
        const content = fs.readFileSync(indexPath, 'utf8');

        const requirements = {};
        const lines = content.split('\n');

        for (const line of lines) {
            // Parse table rows: | REQ-pNNNNN | file.md | Title | hash |
            const match = line.match(/\|\s*(REQ-[pod]\d{5})\s*\|\s*([^\|]+)\s*\|\s*([^\|]+)\s*\|/);
            if (match) {
                const reqId = match[1].trim();
                const file = match[2].trim();
                const title = match[3].trim();

                requirements[reqId] = { file, title };
            }
        }

        return requirements;
    } catch (error) {
        console.error('Warning: Could not load spec/INDEX.md:', error.message);
        return {};
    }
}

/**
 * Main execution
 */
async function main() {
    const args = parseArgs();

    // Validate environment
    try {
        validateEnvironment();
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }

    const apiToken = process.env.LINEAR_API_TOKEN;

    // Get team ID
    let teamId;
    try {
        teamId = await config.getTeamId(apiToken);
    } catch (error) {
        console.error('Error getting team ID:', error.message);
        process.exit(1);
    }

    // Load INDEX data
    const indexData = loadIndexData();

    // Fetch open issues
    console.log('📋 Scanning Linear tickets for requirement references...\n');

    let response;
    try {
        response = await executeGraphQL(QUERY_OPEN_ISSUES, { teamId }, apiToken);
    } catch (error) {
        console.error('Error fetching tickets:', error.message);
        process.exit(1);
    }

    const issues = response.data?.team?.issues?.nodes || [];

    if (issues.length === 0) {
        console.log('No open tickets found.');
        return;
    }

    // Categorize tickets
    const withReqs = [];
    const withoutReqs = [];

    for (const issue of issues) {
        if (hasRequirementReference(issue.description)) {
            const reqs = extractRequirements(issue.description);
            withReqs.push({ ...issue, requirements: reqs });
        } else {
            const suggestion = suggestRequirement(issue, indexData);
            withoutReqs.push({ ...issue, suggestion });
        }
    }

    // Output results
    if (args.format === 'json') {
        console.log(JSON.stringify({
            summary: {
                total: issues.length,
                withRequirements: withReqs.length,
                missingRequirements: withoutReqs.length
            },
            ticketsWithRequirements: withReqs,
            ticketsMissingRequirements: withoutReqs
        }, null, 2));
    } else {
        // Summary format
        console.log(`Total open tickets: ${issues.length}`);
        console.log(`✓ With REQ references: ${withReqs.length}`);
        console.log(`⚠️  Missing REQ references: ${withoutReqs.length}\n`);

        if (withoutReqs.length > 0) {
            // Group by priority
            const urgent = withoutReqs.filter(t => t.priority === 1);
            const high = withoutReqs.filter(t => t.priority === 2);
            const medium = withoutReqs.filter(t => t.priority === 3);
            const low = withoutReqs.filter(t => t.priority === 4);
            const none = withoutReqs.filter(t => t.priority === 0 || !t.priority);

            console.log('📋 TICKETS MISSING REQUIREMENT REFERENCES:\n');

            if (urgent.length > 0) {
                console.log(`🔴 Urgent Priority (${urgent.length}):`);
                for (const ticket of urgent) {
                    console.log(`  • ${ticket.identifier}: ${ticket.title}`);
                    if (ticket.suggestion) {
                        const reqInfo = indexData[ticket.suggestion];
                        if (reqInfo) {
                            console.log(`    💡 Suggested: ${ticket.suggestion} - ${reqInfo.title}`);
                        } else {
                            console.log(`    💡 Suggested: ${ticket.suggestion}`);
                        }
                    }
                }
                console.log();
            }

            if (high.length > 0) {
                console.log(`🟠 High Priority (${high.length}):`);
                for (const ticket of high) {
                    console.log(`  • ${ticket.identifier}: ${ticket.title}`);
                    if (ticket.suggestion) {
                        const reqInfo = indexData[ticket.suggestion];
                        if (reqInfo) {
                            console.log(`    💡 Suggested: ${ticket.suggestion} - ${reqInfo.title}`);
                        } else {
                            console.log(`    💡 Suggested: ${ticket.suggestion}`);
                        }
                    }
                }
                console.log();
            }

            if (medium.length > 0) {
                console.log(`🟡 Medium Priority (${medium.length}):`);
                for (const ticket of medium.slice(0, 5)) {
                    console.log(`  • ${ticket.identifier}: ${ticket.title}`);
                    if (ticket.suggestion) {
                        console.log(`    💡 Suggested: ${ticket.suggestion}`);
                    }
                }
                if (medium.length > 5) {
                    console.log(`  ... and ${medium.length - 5} more`);
                }
                console.log();
            }

            if (low.length > 0) {
                console.log(`🟢 Low Priority (${low.length}):`);
                console.log(`  (Use --format=json to see all tickets)`);
                console.log();
            }

            console.log('\n💡 NEXT STEPS:');
            console.log('1. Review suggested requirement mappings above');
            console.log('2. Add REQ references using:');
            console.log('   /add-REQ-to-ticket TICKET-ID REQ-ID');
            console.log('3. Or create bulk mapping file for multiple updates');
        } else {
            console.log('✅ All open tickets have requirement references!');
        }
    }
}

// Run
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
