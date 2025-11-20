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

const graphqlClient = require('../../linear-api/lib/graphql-client');
const { validateEnvironment } = require('../../linear-api/lib/env-validation');
const config = require('../../linear-api/lib/config');
const fs = require('fs');
const path = require('path');

/**
 * GraphQL query to fetch all open issues (including backlog)
 */
const QUERY_OPEN_ISSUES = `
  query($teamId: String!, $after: String) {
    team(id: $teamId) {
      issues(
        filter: {
          state: { type: { in: ["started", "unstarted", "backlog"] } }
        }
        first: 100
        after: $after
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
          assignee {
            name
          }
        }
        pageInfo {
          hasNextPage
          endCursor
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
 * Extract keywords from ticket for requirement matching
 */
function extractKeywords(ticket) {
    const titleLower = ticket.title.toLowerCase();
    const descLower = (ticket.description || '').toLowerCase();
    const labels = ticket.labels?.nodes?.map(l => l.name.toLowerCase()) || [];

    // Common stopwords to filter out
    const stopwords = new Set(['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'from', 'by', 'as', 'is', 'was', 'are', 'were', 'be', 'been', 'being']);

    // Extract words from title and description
    const words = new Set();

    // Add title words (higher weight)
    titleLower.split(/\s+/).forEach(word => {
        const cleaned = word.replace(/[^a-z0-9-]/g, '');
        if (cleaned.length > 2 && !stopwords.has(cleaned)) {
            words.add(cleaned);
        }
    });

    // Add description words
    descLower.split(/\s+/).forEach(word => {
        const cleaned = word.replace(/[^a-z0-9-]/g, '');
        if (cleaned.length > 2 && !stopwords.has(cleaned)) {
            words.add(cleaned);
        }
    });

    // Add labels
    labels.forEach(label => words.add(label));

    return Array.from(words);
}

/**
 * Find candidate requirements from INDEX.md based on keywords
 */
function findCandidateRequirements(keywords, indexData) {
    const candidates = [];

    for (const [reqId, info] of Object.entries(indexData)) {
        const titleLower = info.title.toLowerCase();
        let matchScore = 0;
        const matchedKeywords = [];

        // Check each keyword against requirement title
        for (const keyword of keywords) {
            if (titleLower.includes(keyword)) {
                matchScore++;
                matchedKeywords.push(keyword);
            }
        }

        if (matchScore > 0) {
            candidates.push({
                reqId,
                file: info.file,
                title: info.title,
                matchScore,
                matchedKeywords
            });
        }
    }

    // Sort by match score (descending)
    candidates.sort((a, b) => b.matchScore - a.matchScore);

    // Return top 10 candidates
    return candidates.slice(0, 10);
}

/**
 * Read requirement body from spec file
 */
function readRequirementBody(reqId, fileName) {
    try {
        const filePath = path.join(process.cwd(), 'spec', fileName);
        const content = fs.readFileSync(filePath, 'utf8');

        // Find the requirement section
        const reqPattern = new RegExp(`# ${reqId}:([^#]+)(?=\\n#|$)`, 's');
        const match = content.match(reqPattern);

        if (match) {
            return match[1].trim();
        }

        return null;
    } catch (error) {
        return null;
    }
}

/**
 * Evaluate relevance of a requirement to a ticket
 */
function evaluateRelevance(ticket, candidate) {
    const reqBody = readRequirementBody(candidate.reqId, candidate.file);

    if (!reqBody) {
        return { ...candidate, confidence: 'low', reason: 'Could not read requirement body' };
    }

    const titleLower = ticket.title.toLowerCase();
    const descLower = (ticket.description || '').toLowerCase();
    const reqBodyLower = reqBody.toLowerCase();

    let relevanceScore = candidate.matchScore * 10; // Base score from keyword matches
    const reasons = [];

    // Check for keyword matches in requirement body
    const ticketKeywords = extractKeywords(ticket);
    let bodyMatches = 0;

    for (const keyword of ticketKeywords) {
        if (reqBodyLower.includes(keyword)) {
            bodyMatches++;
            relevanceScore += 2;
        }
    }

    if (bodyMatches > 0) {
        reasons.push(`${bodyMatches} keyword matches in requirement body`);
    }

    // Check for exact phrase matches
    const titlePhrases = titleLower.split(/[,;.]/).map(p => p.trim()).filter(p => p.length > 5);
    for (const phrase of titlePhrases) {
        if (reqBodyLower.includes(phrase)) {
            relevanceScore += 15;
            reasons.push(`Exact phrase match: "${phrase}"`);
        }
    }

    // Determine confidence level
    let confidence;
    if (relevanceScore >= 30) {
        confidence = 'high';
    } else if (relevanceScore >= 15) {
        confidence = 'medium';
    } else {
        confidence = 'low';
    }

    return {
        reqId: candidate.reqId,
        title: candidate.title,
        confidence,
        score: relevanceScore,
        reason: reasons.length > 0 ? reasons.join('; ') : `${candidate.matchScore} keyword matches in title`
    };
}

/**
 * Suggest requirements based on ticket content using intelligent matching
 */
function suggestRequirement(ticket, indexData) {
    // Extract keywords from ticket
    const keywords = extractKeywords(ticket);

    if (keywords.length === 0) {
        return null;
    }

    // Find candidate requirements from INDEX
    const candidates = findCandidateRequirements(keywords, indexData);

    if (candidates.length === 0) {
        return null;
    }

    // Evaluate each candidate by reading full requirement
    const evaluated = candidates.map(candidate => evaluateRelevance(ticket, candidate));

    // Filter to high and medium confidence matches
    const goodMatches = evaluated.filter(e => e.confidence === 'high' || e.confidence === 'medium');

    // Return top matches (up to 3)
    if (goodMatches.length > 0) {
        return goodMatches.slice(0, 3);
    }

    // If no good matches, return the top low-confidence match
    return evaluated.length > 0 ? [evaluated[0]] : null;
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

    // Fetch open issues with pagination
    console.log('📋 Scanning Linear tickets for requirement references...\n');

    let allIssues = [];
    let hasNextPage = true;
    let after = null;

    try {
        while (hasNextPage) {
            const data = await graphqlClient.execute(QUERY_OPEN_ISSUES, { teamId, after });
            const issuesData = data?.team?.issues;

            if (issuesData?.nodes) {
                allIssues.push(...issuesData.nodes);
            }

            hasNextPage = issuesData?.pageInfo?.hasNextPage || false;
            after = issuesData?.pageInfo?.endCursor || null;
        }
    } catch (error) {
        console.error('Error fetching tickets:', error.message);
        process.exit(1);
    }

    const issues = allIssues;

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
            const suggestions = suggestRequirement(issue, indexData);
            withoutReqs.push({ ...issue, suggestions });
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
                    if (ticket.suggestions && ticket.suggestions.length > 0) {
                        for (const suggestion of ticket.suggestions) {
                            const confidenceIcon = suggestion.confidence === 'high' ? '🟢' : suggestion.confidence === 'medium' ? '🟡' : '🔴';
                            console.log(`    💡 ${confidenceIcon} ${suggestion.reqId} - ${suggestion.title} (${suggestion.confidence})`);
                            console.log(`       ${suggestion.reason}`);
                        }
                    }
                }
                console.log();
            }

            if (high.length > 0) {
                console.log(`🟠 High Priority (${high.length}):`);
                for (const ticket of high) {
                    console.log(`  • ${ticket.identifier}: ${ticket.title}`);
                    if (ticket.suggestions && ticket.suggestions.length > 0) {
                        for (const suggestion of ticket.suggestions) {
                            const confidenceIcon = suggestion.confidence === 'high' ? '🟢' : suggestion.confidence === 'medium' ? '🟡' : '🔴';
                            console.log(`    💡 ${confidenceIcon} ${suggestion.reqId} - ${suggestion.title} (${suggestion.confidence})`);
                            console.log(`       ${suggestion.reason}`);
                        }
                    }
                }
                console.log();
            }

            if (medium.length > 0) {
                console.log(`🟡 Medium Priority (${medium.length}):`);
                for (const ticket of medium.slice(0, 5)) {
                    console.log(`  • ${ticket.identifier}: ${ticket.title}`);
                    if (ticket.suggestions && ticket.suggestions.length > 0) {
                        for (const suggestion of ticket.suggestions) {
                            const confidenceIcon = suggestion.confidence === 'high' ? '🟢' : suggestion.confidence === 'medium' ? '🟡' : '🔴';
                            console.log(`    💡 ${confidenceIcon} ${suggestion.reqId} - ${suggestion.title} (${suggestion.confidence})`);
                        }
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
