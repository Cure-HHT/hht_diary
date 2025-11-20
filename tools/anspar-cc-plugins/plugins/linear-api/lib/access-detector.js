#!/usr/bin/env node
/**
 * Access Method Detector for Linear Integration
 *
 * Detects whether to use Linear MCP or Direct API access
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00053 (Development Environment and Tooling Setup)
 *
 * Supporting: CUR-390 - Linear MCP integration
 */

const fs = require('fs');
const path = require('path');

class AccessDetector {
  constructor() {
    this.cachedMethod = null;
    this.lastCheck = null;
    this.cacheTimeout = 60000; // 1 minute
    this.debug = process.env.DEBUG_LINEAR_ACCESS === 'true';
  }

  /**
   * Detect which access method is available
   * @param {Object} options
   * @param {boolean} options.preferMcp - Prefer MCP if both available (default true)
   * @param {boolean} options.forceRefresh - Force re-detection
   * @returns {Promise<string|null>} 'mcp', 'api', or null
   */
  async detect(options = {}) {
    const {
      preferMcp = true,
      forceRefresh = false
    } = options;

    // Return cached result if valid
    if (!forceRefresh && this.cachedMethod && this.isCacheValid()) {
      if (this.debug) {
        console.log(`🔧 Using cached access method: ${this.cachedMethod}`);
      }
      return this.cachedMethod;
    }

    let method = null;

    // Check in preference order
    if (preferMcp) {
      if (await this.isMcpAvailable()) {
        method = 'mcp';
      } else if (this.isApiTokenAvailable()) {
        method = 'api';
      }
    } else {
      if (this.isApiTokenAvailable()) {
        method = 'api';
      } else if (await this.isMcpAvailable()) {
        method = 'mcp';
      }
    }

    // Cache result
    this.cachedMethod = method;
    this.lastCheck = Date.now();

    if (this.debug) {
      console.log(`🔧 Detected access method: ${method || 'none'}`);
    }

    return method;
  }

  /**
   * Check if Linear MCP is available
   * Strategy: Check for .mcp.json configuration file
   * @returns {Promise<boolean>}
   */
  async isMcpAvailable() {
    try {
      // Check for MCP configuration files (project or user scope)
      const mcpConfigPaths = [
        path.join(process.cwd(), '.mcp.json'),                    // Project-scoped
        path.join(process.env.HOME || '', '.claude', '.mcp.json') // User-scoped
      ];

      for (const configPath of mcpConfigPaths) {
        if (fs.existsSync(configPath)) {
          try {
            const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

            // Check if Linear server is configured
            const hasLinear = this.checkForLinearInConfig(config);

            if (hasLinear) {
              if (this.debug) {
                console.log(`✓ Found Linear MCP config in: ${configPath}`);
              }
              return true;
            }
          } catch (err) {
            if (this.debug) {
              console.log(`⚠️  Error parsing ${configPath}:`, err.message);
            }
          }
        }
      }

      // No Linear MCP configuration found
      return false;

    } catch (error) {
      if (this.debug) {
        console.log('⚠️  Error checking MCP availability:', error.message);
      }
      return false;
    }
  }

  /**
   * Check if Linear is configured in MCP config
   * @private
   */
  checkForLinearInConfig(config) {
    // MCP config structure: { mcpServers: { "server-name": { ... } } }
    if (!config || !config.mcpServers) {
      return false;
    }

    // Check for Linear in any form (case-insensitive)
    const serverNames = Object.keys(config.mcpServers);
    return serverNames.some(name =>
      name.toLowerCase().includes('linear')
    );
  }

  /**
   * Check if API token is available
   * @returns {boolean}
   */
  isApiTokenAvailable() {
    return !!(process.env.LINEAR_API_TOKEN);
  }

  /**
   * Check if cache is still valid
   * @private
   */
  isCacheValid() {
    if (!this.lastCheck) return false;
    return (Date.now() - this.lastCheck) < this.cacheTimeout;
  }

  /**
   * Clear cached detection result
   */
  clearCache() {
    this.cachedMethod = null;
    this.lastCheck = null;
  }

  /**
   * Get diagnostic information
   * @returns {Object}
   */
  getDiagnostics() {
    return {
      cachedMethod: this.cachedMethod,
      lastCheck: this.lastCheck ? new Date(this.lastCheck).toISOString() : null,
      cacheValid: this.isCacheValid(),
      apiTokenAvailable: this.isApiTokenAvailable(),
      mcpConfigPaths: [
        path.join(process.cwd(), '.mcp.json'),
        path.join(process.env.HOME || '', '.claude', '.mcp.json')
      ],
      environment: {
        CLAUDE_CODE: process.env.CLAUDE_CODE || '(not set)',
        LINEAR_API_TOKEN: this.isApiTokenAvailable() ? 'configured' : 'not configured'
      }
    };
  }

  /**
   * Get a human-readable status message
   * @returns {string}
   */
  async getStatusMessage() {
    const method = await this.detect();

    if (!method) {
      return `❌ No Linear access method available.

      Options:
      1. Set LINEAR_API_TOKEN environment variable
      2. Configure Linear MCP in Claude Code (run: /mcp)

      For more help, see: tools/anspar-cc-plugins/plugins/linear-api/README.md`;
    }

    if (method === 'mcp') {
      return `✓ Using Linear MCP (OAuth-based access via Claude Code)`;
    }

    if (method === 'api') {
      return `✓ Using Linear API (Direct API access with authentication key)`;
    }

    return 'Unknown access method';
  }
}

// Export singleton
module.exports = new AccessDetector();
