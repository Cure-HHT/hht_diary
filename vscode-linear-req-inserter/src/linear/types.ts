/**
 * TypeScript interfaces for Linear API data structures
 */

export interface LinearIssue {
    id: string;
    identifier: string; // e.g., "TEAM-123"
    title: string;
    description?: string;
    url: string;
    state: {
        name: string;
    };
    comments: {
        nodes: LinearComment[];
    };
}

export interface LinearComment {
    id: string;
    body: string;
    createdAt: string;
}

export interface LinearUser {
    id: string;
    name: string;
    email: string;
}

export interface Requirement {
    id: string; // e.g., "p00001"
    fullId: string; // e.g., "REQ-p00001"
    title: string;
    level: 'PRD' | 'OPS' | 'DEV';
    status: 'Active' | 'Draft' | 'Deprecated';
}

export interface IssueWithRequirements {
    issue: LinearIssue;
    requirements: Requirement[];
}

export interface LinearConfig {
    apiToken: string;
    teamId?: string;
    userId?: string;
}
