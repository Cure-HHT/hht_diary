#!/usr/bin/env node
/**
 * Ticket Fetcher for Linear Integration
 *
 * Handles all ticket read operations:
 * - Fetch assigned tickets
 * - Search tickets by query
 * - Get tickets by label
 * - Get ticket details by ID
 */

const config = require('./config');
const graphql = require('./graphql-client');
const teamResolver = require('./team-resolver');

class TicketFetcher {
    constructor() {
        this.defaultPageSize = 50;
    }

    /**
     * Get all tickets assigned to the current user
     * @param {Object} options
     * @param {number} options.limit - Maximum number of tickets to return
     * @param {boolean} options.includeCompleted - Include completed/canceled tickets
     * @returns {Promise<Array>} Array of ticket objects
     */
    async getAssignedTickets(options = {}) {
        const {
            limit = 100,
            includeCompleted = false
        } = options;

        const query = `
            query GetAssignedIssues($filter: IssueFilter!, $first: Int!) {
                viewer {
                    assignedIssues(filter: $filter, first: $first) {
                        nodes {
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
                            createdAt
                            updatedAt
                            completedAt
                        }
                    }
                }
            }
        `;

        const filter = includeCompleted ? {} : {
            state: { type: { nin: ["completed", "canceled"] } }
        };

        const data = await graphql.execute(query, {
            filter,
            first: limit
        });

        return data.viewer?.assignedIssues?.nodes || [];
    }

    /**
     * Search tickets by query string
     * @param {string} searchQuery - Search query
     * @param {Object} options
     * @param {number} options.limit - Maximum results
     * @param {boolean} options.includeArchived - Include archived tickets
     * @returns {Promise<Array>} Matching tickets
     */
    async searchTickets(searchQuery, options = {}) {
        const {
            limit = 50,
            includeArchived = false
        } = options;

        const teamId = await teamResolver.getTeamId();

        const query = `
            query SearchIssues($teamId: String!, $term: String!, $includeArchived: Boolean!, $first: Int!) {
                team(id: $teamId) {
                    issues(
                        filter: { searchableContent: { contains: $term } }
                        includeArchived: $includeArchived
                        first: $first
                    ) {
                        nodes {
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
                            createdAt
                            updatedAt
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(query, {
            teamId,
            term: searchQuery,
            includeArchived,
            first: limit
        });

        return data.team?.issues?.nodes || [];
    }

    /**
     * Get tickets by label
     * @param {string|Array<string>} labelNames - Label name(s) to filter by
     * @param {Object} options
     * @param {number} options.limit - Maximum results
     * @param {boolean} options.includeCompleted - Include completed tickets
     * @returns {Promise<Array>} Tickets with specified labels
     */
    async getTicketsByLabel(labelNames, options = {}) {
        const {
            limit = 100,
            includeCompleted = false
        } = options;

        const teamId = await teamResolver.getTeamId();

        // Ensure labelNames is an array
        const labels = Array.isArray(labelNames) ? labelNames : [labelNames];

        const query = `
            query GetIssuesByLabel($teamId: String!, $labels: [String!]!, $filter: IssueFilter!, $first: Int!) {
                team(id: $teamId) {
                    issues(
                        filter: {
                            labels: { name: { in: $labels } }
                            and: [$filter]
                        }
                        first: $first
                    ) {
                        nodes {
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
                            createdAt
                            updatedAt
                            completedAt
                        }
                    }
                }
            }
        `;

        const filter = includeCompleted ? {} : {
            state: { type: { nin: ["completed", "canceled"] } }
        };

        const data = await graphql.execute(query, {
            teamId,
            labels,
            filter,
            first: limit
        });

        return data.team?.issues?.nodes || [];
    }

    /**
     * Get a single ticket by ID or identifier
     * @param {string} ticketId - Ticket UUID or identifier (e.g., "CUR-123")
     * @returns {Promise<Object|null>} Ticket object or null if not found
     */
    async getTicketById(ticketId) {
        // Linear accepts both UUID and shorthand identifiers (e.g., "CUR-312")
        // in the same query field
        const query = `
            query GetIssueById($id: String!) {
                issue(id: $id) {
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
                            description
                        }
                    }
                    assignee {
                        id
                        name
                        email
                    }
                    creator {
                        name
                        email
                    }
                    project {
                        id
                        name
                    }
                    team {
                        id
                        key
                        name
                    }
                    parent {
                        id
                        identifier
                        title
                    }
                    children {
                        nodes {
                            id
                            identifier
                            title
                            state {
                                type
                            }
                        }
                    }
                    comments {
                        nodes {
                            id
                            body
                            createdAt
                            user {
                                name
                            }
                        }
                    }
                    createdAt
                    updatedAt
                    completedAt
                    canceledAt
                    startedAt
                    dueDate
                }
            }
        `;

        try {
            const data = await graphql.execute(query, { id: ticketId });
            return data.issue || null;
        } catch (error) {
            // If not found, return null instead of throwing
            if (error.message.includes('not found') || error.message.includes('Invalid identifier')) {
                return null;
            }
            throw error;
        }
    }

    /**
     * Get all tickets for a project
     * @param {string} projectId - Project ID
     * @param {Object} options
     * @returns {Promise<Array>} Array of tickets in the project
     */
    async getProjectTickets(projectId, options = {}) {
        const { limit = 100 } = options;

        const query = `
            query GetProjectIssues($projectId: String!, $first: Int!) {
                project(id: $projectId) {
                    name
                    issues(first: $first) {
                        nodes {
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
                            assignee {
                                name
                            }
                            createdAt
                            updatedAt
                        }
                    }
                }
            }
        `;

        const data = await graphql.execute(query, {
            projectId,
            first: limit
        });

        return data.project?.issues?.nodes || [];
    }

    /**
     * Extract requirement references from ticket description
     * @param {string} description - Ticket description
     * @returns {Array<string>} Array of requirement IDs found
     */
    extractRequirements(description) {
        if (!description) return [];

        const reqPattern = /REQ-[pod]\d{5}/gi;
        const matches = description.match(reqPattern) || [];

        // Remove duplicates and return
        return [...new Set(matches.map(r => r.toUpperCase()))];
    }

    /**
     * Display tickets in a formatted table
     * @param {Array} tickets - Array of ticket objects
     * @param {Object} options
     * @param {boolean} options.showDescription - Show description preview
     * @param {boolean} options.showLabels - Show labels
     * @param {boolean} options.showAssignee - Show assignee
     * @param {boolean} options.json - Output as JSON
     */
    displayTickets(tickets, options = {}) {
        const {
            showDescription = false,
            showLabels = true,
            showAssignee = true,
            json = false
        } = options;

        if (json) {
            console.log(JSON.stringify(tickets, null, 2));
            return;
        }

        if (!tickets || tickets.length === 0) {
            console.log('No tickets found');
            return;
        }

        console.log(`\n📋 Found ${tickets.length} ticket${tickets.length !== 1 ? 's' : ''}:\n`);

        for (const ticket of tickets) {
            console.log(`${ticket.identifier}: ${ticket.title}`);
            console.log(`   URL: ${ticket.url}`);
            console.log(`   Status: ${ticket.state?.name || 'Unknown'}`);

            if (ticket.priorityLabel) {
                console.log(`   Priority: ${ticket.priorityLabel}`);
            }

            if (showAssignee && ticket.assignee) {
                console.log(`   Assignee: ${ticket.assignee.name}`);
            }

            if (showLabels && ticket.labels?.nodes?.length > 0) {
                const labelNames = ticket.labels.nodes.map(l => l.name).join(', ');
                console.log(`   Labels: ${labelNames}`);
            }

            if (showDescription && ticket.description) {
                const preview = ticket.description.substring(0, 100).replace(/\n/g, ' ');
                const suffix = ticket.description.length > 100 ? '...' : '';
                console.log(`   Description: ${preview}${suffix}`);
            }

            // Check for requirements
            const requirements = this.extractRequirements(ticket.description);
            if (requirements.length > 0) {
                console.log(`   Requirements: ${requirements.join(', ')}`);
            }

            console.log('');
        }
    }

    /**
     * Get tickets with flexible filtering (not limited to assigned tickets)
     * Supports pagination to retrieve all matching tickets
     * @param {Object} options
     * @param {number} options.limit - Maximum number of tickets to return per page (default: 100, max: 100)
     * @param {number} options.maxTotal - Maximum total tickets to retrieve across all pages (default: unlimited)
     * @param {string} options.project - Project name or ID to filter by
     * @param {Array<string>} options.status - Status types to include (e.g., ['backlog', 'unstarted', 'started'])
     * @param {boolean} options.includeCompleted - Include completed/canceled tickets (default: false)
     * @param {boolean} options.noPagination - Only fetch first page (default: false)
     * @returns {Promise<Array>} Array of ticket objects
     */
    async getTickets(options = {}) {
        const {
            limit = 100,
            maxTotal = Infinity,
            project = null,
            status = null,
            includeCompleted = false,
            noPagination = false
        } = options;

        const teamId = await teamResolver.getTeamId();

        // Build filter object
        const filter = {};

        // Status filter
        if (status && status.length > 0) {
            // Map friendly names to Linear state types
            const stateTypeMap = {
                'backlog': 'backlog',
                'todo': 'unstarted',
                'unstarted': 'unstarted',
                'in-progress': 'started',
                'in progress': 'started',
                'started': 'started',
                'done': 'completed',
                'completed': 'completed',
                'canceled': 'canceled',
                'cancelled': 'canceled'
            };

            const stateTypes = status.map(s => stateTypeMap[s.toLowerCase()] || s);
            filter.state = { type: { in: stateTypes } };
        } else if (!includeCompleted) {
            // Default: exclude completed/canceled
            filter.state = { type: { nin: ['completed', 'canceled'] } };
        }

        // Project filter
        if (project) {
            // Try to use project as ID first, or name
            // Linear accepts both in the filter
            filter.project = { name: { eq: project } };
        }

        const query = `
            query GetTickets($teamId: String!, $filter: IssueFilter!, $first: Int!, $after: String) {
                team(id: $teamId) {
                    issues(filter: $filter, first: $first, after: $after, orderBy: updatedAt) {
                        pageInfo {
                            hasNextPage
                            endCursor
                        }
                        nodes {
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
                                id
                                name
                            }
                            createdAt
                            updatedAt
                            completedAt
                        }
                    }
                }
            }
        `;

        // Pagination loop
        let allTickets = [];
        let hasNextPage = true;
        let cursor = null;
        let pageCount = 0;

        while (hasNextPage && allTickets.length < maxTotal) {
            const data = await graphql.execute(query, {
                teamId,
                filter,
                first: Math.min(limit, maxTotal - allTickets.length),
                after: cursor
            });

            const issues = data.team?.issues;
            if (!issues) break;

            allTickets.push(...issues.nodes);
            pageCount++;

            hasNextPage = issues.pageInfo.hasNextPage && !noPagination;
            cursor = issues.pageInfo.endCursor;

            // Rate limiting between pages
            if (hasNextPage) {
                await new Promise(resolve => setTimeout(resolve, 500));
            }
        }

        return allTickets;
    }

    /**
     * Get ticket statistics for the current team
     * @returns {Promise<Object>} Statistics object
     */
    async getTeamStatistics() {
        const teamId = await teamResolver.getTeamId();

        const query = `
            query GetTeamStats($teamId: String!) {
                team(id: $teamId) {
                    name
                    issues {
                        totalCount
                    }
                    inProgressIssues: issues(filter: { state: { type: { eq: "started" } } }) {
                        totalCount
                    }
                    backlogIssues: issues(filter: { state: { type: { eq: "backlog" } } }) {
                        totalCount
                    }
                    todoIssues: issues(filter: { state: { type: { eq: "unstarted" } } }) {
                        totalCount
                    }
                    completedIssues: issues(filter: { state: { type: { eq: "completed" } } }) {
                        totalCount
                    }
                }
            }
        `;

        const data = await graphql.execute(query, { teamId });
        const team = data.team;

        return {
            teamName: team.name,
            total: team.issues.totalCount,
            inProgress: team.inProgressIssues.totalCount,
            backlog: team.backlogIssues.totalCount,
            todo: team.todoIssues.totalCount,
            completed: team.completedIssues.totalCount
        };
    }
}

// Export singleton instance
module.exports = new TicketFetcher();