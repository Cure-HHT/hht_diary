#!/usr/bin/env node
/**
 * List all tickets with security, compliance, or infrastructure labels
 */

const fs = require('fs');

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

// Filter tickets with security, compliance, or infrastructure labels
const targetLabels = ['security', 'compliance', 'infrastructure'];

const relevantTickets = allTickets.filter(t => {
    if (!t.labels || !t.labels.nodes) return false;
    const labelNames = t.labels.nodes.map(l => l.name.toLowerCase());
    return targetLabels.some(target => labelNames.includes(target));
});

// Sort by label for easier review
const byLabel = {
    security: [],
    compliance: [],
    infrastructure: []
};

for (const ticket of relevantTickets) {
    const labelNames = ticket.labels.nodes.map(l => l.name.toLowerCase());
    if (labelNames.includes('security')) byLabel.security.push(ticket);
    if (labelNames.includes('compliance')) byLabel.compliance.push(ticket);
    if (labelNames.includes('infrastructure')) byLabel.infrastructure.push(ticket);
}

console.log('================================================================================');
console.log('TICKETS WITH SECURITY / COMPLIANCE / INFRASTRUCTURE LABELS');
console.log('================================================================================');
console.log();
console.log(`Total relevant tickets: ${relevantTickets.length}`);
console.log(`  Security: ${byLabel.security.length}`);
console.log(`  Compliance: ${byLabel.compliance.length}`);
console.log(`  Infrastructure: ${byLabel.infrastructure.length}`);
console.log();

function printTickets(label, tickets) {
    console.log('--------------------------------------------------------------------------------');
    console.log(`${label.toUpperCase()} LABELED TICKETS`);
    console.log('--------------------------------------------------------------------------------');

    for (const ticket of tickets) {
        const hasReq = (ticket.description || '').toLowerCase().includes('req-');
        const reqMarker = hasReq ? ' ✅ HAS REQ' : ' ⚠️  NO REQ';

        console.log();
        console.log(`${ticket.identifier}: ${ticket.title}${reqMarker}`);
        console.log(`  Status: ${ticket.state.name} | State Type: ${ticket.state.type}`);

        if (ticket.project) {
            console.log(`  Project: ${ticket.project.name}`);
        }

        const allLabels = ticket.labels.nodes.map(l => l.name).join(', ');
        console.log(`  Labels: ${allLabels}`);

        if (ticket.description) {
            const lines = ticket.description.split('\n');
            const preview = lines.slice(0, 4).join('\n    ');
            console.log(`  Description:`);
            console.log(`    ${preview}`);
            if (lines.length > 4) {
                console.log(`    ... (${lines.length - 4} more lines)`);
            }
        } else {
            console.log(`  Description: (empty)`);
        }

        console.log(`  URL: ${ticket.url}`);
    }
}

printTickets('Security', byLabel.security);
console.log();
printTickets('Compliance', byLabel.compliance);
console.log();
printTickets('Infrastructure', byLabel.infrastructure);

console.log();
console.log('================================================================================');
console.log('ANALYSIS NOTES');
console.log('================================================================================');
console.log();
console.log('Review each ticket above and determine if it matches any requirement from:');
console.log('  - prd-security*.md files (PRD security requirements)');
console.log('  - ops-security*.md files (Ops security requirements)');
console.log('  - dev-security*.md files (Dev security requirements)');
console.log('  - prd-clinical-trials.md (compliance requirements)');
console.log('  - ops-deployment.md (infrastructure requirements)');
console.log('  - dev-app.md (app build/release requirements)');
console.log();
