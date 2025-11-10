#!/usr/bin/env node
/**
 * Team Resolver for Linear Integration
 *
 * Handles team ID discovery and caching with:
 * - Auto-discovery of teams
 * - Persistent caching of discovered team
 * - Team selection helpers
 */

const fs = require('fs');
const path = require('path');
const config = require('./config');
const graphql = require('./graphql-client');

class TeamResolver {
    constructor() {
        this.cachedTeamId = null;
        this.configFile = path.join(config.getPath(), '.linear-config.json');
    }

    /**
     * Get the current team ID, discovering if necessary
     * @param {Object} options
     * @param {boolean} options.forceDiscover - Force re-discovery even if cached
     * @param {boolean} options.silent - Suppress console output
     * @returns {Promise<string>} The team ID
     * @throws {Error} If no team can be determined
     */
    async getTeamId(options = {}) {
        const { forceDiscover = false, silent = false } = options;

        // 1. Check if already cached in memory
        if (this.cachedTeamId && !forceDiscover) {
            return this.cachedTeamId;
        }

        // 2. Check config module
        const configTeamId = config.getTeamId(false);
        if (configTeamId && !forceDiscover) {
            this.cachedTeamId = configTeamId;
            return configTeamId;
        }

        // 3. Check saved config file
        const savedTeamId = this._loadSavedTeamId();
        if (savedTeamId && !forceDiscover) {
            this.cachedTeamId = savedTeamId;
            if (!silent) {
                console.log(`✓ Using saved team ID from ${path.basename(this.configFile)}`);
            }
            return savedTeamId;
        }

        // 4. Auto-discover from API
        if (!silent) {
            console.log('⚡ LINEAR_TEAM_ID not set, auto-discovering...');
        }

        const teams = await this.listTeams();

        if (teams.length === 0) {
            throw new Error('No teams found for this Linear account');
        }

        if (teams.length === 1) {
            // Single team - auto-select and save
            const team = teams[0];
            this.cachedTeamId = team.id;

            if (!silent) {
                console.log(`  Found team: ${team.name} (${team.key})`);
                console.log(`✓ Successfully discovered LINEAR_TEAM_ID`);
            }

            // Save for future use
            this._saveTeamConfig(team);

            return team.id;
        } else {
            // Multiple teams - require manual selection
            if (!silent) {
                console.log(`\n⚠️  Found ${teams.length} teams. Please specify which one to use:`);
                console.log('━'.repeat(50));
                teams.forEach((team, i) => {
                    console.log(`  ${i + 1}. ${team.name} (${team.key})`);
                    console.log(`     ID: ${team.id}`);
                });
                console.log('━'.repeat(50));
                console.log('\nTo select a team:');
                console.log('  1. Set environment variable:');
                console.log(`     export LINEAR_TEAM_ID="${teams[0].id}"`);
                console.log('  2. Or pass as argument:');
                console.log(`     --team-id="${teams[0].id}"`);
                console.log('  3. Or save to config:');
                console.log(`     echo '{"teamId":"${teams[0].id}"}' > ~/.config/linear/config`);
            }

            throw new Error('Multiple teams found. Please specify LINEAR_TEAM_ID');
        }
    }

    /**
     * List all available teams for the current user
     * @returns {Promise<Array>} Array of team objects
     */
    async listTeams() {
        const query = `
            query GetTeams {
                viewer {
                    teams {
                        nodes {
                            id
                            key
                            name
                            description
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(query);
        return data.viewer?.teams?.nodes || [];
    }

    /**
     * Get detailed information about a specific team
     * @param {string} teamId - The team ID
     * @returns {Promise<Object>} Team details
     */
    async getTeamDetails(teamId = null) {
        const id = teamId || await this.getTeamId();

        const query = `
            query GetTeamDetails($id: String!) {
                team(id: $id) {
                    id
                    key
                    name
                    description
                    createdAt
                    updatedAt
                    private
                    issueCount
                    projectCount: projects { totalCount }
                    memberCount: members { totalCount }
                }
            }
        `;

        const data = await graphql.execute(query, { id });
        return data.team;
    }

    /**
     * Save team configuration to file
     * @private
     */
    _saveTeamConfig(team) {
        try {
            const configData = {
                teamId: team.id,
                teamName: team.name,
                teamKey: team.key,
                discoveredAt: new Date().toISOString()
            };

            // Ensure directory exists
            const dir = path.dirname(this.configFile);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            fs.writeFileSync(this.configFile, JSON.stringify(configData, null, 2));
            console.log(`   Configuration saved to ${path.relative(process.cwd(), this.configFile)}`);
        } catch (error) {
            // Not critical if save fails
            console.log(`   (Could not save config: ${error.message})`);
        }
    }

    /**
     * Load saved team ID from config file
     * @private
     * @returns {string|null} The saved team ID or null
     */
    _loadSavedTeamId() {
        if (!fs.existsSync(this.configFile)) {
            return null;
        }

        try {
            const configData = JSON.parse(fs.readFileSync(this.configFile, 'utf-8'));
            return configData.teamId || null;
        } catch (error) {
            // Silently ignore parse errors
            return null;
        }
    }

    /**
     * Clear cached team ID (useful for testing or switching teams)
     */
    clearCache() {
        this.cachedTeamId = null;
        if (fs.existsSync(this.configFile)) {
            try {
                fs.unlinkSync(this.configFile);
                console.log('✓ Cleared saved team configuration');
            } catch (error) {
                console.error(`⚠️  Could not delete config file: ${error.message}`);
            }
        }
    }

    /**
     * Validate that a team ID exists and is accessible
     * @param {string} teamId - The team ID to validate
     * @returns {Promise<boolean>} True if valid, false otherwise
     */
    async validateTeamId(teamId) {
        try {
            const query = `
                query ValidateTeam($id: String!) {
                    team(id: $id) {
                        id
                        key
                        name
                    }
                }
            `;

            const data = await graphql.execute(query, { id: teamId });
            return !!data.team;
        } catch (error) {
            return false;
        }
    }
}

// Export singleton instance
module.exports = new TeamResolver();