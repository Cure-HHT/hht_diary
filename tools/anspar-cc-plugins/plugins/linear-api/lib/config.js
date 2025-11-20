#!/usr/bin/env node
/**
 * Central Configuration Module for Linear Integration Plugin
 *
 * Handles:
 * - Environment variable loading from multiple sources
 * - Path resolution relative to plugin root
 * - Token discovery and caching
 * - Default values and fallbacks
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Plugin root directory (5 levels up from scripts/lib/)
const PLUGIN_ROOT = path.resolve(__dirname, '..', '..');
const PROJECT_ROOT = path.resolve(PLUGIN_ROOT, '..', '..', '..');

/**
 * Configuration sources in priority order:
 * 1. Command line arguments (--token=xxx)
 * 2. Environment variables (LINEAR_API_TOKEN) - RECOMMENDED via Doppler
 * 3. Local .env file (deprecated - use Doppler instead)
 * 4. User config file (~/.config/linear/config)
 * 5. Legacy token file (~/.config/linear-api-token)
 */
class LinearConfig {
    constructor() {
        this.config = {
            token: null,
            teamId: null,
            apiEndpoint: 'https://api.linear.app/graphql',
            paths: {
                pluginRoot: PLUGIN_ROOT,
                projectRoot: PROJECT_ROOT,
                scripts: path.join(PLUGIN_ROOT, 'scripts'),
                lib: path.join(PLUGIN_ROOT, 'scripts', 'lib'),
                config: path.join(PLUGIN_ROOT, 'scripts', 'config'),
                cache: path.join(PLUGIN_ROOT, '.cache'),
            }
        };

        // Load configuration from all sources
        this.loadConfiguration();
    }

    /**
     * Load configuration from all available sources
     */
    loadConfiguration() {
        // 1. Check command line arguments
        this.loadFromArgs(process.argv);

        // 2. Check environment variables
        this.loadFromEnvironment();

        // 3. Check local .env file (deprecated - prefer Doppler)
        this.loadFromLocalEnv();

        // 4. Check saved config from auto-discovery
        this.loadFromSavedConfig();

        // 5. Check user config directory
        this.loadFromUserConfig();

        // 6. Check legacy token file
        this.loadFromLegacyToken();
    }

    /**
     * Load configuration from command line arguments
     */
    loadFromArgs(args) {
        for (const arg of args) {
            if (arg.startsWith('--token=')) {
                this.config.token = arg.split('=')[1];
            } else if (arg.startsWith('--team-id=')) {
                this.config.teamId = arg.split('=')[1];
            } else if (arg.startsWith('--api-endpoint=')) {
                this.config.apiEndpoint = arg.split('=')[1];
            }
        }
    }

    /**
     * Load from environment variables
     */
    loadFromEnvironment() {
        if (!this.config.token && process.env.LINEAR_API_TOKEN) {
            this.config.token = process.env.LINEAR_API_TOKEN;
        }
        if (!this.config.teamId && process.env.LINEAR_TEAM_ID) {
            this.config.teamId = process.env.LINEAR_TEAM_ID;
        }
    }

    /**
     * Load from local .env file (for this plugin)
     */
    loadFromLocalEnv() {
        const envPath = path.join(PLUGIN_ROOT, '.env.local');
        if (fs.existsSync(envPath)) {
            try {
                const envContent = fs.readFileSync(envPath, 'utf-8');
                const lines = envContent.split('\n');

                for (const line of lines) {
                    const trimmed = line.trim();
                    if (trimmed && !trimmed.startsWith('#')) {
                        const [key, ...valueParts] = trimmed.split('=');
                        const value = valueParts.join('=').replace(/^["']|["']$/g, '');

                        if (key === 'LINEAR_API_TOKEN' && !this.config.token) {
                            this.config.token = value;
                        } else if (key === 'LINEAR_TEAM_ID' && !this.config.teamId) {
                            this.config.teamId = value;
                        }
                    }
                }
            } catch (error) {
                // Silently ignore errors reading .env.local
            }
        }
    }

    /**
     * Load from user config directory
     */
    loadFromUserConfig() {
        const configPath = path.join(os.homedir(), '.config', 'linear', 'config');
        if (fs.existsSync(configPath)) {
            try {
                const configContent = fs.readFileSync(configPath, 'utf-8');
                const config = JSON.parse(configContent);

                if (!this.config.token && config.token) {
                    this.config.token = config.token;
                }
                if (!this.config.teamId && config.teamId) {
                    this.config.teamId = config.teamId;
                }
            } catch (error) {
                // Silently ignore errors reading user config
            }
        }
    }

    /**
     * Load from legacy token file
     */
    loadFromLegacyToken() {
        const tokenPath = path.join(os.homedir(), '.config', 'linear-api-token');
        if (!this.config.token && fs.existsSync(tokenPath)) {
            try {
                this.config.token = fs.readFileSync(tokenPath, 'utf-8').trim();
            } catch (error) {
                // Silently ignore errors reading legacy token
            }
        }
    }

    /**
     * Get the Linear API token
     * @param {boolean} required - Whether to exit if token is missing
     * @returns {string|null} The API token
     */
    getToken(required = true) {
        if (!this.config.token && required) {
            console.error('❌ Linear API token not found!');
            console.error('');
            console.error('Please provide your Linear API token using environment variables:');
            console.error('');
            console.error('1. RECOMMENDED - Use Doppler for secret management:');
            console.error('   doppler run -- claude');
            console.error('   (Automatically injects LINEAR_API_TOKEN from Doppler)');
            console.error('');
            console.error('2. Set environment variable directly:');
            console.error('   export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"');
            console.error('');
            console.error('3. Command line argument (for testing only):');
            console.error('   --token=YOUR_LINEAR_TOKEN');
            console.error('');
            console.error('Get your token from: https://linear.app/settings/api');
            console.error('');
            console.error('⚠️  Do not use .env files or commit secrets to git!');
            process.exit(1);
        }
        return this.config.token;
    }

    /**
     * Get the team ID
     * @param {boolean} required - Whether to exit if team ID is missing
     * @returns {string|null} The team ID
     */
    getTeamId(required = false) {
        if (!this.config.teamId && required) {
            console.error('❌ Linear team ID not found!');
            console.error('');
            console.error('Please provide your team ID using:');
            console.error('  --team-id=YOUR_TEAM_ID');
            console.error('  or');
            console.error('  export LINEAR_TEAM_ID="YOUR_TEAM_ID"');
            process.exit(1);
        }
        return this.config.teamId;
    }

    /**
     * Auto-discover team ID from Linear API
     * @returns {Promise<string|null>} The discovered team ID
     */
    async discoverTeamId() {
        const token = this.getToken(true);

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

        try {
            const response = await fetch(this.config.apiEndpoint, {
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
                console.log(`✓ Auto-discovered team: ${teams[0].name} (${teams[0].key})`);
                this.config.teamId = teams[0].id;

                // Save discovered configuration
                this.saveDiscoveredConfig(teams[0]);

                return teams[0].id;
            } else {
                // Multiple teams - show options
                console.log(`Found ${teams.length} teams:`);
                teams.forEach((team, i) => {
                    console.log(`  ${i + 1}. ${team.name} (${team.key}) - ID: ${team.id}`);
                });
                console.log('');
                console.log('Please specify team with --team-id=TEAM_ID');
                return null;
            }
        } catch (error) {
            console.error(`Failed to discover team ID: ${error.message}`);
            return null;
        }
    }

    /**
     * Get a path relative to the plugin root
     * @param {...string} segments - Path segments to join
     * @returns {string} The resolved path
     */
    getPath(...segments) {
        return path.join(PLUGIN_ROOT, ...segments);
    }

    /**
     * Get the API endpoint
     * @returns {string} The Linear API endpoint
     */
    getApiEndpoint() {
        return this.config.apiEndpoint;
    }

    /**
     * Get all configuration
     * @returns {Object} The complete configuration object
     */
    getConfig() {
        return this.config;
    }

    /**
     * Create cache directory if it doesn't exist
     */
    ensureCacheDir() {
        const cacheDir = this.config.paths.cache;
        if (!fs.existsSync(cacheDir)) {
            fs.mkdirSync(cacheDir, { recursive: true });
        }
        return cacheDir;
    }

    /**
     * Save discovered configuration to local config file
     * @param {Object} team - Team information from Linear
     */
    saveDiscoveredConfig(team) {
        try {
            const configPath = path.join(PLUGIN_ROOT, '.linear-config.json');
            const configData = {
                teamId: team.id,
                teamName: team.name,
                teamKey: team.key,
                discoveredAt: new Date().toISOString()
            };

            fs.writeFileSync(configPath, JSON.stringify(configData, null, 2));
            console.log(`   Configuration saved to ${configPath}`);
        } catch (error) {
            // Silently fail - not critical
            console.log(`   (Could not save config: ${error.message})`);
        }
    }

    /**
     * Load saved configuration from .linear-config.json
     */
    loadFromSavedConfig() {
        const configPath = path.join(PLUGIN_ROOT, '.linear-config.json');
        if (fs.existsSync(configPath)) {
            try {
                const savedConfig = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
                if (!this.config.teamId && savedConfig.teamId) {
                    this.config.teamId = savedConfig.teamId;
                }
            } catch (error) {
                // Silently ignore errors
            }
        }
    }

    /**
     * Get access method information (MCP vs API)
     * @returns {Promise<Object>} Access method diagnostics
     */
    async getAccessInfo() {
        try {
            const linearAdapter = require('./linear-adapter');
            return await linearAdapter.getDiagnostics();
        } catch (error) {
            return {
                error: error.message,
                note: 'Linear adapter not initialized'
            };
        }
    }

    /**
     * Get diagnostic information for troubleshooting
     * @returns {Object} Complete diagnostic information
     */
    getDiagnostics() {
        // Step 1: Internal detection - check what credentials/configs exist
        const hasApiCredentials = !!this.config.token;
        const hasTeamConfig = !!this.config.teamId;
        const hasEnvCredentials = !!process.env.LINEAR_API_TOKEN;
        const hasTeamEnv = !!process.env.LINEAR_TEAM_ID;

        // Step 2: Report availability without exposing implementation details
        return {
            configuration: {
                apiAccessAvailable: hasApiCredentials,
                teamIdAvailable: hasTeamConfig,
                apiEndpoint: this.config.apiEndpoint,
                paths: this.config.paths
            },
            environment: {
                directApiAccess: hasEnvCredentials ? 'available' : 'not available',
                teamIdConfigured: hasTeamEnv ? 'available' : 'not available',
                NODE_VERSION: process.version,
                PLATFORM: process.platform
            },
            configSources: {
                cliArguments: hasApiCredentials ? 'credentials provided' : 'not used',
                environmentVariables: hasEnvCredentials ? 'credentials available' : 'not available',
                localEnvFile: fs.existsSync(path.join(PLUGIN_ROOT, '.env.local')),
                userConfig: fs.existsSync(path.join(os.homedir(), '.config', 'linear', 'config')),
                legacyAuthFile: fs.existsSync(path.join(os.homedir(), '.config', 'linear-api-token')),
                savedConfig: fs.existsSync(path.join(PLUGIN_ROOT, '.linear-config.json'))
            }
        };
    }
}

// Export singleton instance
module.exports = new LinearConfig();