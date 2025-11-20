#!/usr/bin/env node
/**
 * MCP Client for Linear Integration
 *
 * Provides Linear operations via Model Context Protocol
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00053 (Development Environment and Tooling Setup)
 *
 * Supporting: CUR-390 - Linear MCP integration
 *
 * NOTE: This client leverages Claude Code's MCP connection by providing
 * structured prompts that Claude can execute using its Linear MCP tools.
 * It does not directly invoke MCP - that's handled by Claude Code itself.
 */

class McpClient {
  constructor() {
    this.debug = process.env.DEBUG_LINEAR_MCP === 'true';
  }

  /**
   * Create an issue via MCP
   * @param {Object} params - Issue creation parameters
   * @param {string} params.title - Issue title
   * @param {string} params.description - Issue description
   * @param {number} params.priority - Priority level (0-4)
   * @param {Array<string>} params.labelIds - Label IDs
   * @param {string} params.teamId - Team ID
   * @returns {Promise<Object>} MCP instruction object
   */
  async createIssue(params) {
    const {
      title,
      description,
      priority,
      labelIds,
      teamId
    } = params;

    // Map priority number to label
    const priorityLabel = this.getPriorityLabel(priority);

    // Build instruction for Claude
    const instruction = this.buildInstruction({
      operation: 'create issue',
      details: {
        title,
        description,
        priority: priorityLabel,
        teamId
      },
      mcpTool: 'create_issue',
      mcpParams: {
        title,
        description,
        priority,
        labelIds,
        teamId
      }
    });

    if (this.debug) {
      console.log('📋 MCP Create Issue Instruction:', instruction);
    }

    return instruction;
  }

  /**
   * Get an issue by ID via MCP
   * @param {string} id - Issue identifier (e.g., "CUR-123")
   * @returns {Promise<Object>} MCP instruction object
   */
  async getIssue(id) {
    const instruction = this.buildInstruction({
      operation: `fetch issue ${id}`,
      details: { issueId: id },
      mcpTool: 'get_issue',
      mcpParams: { id }
    });

    if (this.debug) {
      console.log('📋 MCP Get Issue Instruction:', instruction);
    }

    return instruction;
  }

  /**
   * Update an issue via MCP
   * @param {string} id - Issue identifier
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} MCP instruction object
   */
  async updateIssue(id, updates) {
    const instruction = this.buildInstruction({
      operation: `update issue ${id}`,
      details: { issueId: id, updates },
      mcpTool: 'update_issue',
      mcpParams: { id, ...updates }
    });

    if (this.debug) {
      console.log('📋 MCP Update Issue Instruction:', instruction);
    }

    return instruction;
  }

  /**
   * Search issues via MCP
   * @param {string|Object} query - Search query
   * @returns {Promise<Object>} MCP instruction object
   */
  async searchIssues(query) {
    const instruction = this.buildInstruction({
      operation: 'search issues',
      details: { query },
      mcpTool: 'search_issues',
      mcpParams: { query }
    });

    if (this.debug) {
      console.log('📋 MCP Search Issues Instruction:', instruction);
    }

    return instruction;
  }

  /**
   * Build an MCP instruction object
   * @private
   */
  buildInstruction({ operation, details, mcpTool, mcpParams }) {
    return {
      useMcp: true,
      operation,
      mcpTool,
      mcpParams,
      humanReadable: this.formatHumanReadable(operation, details),
      instructions: [
        `This operation requires Linear MCP access.`,
        ``,
        `To complete this request, please use the Linear MCP tool: ${mcpTool}`,
        ``,
        `Parameters:`,
        JSON.stringify(mcpParams, null, 2),
        ``,
        `Alternative: If you have LINEAR_API_TOKEN set, run this command again`,
        `with the token in your environment.`
      ].join('\n')
    };
  }

  /**
   * Format human-readable operation description
   * @private
   */
  formatHumanReadable(operation, details) {
    const parts = [`Operation: ${operation}`];

    if (details) {
      parts.push(`Details:`);
      for (const [key, value] of Object.entries(details)) {
        if (typeof value === 'object') {
          parts.push(`  ${key}: ${JSON.stringify(value)}`);
        } else {
          parts.push(`  ${key}: ${value}`);
        }
      }
    }

    return parts.join('\n');
  }

  /**
   * Map priority number to label
   * @private
   */
  getPriorityLabel(priority) {
    const labels = {
      0: 'No Priority',
      1: 'Urgent',
      2: 'High',
      3: 'Normal',
      4: 'Low'
    };
    return labels[priority] || 'Normal';
  }

  /**
   * Check if we're in a context where MCP can be used directly
   * (This would require integration with Claude Code's tool system)
   * @returns {boolean}
   */
  canInvokeDirect() {
    // For now, we don't support direct MCP invocation
    // Future enhancement: Detect if running within Claude Code
    // and can access its tool invocation system
    return false;
  }

  /**
   * Get diagnostic information
   * @returns {Object}
   */
  getDiagnostics() {
    return {
      clientType: 'mcp-instruction',
      canInvokeDirect: this.canInvokeDirect(),
      requiresManualExecution: true,
      note: 'This client provides instructions for Claude Code to execute via MCP'
    };
  }
}

// Export singleton
module.exports = new McpClient();
