#!/usr/bin/env node
/**
 * Advanced duplicate checker:
 * 1. Filter out tickets in "JumpCloud IAM Implementation" project
 * 2. Check remaining tickets without REQ references for duplicates
 */

const fs = require('fs');
const path = require('path');

// Read the Linear tickets JSON
const ticketsData = JSON.parse(fs.readFileSync('/tmp/linear-tickets-clean.json', 'utf-8'));

// Get all tickets
const allTickets = ticketsData.analysis.categories.backlog
    .concat(ticketsData.analysis.categories.todo)
    .concat(ticketsData.analysis.categories.inProgress)
    .concat(ticketsData.analysis.categories.inReview)
    .concat(ticketsData.analysis.categories.blocked)
    .concat(ticketsData.analysis.categories.done)
    .concat(ticketsData.analysis.categories.other);

// Filter out JumpCloud IAM Implementation project tickets
const jumpCloudTickets = allTickets.filter(t => t.project && t.project.name === 'JumpCloud IAM Implementation');
const otherTickets = allTickets.filter(t => !t.project || t.project.name !== 'JumpCloud IAM Implementation');

// Filter tickets without REQ references
const ticketsWithoutReq = otherTickets.filter(t => {
    const text = (t.title + ' ' + (t.description || '')).toLowerCase();
    return !text.includes('req-');
});

// Parse requirements
function parseRequirements(specDir) {
    const requirements = [];
    const reqHeaderPattern = /^###\s+REQ-([pod]\d{5}):\s+(.+)$/gm;
    const metadataPattern = /\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)/;

    const specFiles = fs.readdirSync(specDir).filter(f => f.endsWith('.md'));

    for (const file of specFiles) {
        const content = fs.readFileSync(path.join(specDir, file), 'utf-8');
        let match;

        while ((match = reqHeaderPattern.exec(content)) !== null) {
            const reqId = match[1];
            const title = match[2].trim();
            const remainingContent = content.slice(match.index + match[0].length);
            const metadataMatch = remainingContent.match(metadataPattern);

            if (metadataMatch) {
                const level = metadataMatch[1];
                requirements.push({
                    id: reqId,
                    title,
                    level,
                });
            }
        }
    }

    return requirements;
}

const specDir = path.join(__dirname, '../../spec');
const requirements = parseRequirements(specDir).filter(r => r.id !== 'p00001' && r.id !== 'p00015');

console.log('================================================================================');
console.log('ADVANCED DUPLICATE CHECK');
console.log('================================================================================');
console.log();
console.log(`Total existing tickets: ${allTickets.length}`);
console.log(`  - JumpCloud IAM Implementation: ${jumpCloudTickets.length} (ignored)`);
console.log(`  - Other projects/no project: ${otherTickets.length}`);
console.log(`  - Without REQ reference: ${ticketsWithoutReq.length} (checking for duplicates)`);
console.log();
console.log(`Requirements to create: ${requirements.length}`);
console.log();

// Show JumpCloud tickets being ignored
console.log('--------------------------------------------------------------------------------');
console.log('IGNORED: JUMPCLOUD IAM IMPLEMENTATION TICKETS');
console.log('--------------------------------------------------------------------------------');
for (const ticket of jumpCloudTickets) {
    console.log(`  ${ticket.identifier}: ${ticket.title}`);
}
console.log();

// Check for duplicates against tickets without REQ
console.log('--------------------------------------------------------------------------------');
console.log('CHECKING FOR DUPLICATES (tickets without REQ references)');
console.log('--------------------------------------------------------------------------------');

const duplicates = [];

for (const req of requirements) {
    const reqTitleLower = req.title.toLowerCase();
    const reqWords = reqTitleLower.split(/\s+/).filter(w => w.length > 3);

    for (const ticket of ticketsWithoutReq) {
        const ticketTitleLower = ticket.title.toLowerCase();

        // Check for exact match
        if (ticketTitleLower === reqTitleLower) {
            duplicates.push({
                req,
                ticket,
                matchType: 'exact',
                matchPercent: 100
            });
            continue;
        }

        // Check for similar match (same words)
        let matchCount = 0;
        for (const word of reqWords) {
            if (ticketTitleLower.includes(word)) {
                matchCount++;
            }
        }

        // If more than 50% of words match, consider it similar
        if (reqWords.length > 0 && matchCount / reqWords.length > 0.5) {
            duplicates.push({
                req,
                ticket,
                matchType: 'similar',
                matchPercent: Math.round(matchCount / reqWords.length * 100)
            });
        }
    }
}

if (duplicates.length > 0) {
    console.log();
    console.log(`⚠️  POTENTIAL DUPLICATES FOUND: ${duplicates.length}`);
    console.log();
    for (const dup of duplicates) {
        console.log(`  REQ-${dup.req.id}: ${dup.req.title}`);
        console.log(`    ${dup.matchType === 'exact' ? '→ EXACT MATCH' : `→ ${dup.matchPercent}% similar to`}: ${dup.ticket.identifier} - ${dup.ticket.title}`);
        console.log(`    Ticket status: ${dup.ticket.state.name}`);
        if (dup.ticket.url) {
            console.log(`    URL: ${dup.ticket.url}`);
        }
        console.log();
    }
} else {
    console.log();
    console.log('✅ NO DUPLICATES FOUND');
    console.log();
}

// Show sample of tickets being checked
console.log('--------------------------------------------------------------------------------');
console.log('SAMPLE: EXISTING TICKETS WITHOUT REQ (being checked for duplicates)');
console.log('--------------------------------------------------------------------------------');
for (const ticket of ticketsWithoutReq.slice(0, 15)) {
    const projectStr = ticket.project ? ` [${ticket.project.name}]` : '';
    console.log(`  ${ticket.identifier}: ${ticket.title}${projectStr}`);
}
if (ticketsWithoutReq.length > 15) {
    console.log(`  ... and ${ticketsWithoutReq.length - 15} more`);
}
console.log();

console.log('================================================================================');
console.log('SUMMARY');
console.log('================================================================================');
console.log(`Tickets to create: ${requirements.length}`);
console.log(`Potential duplicates: ${duplicates.length}`);
console.log();
