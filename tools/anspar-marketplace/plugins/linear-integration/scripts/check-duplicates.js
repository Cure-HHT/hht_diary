#!/usr/bin/env node
/**
 * Check for duplicate tickets before creating requirements
 */

const fs = require('fs');
const path = require('path');

// Read the Linear tickets JSON
const ticketsData = JSON.parse(fs.readFileSync('/tmp/linear-tickets-clean.json', 'utf-8'));
const existingTitles = ticketsData.analysis.categories.backlog
    .concat(ticketsData.analysis.categories.todo)
    .concat(ticketsData.analysis.categories.inProgress)
    .concat(ticketsData.analysis.categories.inReview)
    .concat(ticketsData.analysis.categories.blocked)
    .concat(ticketsData.analysis.categories.done)
    .concat(ticketsData.analysis.categories.other)
    .map(issue => issue.title.toLowerCase());

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
const requirements = parseRequirements(specDir).filter(r => r.id !== 'p00001');

console.log('================================================================================');
console.log('CHECKING FOR DUPLICATE TICKETS');
console.log('================================================================================');
console.log();
console.log(`Existing tickets: ${existingTitles.length}`);
console.log(`Requirements to create: ${requirements.length}`);
console.log();

// Check for duplicates
const duplicates = [];
const samples = [];

for (const req of requirements) {
    const titleLower = req.title.toLowerCase();

    // Check for exact match
    if (existingTitles.includes(titleLower)) {
        duplicates.push({ req, matchType: 'exact' });
    }

    // Check for similar match (same words)
    const words = titleLower.split(/\s+/).filter(w => w.length > 3);
    for (const existingTitle of existingTitles) {
        let matchCount = 0;
        for (const word of words) {
            if (existingTitle.includes(word)) {
                matchCount++;
            }
        }

        // If more than 50% of words match, consider it similar
        if (words.length > 0 && matchCount / words.length > 0.5) {
            duplicates.push({
                req,
                matchType: 'similar',
                existingTitle,
                matchPercent: Math.round(matchCount / words.length * 100)
            });
            break;
        }
    }

    // Collect some samples
    if (samples.length < 10) {
        samples.push(req);
    }
}

if (duplicates.length > 0) {
    console.log('⚠️  POTENTIAL DUPLICATES FOUND:');
    console.log();
    for (const dup of duplicates.slice(0, 10)) {
        console.log(`  REQ-${dup.req.id}: ${dup.req.title}`);
        if (dup.matchType === 'exact') {
            console.log(`    → EXACT MATCH found in existing tickets`);
        } else {
            console.log(`    → ${dup.matchPercent}% similar to: "${dup.existingTitle}"`);
        }
    }
    if (duplicates.length > 10) {
        console.log(`  ... and ${duplicates.length - 10} more`);
    }
} else {
    console.log('✅ NO DUPLICATES FOUND');
}

console.log();
console.log('--------------------------------------------------------------------------------');
console.log('SAMPLE REQUIREMENT TITLES TO BE CREATED:');
console.log('--------------------------------------------------------------------------------');
for (const req of samples) {
    console.log(`  [${req.level}] ${req.title}`);
}
console.log();
