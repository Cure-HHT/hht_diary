#!/usr/bin/env node
/**
 * Ticket Updater for Linear Integration
 *
 * Handles ticket update operations:
 * - Update ticket description
 * - Add/modify checklists
 * - Change status
 * - Link requirements
 * - Update labels and priority
 */

const config = require('./config');
const graphql = require('./graphql-client');
const teamResolver = require('./team-resolver');
const ticketFetcher = require('./ticket-fetcher');
const labelManager = require('./label-manager');

class TicketUpdater {
    constructor() {
        this.stateMap = {
            'backlog': 'backlog',
            'todo': 'unstarted',
            'unstarted': 'unstarted',
            'in-progress': 'started',
            'started': 'started',
            'in progress': 'started',
            'done': 'completed',
            'completed': 'completed',
            'canceled': 'canceled',
            'cancelled': 'canceled'
        };
    }

    /**
     * Update a ticket's fields
     * @param {string} ticketId - Ticket ID or identifier
     * @param {Object} updates - Fields to update
     * @param {string} updates.title - New title
     * @param {string} updates.description - New description
     * @param {number} updates.priority - New priority (0-4)
     * @param {string} updates.stateId - New state ID
     * @param {Array<string>} updates.labelIds - New label IDs (replaces existing)
     * @param {Array<string>} updates.addLabelIds - Label IDs to add
     * @param {Array<string>} updates.removeLabelIds - Label IDs to remove
     * @param {string} updates.assigneeId - New assignee ID
     * @param {string} updates.projectId - New project ID
     * @param {Date} updates.dueDate - New due date
     * @param {Object} options
     * @param {boolean} options.silent - Suppress output
     * @returns {Promise<Object>} Updated ticket
     */
    async updateTicket(ticketId, updates, options = {}) {
        const { silent = false } = options;

        // First, get the current ticket to ensure it exists
        const currentTicket = await ticketFetcher.getTicketById(ticketId);
        if (!currentTicket) {
            throw new Error(`Ticket ${ticketId} not found`);
        }

        if (!silent) {
            console.log(`\n📝 Updating ticket: ${currentTicket.identifier} - ${currentTicket.title}`);
        }

        // Build mutation
        const mutation = `
            mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
                issueUpdate(id: $id, input: $input) {
                    success
                    issue {
                        id
                        identifier
                        title
                        description
                        url
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
                        assignee {
                            name
                        }
                        updatedAt
                    }
                }
            }
        `;

        // Build input object with only provided updates
        const input = {};

        if (updates.title !== undefined) {
            input.title = updates.title;
        }

        if (updates.description !== undefined) {
            input.description = updates.description;
        }

        if (updates.priority !== undefined) {
            input.priority = updates.priority;
        }

        if (updates.stateId !== undefined) {
            input.stateId = updates.stateId;
        }

        if (updates.labelIds !== undefined) {
            input.labelIds = updates.labelIds;
        }

        if (updates.addLabelIds !== undefined) {
            input.addLabelIds = updates.addLabelIds;
        }

        if (updates.removeLabelIds !== undefined) {
            input.removeLabelIds = updates.removeLabelIds;
        }

        if (updates.assigneeId !== undefined) {
            input.assigneeId = updates.assigneeId;
        }

        if (updates.projectId !== undefined) {
            input.projectId = updates.projectId;
        }

        if (updates.dueDate !== undefined) {
            input.dueDate = updates.dueDate ? this.formatDate(updates.dueDate) : null;
        }

        // Execute mutation
        const data = await graphql.execute(mutation, {
            id: currentTicket.id,
            input
        });

        if (!data.issueUpdate?.success) {
            throw new Error('Failed to update ticket');
        }

        const updatedTicket = data.issueUpdate.issue;

        if (!silent) {
            console.log(`✅ Ticket updated successfully`);
            console.log(`   URL: ${updatedTicket.url}`);

            if (updates.description !== undefined) {
                console.log(`   Description updated`);
            }

            if (updates.priority !== undefined) {
                console.log(`   Priority: ${updatedTicket.priorityLabel}`);
            }

            if (updatedTicket.labels?.nodes?.length > 0) {
                const labels = updatedTicket.labels.nodes.map(l => l.name).join(', ');
                console.log(`   Labels: ${labels}`);
            }
        }

        return updatedTicket;
    }

    /**
     * Add a checklist to ticket description
     * @param {string} ticketId - Ticket ID or identifier
     * @param {string|Array<string>} checklist - Checklist items or markdown
     * @param {Object} options
     * @param {string} options.title - Checklist title
     * @param {boolean} options.append - Append to existing description (default true)
     * @param {boolean} options.silent - Suppress output
     * @returns {Promise<Object>} Updated ticket
     */
    async addChecklist(ticketId, checklist, options = {}) {
        const {
            title = 'Checklist',
            append = true,
            silent = false
        } = options;

        // Get current ticket
        const currentTicket = await ticketFetcher.getTicketById(ticketId);
        if (!currentTicket) {
            throw new Error(`Ticket ${ticketId} not found`);
        }

        // Format checklist
        let checklistMarkdown = '';

        if (Array.isArray(checklist)) {
            checklistMarkdown = `\n\n### ${title}\n`;
            checklistMarkdown += checklist.map(item => {
                // Add checkbox if not present
                if (!item.startsWith('- [ ]') && !item.startsWith('- [x]')) {
                    return `- [ ] ${item}`;
                }
                return item;
            }).join('\n');
        } else {
            // Assume it's already formatted markdown
            checklistMarkdown = `\n\n${checklist}`;
        }

        // Build new description
        let newDescription = currentTicket.description || '';

        if (append) {
            // Check if description already has this checklist title
            if (newDescription.includes(`### ${title}`)) {
                if (!silent) {
                    console.log(`⚠️  Checklist "${title}" already exists in description`);
                }
            }
            newDescription += checklistMarkdown;
        } else {
            newDescription = checklistMarkdown + '\n\n' + newDescription;
        }

        // Update ticket
        return await this.updateTicket(ticketId, {
            description: newDescription
        }, { silent });
    }

    /**
     * Link a requirement to ticket description
     * @param {string} ticketId - Ticket ID or identifier
     * @param {string} requirementId - Requirement ID (e.g., "REQ-p00001")
     * @param {Object} options
     * @param {boolean} options.prepend - Prepend to description (default true)
     * @param {boolean} options.silent - Suppress output
     * @returns {Promise<Object>} Updated ticket
     */
    async linkRequirement(ticketId, requirementId, options = {}) {
        const {
            prepend = true,
            silent = false
        } = options;

        // Get current ticket
        const currentTicket = await ticketFetcher.getTicketById(ticketId);
        if (!currentTicket) {
            throw new Error(`Ticket ${ticketId} not found`);
        }

        // Check if requirement is already linked
        const currentDescription = currentTicket.description || '';
        if (currentDescription.includes(requirementId)) {
            if (!silent) {
                console.log(`ℹ️  Requirement ${requirementId} is already linked to this ticket`);
            }
            return currentTicket;
        }

        // Build requirement reference
        const requirementRef = `**Requirement**: ${requirementId}\n\n`;

        // Build new description
        let newDescription;
        if (prepend) {
            newDescription = requirementRef + currentDescription;
        } else {
            newDescription = currentDescription + '\n\n' + requirementRef;
        }

        // Update ticket
        return await this.updateTicket(ticketId, {
            description: newDescription
        }, { silent });
    }

    /**
     * Update ticket labels by name
     * @param {string} ticketId - Ticket ID or identifier
     * @param {Object} labelChanges
     * @param {Array<string>} labelChanges.add - Label names to add
     * @param {Array<string>} labelChanges.remove - Label names to remove
     * @param {Array<string>} labelChanges.set - Label names to set (replaces all)
     * @param {Object} options
     * @returns {Promise<Object>} Updated ticket
     */
    async updateLabels(ticketId, labelChanges, options = {}) {
        const { silent = false } = options;
        const updates = {};

        // Handle setting labels (replaces existing)
        if (labelChanges.set) {
            const result = await labelManager.getLabelIdsFromNames(labelChanges.set, {
                strict: false,
                silent
            });
            updates.labelIds = result.ids;
        }

        // Handle adding labels
        if (labelChanges.add) {
            const result = await labelManager.getLabelIdsFromNames(labelChanges.add, {
                strict: false,
                silent
            });
            updates.addLabelIds = result.ids;
        }

        // Handle removing labels
        if (labelChanges.remove) {
            const result = await labelManager.getLabelIdsFromNames(labelChanges.remove, {
                strict: false,
                silent
            });
            updates.removeLabelIds = result.ids;
        }

        return await this.updateTicket(ticketId, updates, { silent });
    }

    /**
     * Update ticket status
     * @param {string} ticketId - Ticket ID or identifier
     * @param {string} status - Status name (todo, in-progress, done, canceled)
     * @param {Object} options
     * @returns {Promise<Object>} Updated ticket
     */
    async updateStatus(ticketId, status, options = {}) {
        const { silent = false } = options;

        // Map status to state type
        const stateType = this.stateMap[status.toLowerCase()];
        if (!stateType) {
            throw new Error(`Unknown status: ${status}. Valid options: ${Object.keys(this.stateMap).join(', ')}`);
        }

        // Get available states for the team
        const teamId = await teamResolver.getTeamId();

        const query = `
            query GetWorkflowStates($teamId: String!) {
                team(id: $teamId) {
                    states {
                        nodes {
                            id
                            name
                            type
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(query, { teamId });
        const states = data.team?.states?.nodes || [];

        // Find matching state
        const targetState = states.find(s => s.type === stateType);
        if (!targetState) {
            throw new Error(`No state found for type: ${stateType}`);
        }

        if (!silent) {
            console.log(`📊 Changing status to: ${targetState.name}`);
        }

        return await this.updateTicket(ticketId, {
            stateId: targetState.id
        }, { silent });
    }

    /**
     * Add a comment to a ticket
     * @param {string} ticketId - Ticket ID or identifier
     * @param {string} comment - Comment text
     * @param {Object} options
     * @returns {Promise<Object>} Created comment
     */
    async addComment(ticketId, comment, options = {}) {
        const { silent = false } = options;

        // Get ticket ID if identifier was provided
        const ticket = await ticketFetcher.getTicketById(ticketId);
        if (!ticket) {
            throw new Error(`Ticket ${ticketId} not found`);
        }

        const mutation = `
            mutation AddComment($issueId: String!, $body: String!) {
                commentCreate(
                    input: {
                        issueId: $issueId
                        body: $body
                    }
                ) {
                    success
                    comment {
                        id
                        body
                        createdAt
                        user {
                            name
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(mutation, {
            issueId: ticket.id,
            body: comment
        });

        if (!data.commentCreate?.success) {
            throw new Error('Failed to add comment');
        }

        if (!silent) {
            console.log(`💬 Comment added to ${ticket.identifier}`);
        }

        return data.commentCreate.comment;
    }

    /**
     * Bulk update multiple tickets
     * @param {Array<Object>} updates - Array of {ticketId, updates} objects
     * @param {Object} options
     * @param {boolean} options.stopOnError - Stop if any update fails
     * @returns {Promise<Object>} Results summary
     */
    async bulkUpdate(updates, options = {}) {
        const { stopOnError = false } = options;

        const results = {
            updated: [],
            failed: [],
            total: updates.length
        };

        console.log(`\n📦 Updating ${updates.length} tickets...`);

        for (let i = 0; i < updates.length; i++) {
            const { ticketId, updates: ticketUpdates } = updates[i];

            console.log(`\n[${i + 1}/${updates.length}] Updating: ${ticketId}`);

            try {
                const updated = await this.updateTicket(ticketId, ticketUpdates, {
                    silent: true
                });

                results.updated.push(updated);
                console.log(`   ✅ Updated: ${updated.identifier}`);

            } catch (error) {
                results.failed.push({
                    ticketId,
                    error: error.message
                });

                console.log(`   ❌ Failed: ${error.message}`);

                if (stopOnError) {
                    break;
                }
            }

            // Add delay to avoid rate limiting
            if (i < updates.length - 1) {
                await this.sleep(500);
            }
        }

        console.log('\n📊 Bulk update summary:');
        console.log(`   Updated: ${results.updated.length}/${results.total}`);
        console.log(`   Failed: ${results.failed.length}/${results.total}`);

        return results;
    }

    /**
     * Format date for Linear API
     * @private
     */
    formatDate(date) {
        const d = date instanceof Date ? date : new Date(date);
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    /**
     * Sleep for specified milliseconds
     * @private
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Export singleton instance
module.exports = new TicketUpdater();