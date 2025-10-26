/**
 * Linear API client for fetching in-progress issues
 */

import { LinearClient } from '@linear/sdk';
import { LinearIssue, LinearUser, LinearConfig } from './types';

export class LinearApiClient {
    private client: LinearClient | null = null;
    private config: LinearConfig;

    constructor(config: LinearConfig) {
        this.config = config;
        if (config.apiToken) {
            this.client = new LinearClient({ apiKey: config.apiToken });
        }
    }

    /**
     * Update API token
     */
    updateToken(apiToken: string): void {
        this.config.apiToken = apiToken;
        this.client = new LinearClient({ apiKey: apiToken });
    }

    /**
     * Check if client is configured
     */
    isConfigured(): boolean {
        return this.client !== null && !!this.config.apiToken;
    }

    /**
     * Get current user information
     */
    async getCurrentUser(): Promise<LinearUser | null> {
        if (!this.client) {
            throw new Error('Linear API token not configured');
        }

        try {
            const viewer = await this.client.viewer;
            return {
                id: viewer.id,
                name: viewer.name,
                email: viewer.email,
            };
        } catch (error) {
            console.error('Failed to fetch user info:', error);
            return null;
        }
    }

    /**
     * Fetch in-progress issues assigned to the current user
     */
    async getInProgressIssues(): Promise<LinearIssue[]> {
        if (!this.client) {
            throw new Error('Linear API token not configured');
        }

        try {
            const viewer = await this.client.viewer;
            const issues = await viewer.assignedIssues({
                filter: {
                    state: {
                        name: {
                            in: ['In Progress', 'In Review']
                        }
                    }
                },
                orderBy: LinearClient.PaginationOrderBy.UpdatedAt
            });

            const issueNodes: LinearIssue[] = [];

            for await (const issue of issues) {
                const state = await issue.state;
                const comments = await issue.comments();

                issueNodes.push({
                    id: issue.id,
                    identifier: issue.identifier,
                    title: issue.title,
                    description: issue.description || '',
                    url: issue.url,
                    state: {
                        name: state?.name || 'Unknown'
                    },
                    comments: {
                        nodes: []
                    }
                });

                // Fetch comment bodies
                for await (const comment of comments) {
                    const lastNode = issueNodes[issueNodes.length - 1];
                    lastNode.comments.nodes.push({
                        id: comment.id,
                        body: comment.body,
                        createdAt: comment.createdAt.toISOString()
                    });
                }
            }

            return issueNodes;
        } catch (error) {
            console.error('Failed to fetch in-progress issues:', error);
            throw error;
        }
    }
}
