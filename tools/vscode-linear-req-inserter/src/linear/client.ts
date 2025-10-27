/**
 * Linear API client for fetching in-progress issues
 *
 * Uses direct GraphQL API calls instead of @linear/sdk to reduce bundle size
 */

import { LinearIssue, LinearUser, LinearConfig } from './types';
import { GET_IN_PROGRESS_ISSUES, GET_USER_INFO } from './queries';

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

export class LinearApiClient {
    private config: LinearConfig;

    constructor(config: LinearConfig) {
        this.config = config;
    }

    /**
     * Update API token
     */
    updateToken(apiToken: string): void {
        this.config.apiToken = apiToken;
    }

    /**
     * Check if client is configured
     */
    isConfigured(): boolean {
        return !!this.config.apiToken;
    }

    /**
     * Execute GraphQL query
     */
    private async executeQuery<T>(query: string, variables?: Record<string, any>): Promise<T> {
        const response = await fetch(LINEAR_API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': this.config.apiToken || '',
            },
            body: JSON.stringify({ query, variables }),
        });

        if (!response.ok) {
            throw new Error(`Linear API error: ${response.statusText}`);
        }

        const result: any = await response.json();

        if (result.errors) {
            throw new Error(`GraphQL errors: ${JSON.stringify(result.errors)}`);
        }

        return result.data as T;
    }

    /**
     * Get current user information
     */
    async getCurrentUser(): Promise<LinearUser | null> {
        if (!this.config.apiToken) {
            throw new Error('Linear API token not configured');
        }

        try {
            const data = await this.executeQuery<{ viewer: LinearUser }>(GET_USER_INFO);
            return data.viewer;
        } catch (error) {
            console.error('Failed to fetch user info:', error);
            return null;
        }
    }

    /**
     * Fetch in-progress issues assigned to the current user
     */
    async getInProgressIssues(): Promise<LinearIssue[]> {
        if (!this.config.apiToken) {
            throw new Error('Linear API token not configured');
        }

        try {
            const data = await this.executeQuery<{ viewer: { assignedIssues: { nodes: any[] } } }>(
                GET_IN_PROGRESS_ISSUES
            );

            return data.viewer.assignedIssues.nodes.map(issue => ({
                id: issue.id,
                identifier: issue.identifier,
                title: issue.title,
                description: issue.description || '',
                url: issue.url,
                state: {
                    name: issue.state?.name || 'Unknown'
                },
                comments: {
                    nodes: (issue.comments?.nodes || []).map((comment: any) => ({
                        id: comment.id,
                        body: comment.body || '',
                        createdAt: comment.createdAt
                    }))
                }
            }));
        } catch (error) {
            console.error('Failed to fetch in-progress issues:', error);
            throw error;
        }
    }
}
