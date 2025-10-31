#!/usr/bin/env node
/**
 * Ticket Creator for Linear Integration
 *
 * Handles ticket creation operations:
 * - Create tickets with labels and priorities
 * - Validate required fields
 * - Handle label name to ID mapping
 * - Support file-based descriptions
 */

const config = require('./config');
const graphql = require('./graphql-client');
const teamResolver = require('./team-resolver');
const labelManager = require('./label-manager');

class TicketCreator {
    constructor() {
        this.priorityMap = {
            'urgent': 1,
            'high': 2,
            'normal': 3,
            'medium': 3,  // Alias for normal
            'low': 4,
            'none': 0,
            'no': 0,      // Alias for none
            // Numeric strings
            '1': 1,
            '2': 2,
            '3': 3,
            '4': 4,
            '0': 0,
            // P-notation
            'p1': 1,
            'p2': 2,
            'p3': 3,
            'p4': 4,
            'p0': 0
        };
    }

    /**
     * Create a new ticket
     * @param {Object} ticketData
     * @param {string} ticketData.title - Ticket title (required)
     * @param {string} ticketData.description - Ticket description
     * @param {string|number} ticketData.priority - Priority level or name
     * @param {Array<string>} ticketData.labels - Label names to apply
     * @param {string} ticketData.assigneeId - User ID to assign to
     * @param {string} ticketData.projectId - Project ID to add to
     * @param {string} ticketData.parentId - Parent ticket ID for subtasks
     * @param {Date} ticketData.dueDate - Due date
     * @param {Object} options
     * @param {boolean} options.silent - Suppress output
     * @param {boolean} options.returnFull - Return full ticket data
     * @returns {Promise<Object>} Created ticket
     */
    async createTicket(ticketData, options = {}) {
        const {
            title,
            description = '',
            priority = null,
            labels = [],
            assigneeId = null,
            projectId = null,
            parentId = null,
            dueDate = null
        } = ticketData;

        const { silent = false, returnFull = false } = options;

        // Validate required fields
        if (!title) {
            throw new Error('Ticket title is required');
        }

        // Get team ID
        const teamId = await teamResolver.getTeamId({ silent });

        if (!silent) {
            console.log('\n🎫 Creating Linear ticket...');
            console.log(`   Title: ${title}`);
        }

        // Parse priority
        const priorityValue = this.parsePriority(priority);
        if (!silent && priorityValue !== null) {
            console.log(`   Priority: ${this.getPriorityLabel(priorityValue)}`);
        }

        // Map label names to IDs
        let labelIds = [];
        if (labels && labels.length > 0) {
            if (!silent) {
                console.log(`   Labels requested: ${labels.join(', ')}`);
            }

            const labelResult = await labelManager.getLabelIdsFromNames(labels, {
                strict: false,
                silent
            });

            labelIds = labelResult.ids;

            if (!silent && labelResult.missing.length > 0) {
                console.log(`   ⚠️  Some labels not found: ${labelResult.missing.join(', ')}`);
            }
        }

        // Build mutation
        const mutation = `
            mutation CreateIssue(
                $teamId: String!
                $title: String!
                $description: String
                $priority: Int
                $labelIds: [String!]
                $assigneeId: String
                $projectId: String
                $parentId: String
                $dueDate: TimelessDate
            ) {
                issueCreate(
                    input: {
                        teamId: $teamId
                        title: $title
                        description: $description
                        priority: $priority
                        labelIds: $labelIds
                        assigneeId: $assigneeId
                        projectId: $projectId
                        parentId: $parentId
                        dueDate: $dueDate
                    }
                ) {
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
                            email
                        }
                        project {
                            name
                        }
                        parent {
                            identifier
                            title
                        }
                        createdAt
                    }
                }
            }
        `;

        // Build variables, only including non-null values
        const variables = {
            teamId,
            title,
            description
        };

        // Only add optional fields if they have values
        if (priorityValue !== null) {
            variables.priority = priorityValue;
        }
        if (labelIds.length > 0) {
            variables.labelIds = labelIds;
        }
        if (assigneeId) {
            variables.assigneeId = assigneeId;
        }
        if (projectId) {
            variables.projectId = projectId;
        }
        if (parentId) {
            variables.parentId = parentId;
        }
        if (dueDate) {
            variables.dueDate = this.formatDate(dueDate);
        }

        // Execute mutation
        const data = await graphql.execute(mutation, variables);

        if (!data.issueCreate?.success) {
            throw new Error('Failed to create ticket - no success response');
        }

        const issue = data.issueCreate.issue;

        if (!silent) {
            console.log(`\n✅ Ticket created successfully!`);
            console.log(`   ID: ${issue.identifier}`);
            console.log(`   URL: ${issue.url}`);

            if (issue.labels?.nodes?.length > 0) {
                const appliedLabels = issue.labels.nodes.map(l => l.name).join(', ');
                console.log(`   Applied labels: ${appliedLabels}`);
            }

            if (issue.assignee) {
                console.log(`   Assigned to: ${issue.assignee.name}`);
            }

            if (issue.project) {
                console.log(`   Project: ${issue.project.name}`);
            }

            if (issue.parent) {
                console.log(`   Parent: ${issue.parent.identifier} - ${issue.parent.title}`);
            }
        }

        return returnFull ? issue : {
            id: issue.id,
            identifier: issue.identifier,
            title: issue.title,
            url: issue.url
        };
    }

    /**
     * Create multiple tickets in batch
     * @param {Array<Object>} ticketsData - Array of ticket data objects
     * @param {Object} options
     * @param {boolean} options.stopOnError - Stop if any ticket fails
     * @param {boolean} options.silent - Suppress output
     * @returns {Promise<Object>} Results with created and failed tickets
     */
    async createMultipleTickets(ticketsData, options = {}) {
        const {
            stopOnError = false,
            silent = false
        } = options;

        const results = {
            created: [],
            failed: [],
            total: ticketsData.length
        };

        if (!silent) {
            console.log(`\n📦 Creating ${ticketsData.length} tickets...`);
        }

        for (let i = 0; i < ticketsData.length; i++) {
            const ticketData = ticketsData[i];

            if (!silent) {
                console.log(`\n[${i + 1}/${ticketsData.length}] Creating: ${ticketData.title}`);
            }

            try {
                const ticket = await this.createTicket(ticketData, {
                    silent: true,
                    returnFull: false
                });

                results.created.push(ticket);

                if (!silent) {
                    console.log(`   ✅ Created: ${ticket.identifier}`);
                }

                // Add delay to avoid rate limiting
                if (i < ticketsData.length - 1) {
                    await this.sleep(500);
                }

            } catch (error) {
                const failureInfo = {
                    title: ticketData.title,
                    error: error.message
                };

                results.failed.push(failureInfo);

                if (!silent) {
                    console.log(`   ❌ Failed: ${error.message}`);
                }

                if (stopOnError) {
                    break;
                }
            }
        }

        if (!silent) {
            console.log('\n📊 Batch creation summary:');
            console.log(`   Created: ${results.created.length}/${results.total}`);
            console.log(`   Failed: ${results.failed.length}/${results.total}`);
        }

        return results;
    }

    /**
     * Create a ticket from a requirement
     * @param {Object} requirement - Requirement object with id, title, content
     * @param {Object} options - Additional options for ticket creation
     * @returns {Promise<Object>} Created ticket
     */
    async createFromRequirement(requirement, options = {}) {
        const {
            labels = [],
            priority = null,
            projectId = null,
            includeContent = true
        } = options;

        // Build description
        let description = `**Requirement**: ${requirement.id}\n\n`;

        if (requirement.title) {
            description += `**Title**: ${requirement.title}\n\n`;
        }

        if (includeContent && requirement.content) {
            description += '## Requirement Details\n\n';
            description += requirement.content;
        }

        if (requirement.implements && requirement.implements.length > 0) {
            description += `\n\n**Implements**: ${requirement.implements.join(', ')}`;
        }

        // Determine priority based on requirement level
        let defaultPriority = priority;
        if (!defaultPriority && requirement.id) {
            if (requirement.id.includes('REQ-p')) {
                defaultPriority = 'high';  // PRD requirements
            } else if (requirement.id.includes('REQ-o')) {
                defaultPriority = 'normal';  // Ops requirements
            } else if (requirement.id.includes('REQ-d')) {
                defaultPriority = 'normal';  // Dev requirements
            }
        }

        // Add requirement-specific labels
        const allLabels = [...labels];

        // Add level-specific label if not present
        if (requirement.id) {
            if (requirement.id.includes('REQ-p') && !allLabels.includes('prd')) {
                allLabels.push('prd');
            } else if (requirement.id.includes('REQ-o') && !allLabels.includes('ops')) {
                allLabels.push('ops');
            } else if (requirement.id.includes('REQ-d') && !allLabels.includes('dev')) {
                allLabels.push('dev');
            }
        }

        // Create the ticket
        return await this.createTicket({
            title: `[${requirement.id}] ${requirement.title}`,
            description,
            priority: defaultPriority,
            labels: allLabels,
            projectId
        });
    }

    /**
     * Parse priority from various formats
     * @param {string|number} priority - Priority value
     * @returns {number|null} Linear priority value (0-4) or null
     */
    parsePriority(priority) {
        if (priority === null || priority === undefined) {
            return null;
        }

        // If it's already a number in the right range
        if (typeof priority === 'number' && priority >= 0 && priority <= 4) {
            return priority;
        }

        // Convert to string and lowercase for mapping
        const key = String(priority).toLowerCase().trim();

        return this.priorityMap[key] !== undefined ? this.priorityMap[key] : null;
    }

    /**
     * Get human-readable priority label
     * @param {number} priority - Priority value (0-4)
     * @returns {string} Priority label
     */
    getPriorityLabel(priority) {
        const labels = {
            0: 'No priority',
            1: 'P1 (Urgent)',
            2: 'P2 (High)',
            3: 'P3 (Normal)',
            4: 'P4 (Low)'
        };

        return labels[priority] || 'Unknown';
    }

    /**
     * Format date for Linear API
     * @param {Date|string} date - Date to format
     * @returns {string} Date in YYYY-MM-DD format
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
module.exports = new TicketCreator();