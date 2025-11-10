#!/usr/bin/env node
/**
 * Environment Variable Validation for Linear Integration Plugin
 *
 * This module checks for required environment variables at script startup.
 *
 * FUTURE: This will be enhanced to fetch secrets from Doppler or other
 * secret management systems instead of relying on environment variables.
 * See: https://www.doppler.com/ or similar secret management solutions.
 *
 * Current behavior:
 * - Checks for LINEAR_API_TOKEN (required)
 * - Checks for LINEAR_TEAM_ID (optional, can be auto-discovered)
 * - Reports which variables are set (NOT their values for security)
 * - Auto-discovers LINEAR_TEAM_ID if not set
 */

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

/**
 * Check and validate Linear environment variables
 *
 * @param {Object} options - Configuration options
 * @param {boolean} options.requireToken - Whether LINEAR_API_TOKEN is required
 * @param {boolean} options.requireTeamId - Whether LINEAR_TEAM_ID is required
 * @param {boolean} options.autoDiscover - Auto-discover LINEAR_TEAM_ID if missing
 * @param {boolean} options.silent - Suppress output messages
 * @returns {Object} { token, teamId, discovered }
 */
async function validateEnvironment(options = {}) {
    const {
        requireToken = true,
        requireTeamId = false,
        autoDiscover = true,
        silent = false
    } = options;

    const result = {
        token: null,
        teamId: null,
        discovered: false
    };

    if (!silent) {
        console.log('🔧 Checking environment variables...');
        console.log('');
    }

    // Check LINEAR_API_TOKEN
    if (process.env.LINEAR_API_TOKEN) {
        result.token = process.env.LINEAR_API_TOKEN;
        if (!silent) {
            console.log('✓ Using LINEAR_API_TOKEN from environment');
        }
    } else if (requireToken) {
        console.error('✗ LINEAR_API_TOKEN is not set');
        console.error('');
        console.error('Please set your Linear API token:');
        console.error('  export LINEAR_API_TOKEN="lin_api_..."');
        console.error('');
        console.error('Get your token from: https://linear.app/settings/api');
        console.error('');
        console.error('FUTURE: Secrets will be fetched from Doppler or similar');
        console.error('        secret management system automatically.');
        process.exit(1);
    }

    // Check LINEAR_TEAM_ID
    if (process.env.LINEAR_TEAM_ID) {
        result.teamId = process.env.LINEAR_TEAM_ID;
        if (!silent) {
            console.log('✓ Using LINEAR_TEAM_ID from environment');
        }
    } else if (autoDiscover && result.token) {
        if (!silent) {
            console.log('⚡ LINEAR_TEAM_ID not set, auto-discovering...');
        }

        try {
            const teamId = await discoverTeamId(result.token, silent);
            if (teamId) {
                result.teamId = teamId;
                result.discovered = true;
                if (!silent) {
                    console.log('✓ Successfully discovered LINEAR_TEAM_ID');
                    console.log('');
                    console.log('  To avoid auto-discovery in the future, add to ~/.bashrc:');
                    console.log(`  export LINEAR_TEAM_ID="${teamId}"`);
                }
            }
        } catch (error) {
            if (!silent) {
                console.error(`✗ Failed to auto-discover LINEAR_TEAM_ID: ${error.message}`);
            }
            if (requireTeamId) {
                process.exit(1);
            }
        }
    } else if (requireTeamId) {
        console.error('✗ LINEAR_TEAM_ID is not set and auto-discovery is disabled');
        console.error('');
        console.error('Please run: source tools/anspar-cc-plugins/plugins/linear-api/scripts/setup-env.sh');
        console.error('Or set manually: export LINEAR_TEAM_ID="your-team-id"');
        process.exit(1);
    }

    if (!silent) {
        console.log('');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('');
    }

    return result;
}

/**
 * Auto-discover LINEAR_TEAM_ID by querying Linear API
 *
 * @param {string} token - Linear API token
 * @param {boolean} silent - Suppress output
 * @returns {string|null} Team ID or null if not found
 */
async function discoverTeamId(token, silent = false) {
    const query = `
        query {
            viewer {
                organization {
                    teams {
                        nodes {
                            id
                            key
                            name
                        }
                    }
                }
            }
        }
    `;

    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': token,
        },
        body: JSON.stringify({ query }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    const teams = result.data?.viewer?.organization?.teams?.nodes || [];

    if (teams.length === 0) {
        throw new Error('No teams found for this Linear account');
    }

    if (teams.length === 1) {
        // Single team - auto-select
        if (!silent) {
            console.log(`  Found team: ${teams[0].name} (${teams[0].key})`);
        }
        return teams[0].id;
    } else {
        // Multiple teams - cannot auto-select
        if (!silent) {
            console.log('');
            console.log(`  Found ${teams.length} teams:`);
            teams.forEach((team, i) => {
                console.log(`    ${i + 1}. ${team.name} (${team.key})`);
            });
            console.log('');
            console.log('  Please set LINEAR_TEAM_ID manually to select a team:');
            console.log(`  export LINEAR_TEAM_ID="${teams[0].id}"  # ${teams[0].name}`);
        }
        return null;
    }
}

/**
 * Get environment variables from command line args or environment
 * Checks for --token and --team-id flags first, falls back to env vars
 *
 * @param {Array} args - Command line arguments (process.argv)
 * @returns {Object} { token, teamId }
 */
function getCredentialsFromArgs(args) {
    const result = {
        token: process.env.LINEAR_API_TOKEN || null,
        teamId: process.env.LINEAR_TEAM_ID || null,
    };

    for (const arg of args) {
        if (arg.startsWith('--token=')) {
            result.token = arg.split('=')[1];
        } else if (arg.startsWith('--team-id=')) {
            result.teamId = arg.split('=')[1];
        }
    }

    return result;
}

module.exports = {
    validateEnvironment,
    discoverTeamId,
    getCredentialsFromArgs,
};
