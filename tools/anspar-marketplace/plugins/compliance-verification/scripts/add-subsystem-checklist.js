#!/usr/bin/env node
/**
 * Add sub-system checklists to Linear tickets
 *
 * Analyzes each ticket's requirement and adds a checklist of
 * relevant sub-systems (Supabase, GitHub, Google Workspace, etc.)
 *
 * Usage:
 *   node add-subsystem-checklist.js --token=<token> [--dry-run]
 */

const fs = require('fs');
const path = require('path');

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// Parse command line arguments
function parseArgs() {
    const args = {
        token: null,
        dryRun: false,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--token=')) {
            args.token = arg.split('=')[1];
        } else if (arg === '--dry-run') {
            args.dryRun = true;
        }
    }

    if (!args.token) {
        console.error('Error: --token is required');
        console.error('Usage: node add-subsystem-checklist.js --token=<token> [--dry-run]');
        process.exit(1);
    }

    return args;
}

/**
 * Define sub-systems and their keywords
 */
const SUBSYSTEMS = {
    'Supabase (Database & Auth)': [
        'database', 'supabase', 'schema', 'rls', 'row level security', 'postgres',
        'auth', 'authentication', 'user', 'role', 'permission', 'access', 'data',
        'table', 'query', 'sql', 'event sourcing', 'audit'
    ],
    'Mobile App (Flutter)': [
        'mobile', 'app', 'flutter', 'dart', 'offline', 'local', 'sync',
        'patient', 'diary', 'entry', 'ui', 'interface'
    ],
    'Web Portal': [
        'web', 'portal', 'sponsor', 'dashboard', 'browser', 'frontend',
        'investigator', 'analyst'
    ],
    'Development Environment': [
        'dev environment', 'development', 'tooling', 'ide', 'setup', 'install',
        'configuration', 'local', 'docker', 'vscode', 'claude code'
    ],
    'CI/CD Pipeline (GitHub Actions)': [
        'ci/cd', 'pipeline', 'github actions', 'deployment', 'build', 'test',
        'automation', 'workflow'
    ],
    'Google Workspace': [
        'google workspace', 'gmail', 'google', 'email', 'workspace',
        'mfa', 'multi-factor', '2fa', 'sso'
    ],
    'GitHub': [
        'github', 'repository', 'git', 'version control', 'package registry',
        'code', 'commit'
    ],
    'Doppler (Secrets Management)': [
        'doppler', 'secrets', 'credentials', 'api key', 'token', 'environment variable',
        'config'
    ],
    'Netlify (Web Hosting)': [
        'netlify', 'hosting', 'deploy', 'cdn', 'web hosting'
    ],
    'Linear (Project Management)': [
        'linear', 'ticket', 'issue', 'project management', 'tracking'
    ],
    'Compliance & Documentation': [
        'compliance', 'fda', 'alcoa', '21 cfr part 11', 'requirement', 'traceability',
        'documentation', 'adr', 'validation', 'audit trail'
    ],
    'Backup & Recovery': [
        'backup', 'recovery', 'retention', 'restore', 'archive'
    ]
};

/**
 * Analyze a ticket and determine relevant sub-systems
 */
function analyzeSubsystems(ticket, requirementContent) {
    const text = (
        ticket.title + ' ' +
        ticket.description + ' ' +
        requirementContent
    ).toLowerCase();

    const relevantSubsystems = [];

    for (const [subsystem, keywords] of Object.entries(SUBSYSTEMS)) {
        for (const keyword of keywords) {
            if (text.includes(keyword.toLowerCase())) {
                relevantSubsystems.push(subsystem);
                break;
            }
        }
    }

    // Special handling for cross-cutting concerns
    // Security and access control requirements apply to ALL systems
    if (text.match(/\b(rbac|role.based|access control|permission|privilege|least privilege|authentication|authorization)\b/i)) {
        const securitySubsystems = [
            'Supabase (Database & Auth)',
            'Google Workspace',
            'GitHub',
            'Doppler (Secrets Management)',
            'Development Environment',
            'Netlify (Web Hosting)',
            'Linear (Project Management)'
        ];
        for (const subsystem of securitySubsystems) {
            if (!relevantSubsystems.includes(subsystem)) {
                relevantSubsystems.push(subsystem);
            }
        }
    }

    // Remove duplicates and sort
    return [...new Set(relevantSubsystems)].sort();
}

/**
 * Read requirement from spec files
 */
function findRequirement(reqId) {
    const specDir = path.join(__dirname, '../../../../spec');
    const files = fs.readdirSync(specDir).filter(f => f.endsWith('.md'));

    for (const file of files) {
        const content = fs.readFileSync(path.join(specDir, file), 'utf-8');
        const reqPattern = new RegExp(`###\\s+${reqId}:([^#]+)`, 's');
        const match = content.match(reqPattern);
        if (match) {
            return match[1].trim();
        }
    }

    return '';
}

/**
 * Build new description with subsystem checklist
 */
function buildDescription(ticket, subsystems) {
    const reqMatch = ticket.description.match(/\*\*Requirement\*\*:\s+(REQ-\w+)/);
    if (!reqMatch) {
        return ticket.description;
    }

    const reqId = reqMatch[1];
    let newDesc = `**Requirement**: ${reqId}\n\n`;

    if (subsystems.length > 0) {
        newDesc += `**Sub-systems**:\n`;
        for (const subsystem of subsystems) {
            newDesc += `- [ ] ${subsystem}\n`;
        }
        newDesc += '\n';
    }

    // Preserve any existing content after the requirement line
    const existingContent = ticket.description.split('\n').slice(1).join('\n').trim();
    if (existingContent && !existingContent.startsWith('**Sub-systems**')) {
        newDesc += existingContent;
    }

    return newDesc.trim();
}

/**
 * Update ticket description
 */
async function updateTicket(apiToken, ticketId, description) {
    const mutation = `
        mutation UpdateIssue($issueId: String!, $description: String!) {
            issueUpdate(id: $issueId, input: { description: $description }) {
                success
                issue {
                    id
                    identifier
                }
            }
        }
    `;

    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': apiToken,
        },
        body: JSON.stringify({
            query: mutation,
            variables: { issueId: ticketId, description }
        }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    return result.data.issueUpdate;
}

/**
 * Main function
 */
async function main() {
    const args = parseArgs();

    // Read tickets from /tmp/ai_new_tickets.json
    const ticketsFile = '/tmp/ai_new_tickets.json';
    if (!fs.existsSync(ticketsFile)) {
        console.error('Error: /tmp/ai_new_tickets.json not found');
        console.error('Run: node fetch-tickets-by-label.js --token=<token> --label="ai:new" > /tmp/ai_new_tickets.json');
        process.exit(1);
    }

    const tickets = JSON.parse(fs.readFileSync(ticketsFile, 'utf-8'));

    console.log('================================================================================');
    console.log('ADD SUB-SYSTEM CHECKLISTS TO LINEAR TICKETS');
    console.log('================================================================================');
    console.log('');
    console.log(`Found ${tickets.length} tickets with ai:new label`);
    console.log('');

    if (args.dryRun) {
        console.log('🔍 DRY RUN MODE - No tickets will be updated');
        console.log('');
    }

    let updated = 0;
    let skipped = 0;

    for (const ticket of tickets) {
        // Extract requirement ID
        const reqMatch = ticket.description.match(/\*\*Requirement\*\*:\s+(REQ-\w+)/);
        if (!reqMatch) {
            console.log(`⚠️  ${ticket.identifier}: No requirement found, skipping`);
            skipped++;
            continue;
        }

        const reqId = reqMatch[1];

        // Check if already has sub-system checklist
        if (ticket.description.includes('**Sub-systems**')) {
            console.log(`⏭️  ${ticket.identifier}: Already has sub-system checklist, skipping`);
            skipped++;
            continue;
        }

        // Find requirement content
        const reqContent = findRequirement(reqId);

        // Analyze sub-systems
        const subsystems = analyzeSubsystems(ticket, reqContent);

        if (subsystems.length === 0) {
            console.log(`⚠️  ${ticket.identifier}: No sub-systems identified, skipping`);
            skipped++;
            continue;
        }

        // Build new description
        const newDescription = buildDescription(ticket, subsystems);

        if (args.dryRun) {
            console.log(`Would update ${ticket.identifier}: ${ticket.title}`);
            console.log(`  Sub-systems (${subsystems.length}): ${subsystems.join(', ')}`);
        } else {
            try {
                await updateTicket(args.token, ticket.id, newDescription);
                console.log(`✅ ${ticket.identifier}: ${ticket.title}`);
                console.log(`   Added ${subsystems.length} sub-systems: ${subsystems.join(', ')}`);
                updated++;

                // Rate limit: 100ms between requests
                await new Promise(resolve => setTimeout(resolve, 100));
            } catch (error) {
                console.error(`❌ ${ticket.identifier}: ${error.message}`);
            }
        }
    }

    console.log('');
    console.log('================================================================================');
    console.log('SUMMARY');
    console.log('================================================================================');
    console.log(`Total tickets: ${tickets.length}`);
    if (!args.dryRun) {
        console.log(`Successfully updated: ${updated}`);
    }
    console.log(`Skipped: ${skipped}`);
    console.log('');
}

main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
