#!/usr/bin/env node
/**
 * Linear Adapter - Unified interface for API and MCP access
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00053 (Development Environment and Tooling Setup)
 *
 * Supporting: CUR-390 - Linear MCP integration
 *
 * This adapter provides a unified interface for Linear operations,
 * automatically routing to either MCP (when available) or direct API
 * (when LINEAR_API_TOKEN is set).
 */

const accessDetector = require('./access-detector');
const mcpClient = require('./mcp-client');

class LinearAdapter {
  constructor() {
    this.accessMethod = null;
    this.initialized = false;
    this.debug = process.env.DEBUG_LINEAR_ADAPTER === 'true';
  }

  /**
   * Initialize adapter - detect and configure access method
   * @returns {Promise<void>}
   */
  async initialize() {
    if (this.initialized) return;

    this.accessMethod = await accessDetector.detect();

    if (!this.accessMethod) {
      const statusMsg = await accessDetector.getStatusMessage();
      throw new Error(statusMsg);
    }

    if (this.debug) {
      console.log(`🔧 Linear adapter initialized with: ${this.accessMethod}`);
    }

    this.initialized = true;
  }

  /**
   * Create an issue
   * @param {Object} params - Issue creation parameters
   * @returns {Promise<Object>} Created issue or MCP instruction
   */
  async createIssue(params) {
    await this.initialize();

    try {
      if (this.accessMethod === 'mcp') {
        return await mcpClient.createIssue(params);
      } else {
        // Use existing API implementation
        const graphqlClient = require('./graphql-client');
        const teamId = params.teamId || await this.getDefaultTeamId();

        // Build GraphQL mutation
        const mutation = `
          mutation CreateIssue($title: String!, $description: String, $teamId: String!, $priority: Int, $labelIds: [String!]) {
            issueCreate(input: {
              title: $title
              description: $description
              teamId: $teamId
              priority: $priority
              labelIds: $labelIds
            }) {
              success
              issue {
                id
                identifier
                title
                url
              }
            }
          }
        `;

        const result = await graphqlClient.execute(mutation, {
          title: params.title,
          description: params.description,
          teamId,
          priority: params.priority,
          labelIds: params.labelIds
        });

        return result.issueCreate.issue;
      }
    } catch (error) {
      return await this.handleError('createIssue', error, params);
    }
  }

  /**
   * Get an issue by ID
   * @param {string} id - Issue ID or identifier
   * @returns {Promise<Object>} Issue object or MCP instruction
   */
  async getIssue(id) {
    await this.initialize();

    try {
      if (this.accessMethod === 'mcp') {
        return await mcpClient.getIssue(id);
      } else {
        // Use existing ticket-fetcher logic
        const graphqlClient = require('./graphql-client');

        const query = `
          query GetIssue($id: String!) {
            issue(id: $id) {
              id
              identifier
              title
              description
              state {
                name
                type
              }
              priority
              priorityLabel
              labels {
                nodes {
                  id
                  name
                }
              }
              url
            }
          }
        `;

        const result = await graphqlClient.execute(query, { id });
        return result.issue;
      }
    } catch (error) {
      return await this.handleError('getIssue', error, id);
    }
  }

  /**
   * Update an issue
   * @param {string} id - Issue ID or identifier
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated issue or MCP instruction
   */
  async updateIssue(id, updates) {
    await this.initialize();

    try {
      if (this.accessMethod === 'mcp') {
        return await mcpClient.updateIssue(id, updates);
      } else {
        // Use existing API implementation
        const graphqlClient = require('./graphql-client');

        const mutation = `
          mutation UpdateIssue($id: String!, $title: String, $description: String, $stateId: String, $priority: Int) {
            issueUpdate(id: $id, input: {
              title: $title
              description: $description
              stateId: $stateId
              priority: $priority
            }) {
              success
              issue {
                id
                identifier
                title
                url
              }
            }
          }
        `;

        const result = await graphqlClient.execute(mutation, {
          id,
          ...updates
        });

        return result.issueUpdate.issue;
      }
    } catch (error) {
      return await this.handleError('updateIssue', error, { id, updates });
    }
  }

  /**
   * Search issues
   * @param {string|Object} query - Search query or filter object
   * @returns {Promise<Array|Object>} Matching issues or MCP instruction
   */
  async searchIssues(query) {
    await this.initialize();

    try {
      if (this.accessMethod === 'mcp') {
        return await mcpClient.searchIssues(query);
      } else {
        // Use existing API implementation
        const graphqlClient = require('./graphql-client');
        const teamId = await this.getDefaultTeamId();

        const gqlQuery = `
          query SearchIssues($teamId: String!, $filter: IssueFilter) {
            team(id: $teamId) {
              issues(filter: $filter, first: 50) {
                nodes {
                  id
                  identifier
                  title
                  description
                  state {
                    name
                    type
                  }
                  priority
                  priorityLabel
                  url
                }
              }
            }
          }
        `;

        const filter = typeof query === 'string'
          ? { title: { contains: query } }
          : query;

        const result = await graphqlClient.execute(gqlQuery, { teamId, filter });
        return result.team.issues.nodes;
      }
    } catch (error) {
      return await this.handleError('searchIssues', error, query);
    }
  }

  /**
   * Handle errors with fallback logic
   * @private
   */
  async handleError(operation, error, params) {
    if (this.debug) {
      console.error(`❌ ${operation} failed with ${this.accessMethod}:`, error.message);
    }

    // If MCP failed, try API as fallback
    if (this.accessMethod === 'mcp' && accessDetector.isApiAvailable()) {
      if (this.debug) {
        console.log(`🔄 Falling back to API for ${operation}`);
      }

      this.accessMethod = 'api';
      this.initialized = false;
      await this.initialize();

      // Retry with API
      switch (operation) {
        case 'createIssue':
          return await this.createIssue(params);
        case 'getIssue':
          return await this.getIssue(params);
        case 'updateIssue':
          return await this.updateIssue(params.id, params.updates);
        case 'searchIssues':
          return await this.searchIssues(params);
      }
    }

    // No fallback available or API also failed
    throw error;
  }

  /**
   * Get default team ID from config
   * @private
   */
  async getDefaultTeamId() {
    const config = require('./config');
    try {
      return await config.getTeamId();
    } catch (error) {
      throw new Error('Team ID not configured. Set LINEAR_TEAM_ID or use --teamId parameter.');
    }
  }

  /**
   * Get current access method
   * @returns {string|null}
   */
  getAccessMethod() {
    return this.accessMethod;
  }

  /**
   * Check if response is an MCP instruction
   * @param {Object} response
   * @returns {boolean}
   */
  isMcpInstruction(response) {
    return response && response.useMcp === true;
  }

  /**
   * Format MCP instruction for display
   * @param {Object} instruction
   * @returns {string}
   */
  formatMcpInstruction(instruction) {
    if (!this.isMcpInstruction(instruction)) {
      return JSON.stringify(instruction, null, 2);
    }

    return `
╔═══════════════════════════════════════════════════════════╗
║  Linear MCP Integration Required                          ║
╚═══════════════════════════════════════════════════════════╝

${instruction.humanReadable}

${instruction.instructions}

For more information, see: tools/anspar-cc-plugins/plugins/linear-api/README.md
`.trim();
  }

  /**
   * Force re-detection of access method
   * @returns {Promise<void>}
   */
  async refresh() {
    this.initialized = false;
    accessDetector.clearCache();
    await this.initialize();
  }

  /**
   * Get diagnostic information
   * @returns {Object}
   */
  async getDiagnostics() {
    await this.initialize();

    return {
      accessMethod: this.accessMethod,
      initialized: this.initialized,
      detector: accessDetector.getDiagnostics(),
      mcpClient: this.accessMethod === 'mcp' ? mcpClient.getDiagnostics() : null
    };
  }
}

// Export singleton
module.exports = new LinearAdapter();
