#!/usr/bin/env node
/**
 * List all infrastructure-related tickets for manual review
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

// Filter infrastructure-related tickets
const infraProjects = [
    'DevOps Environment Bootstrap',
    'Development Environment Ready',
    'Compliance Setup'
];

const infraTickets = allTickets.filter(t =>
    t.project && infraProjects.includes(t.project.name)
);

// Also get tickets without project but infrastructure-related
const infraKeywords = ['deploy', 'ci/cd', 'pipeline', 'setup', 'install', 'configure', 'infrastructure', 'supabase', 'netlify'];
const otherInfraTickets = allTickets.filter(t => {
    const text = (t.title + ' ' + (t.description || '')).toLowerCase();
    return !t.project && infraKeywords.some(kw => text.includes(kw));
});

console.log('================================================================================');
console.log('INFRASTRUCTURE-RELATED TICKETS');
console.log('================================================================================');
console.log();
console.log(`Found ${infraTickets.length} tickets in infrastructure projects`);
console.log(`Found ${otherInfraTickets.length} other infrastructure-related tickets`);
console.log();

console.log('--------------------------------------------------------------------------------');
console.log('INFRASTRUCTURE PROJECT TICKETS');
console.log('--------------------------------------------------------------------------------');
for (const ticket of infraTickets) {
    const hasReq = (ticket.description || '').includes('REQ-');
    const reqMarker = hasReq ? ' ✅ HAS REQ' : ' ⚠️  NO REQ';
    console.log();
    console.log(`${ticket.identifier}: ${ticket.title}${reqMarker}`);
    console.log(`  Project: ${ticket.project.name}`);
    console.log(`  Status: ${ticket.state.name}`);
    if (ticket.description) {
        const lines = ticket.description.split('\n');
        const preview = lines.slice(0, 3).join('\n    ');
        console.log(`  Description: ${preview}`);
        if (lines.length > 3) {
            console.log(`    ... (${lines.length - 3} more lines)`);
        }
    }
}

console.log();
console.log('--------------------------------------------------------------------------------');
console.log('OTHER INFRASTRUCTURE TICKETS (no project)');
console.log('--------------------------------------------------------------------------------');
for (const ticket of otherInfraTickets) {
    const hasReq = (ticket.description || '').includes('REQ-');
    const reqMarker = hasReq ? ' ✅ HAS REQ' : ' ⚠️  NO REQ';
    console.log();
    console.log(`${ticket.identifier}: ${ticket.title}${reqMarker}`);
    console.log(`  Status: ${ticket.state.name}`);
    if (ticket.description) {
        const lines = ticket.description.split('\n');
        const preview = lines.slice(0, 3).join('\n    ');
        console.log(`  Description: ${preview}`);
        if (lines.length > 3) {
            console.log(`    ... (${lines.length - 3} more lines)`);
        }
    }
}

console.log();
console.log('================================================================================');
console.log(`Total infrastructure tickets: ${infraTickets.length + otherInfraTickets.length}`);
console.log('================================================================================');
