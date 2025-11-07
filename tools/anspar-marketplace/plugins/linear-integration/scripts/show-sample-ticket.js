#!/usr/bin/env node
/**
 * Show what a sample Linear ticket would look like
 */

const fs = require('fs');
const path = require('path');

/**
 * Parse requirements from spec files
 */
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
                const implementsStr = metadataMatch[2].trim();
                const status = metadataMatch[3];

                const implements = implementsStr === '-'
                    ? []
                    : implementsStr.split(',').map(s => s.trim());

                requirements.push({
                    id: reqId,
                    title,
                    level,
                    implements,
                    status,
                    file
                });
            }
        }
    }

    return requirements;
}

// Parse requirements
const specDir = path.join(__dirname, '../../spec');
const requirements = parseRequirements(specDir);

// Show 3 example tickets (one from each level)
const prdReq = requirements.find(r => r.level === 'PRD' && r.id !== 'p00001');
const opsReq = requirements.find(r => r.level === 'Ops');
const devReq = requirements.find(r => r.level === 'Dev');

console.log('================================================================================');
console.log('SAMPLE LINEAR TICKETS');
console.log('================================================================================');
console.log();

for (const req of [prdReq, opsReq, devReq]) {
    if (!req) continue;

    const ticketTitle = req.title;
    const ticketDescription = `**Requirement**: REQ-${req.id}`;

    const priority = req.level === 'PRD' ? 1 : req.level === 'Ops' ? 2 : 3;

    console.log('--------------------------------------------------------------------------------');
    console.log(`LEVEL: ${req.level} | PRIORITY: P${priority}`);
    console.log('--------------------------------------------------------------------------------');
    console.log();
    console.log(`TITLE:`);
    console.log(`  ${ticketTitle}`);
    console.log();
    console.log(`DESCRIPTION:`);
    console.log(ticketDescription.split('\n').map(line => `  ${line}`).join('\n'));
    console.log();
}

console.log('================================================================================');
console.log(`Total tickets to be created: ${requirements.filter(r => r.id !== 'p00001').length}`);
console.log('================================================================================');
