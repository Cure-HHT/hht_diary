/**
 * Extension configuration management
 */

import * as vscode from 'vscode';
import * as path from 'path';

export interface ExtensionConfig {
    apiToken: string;
    teamId: string;
    specPath: string;
    commentFormat: 'multiline' | 'singleline';
    includeTicketLink: boolean;
}

/**
 * Get extension configuration
 */
export function getConfig(): ExtensionConfig {
    const config = vscode.workspace.getConfiguration('linearReqInserter');

    return {
        apiToken: config.get<string>('apiToken', ''),
        teamId: config.get<string>('teamId', ''),
        specPath: resolveSpecPath(config.get<string>('specPath', '${workspaceFolder}/spec')),
        commentFormat: config.get<string>('commentFormat', 'multiline') as 'multiline' | 'singleline',
        includeTicketLink: config.get<boolean>('includeTicketLink', false)
    };
}

/**
 * Resolve spec path with variable substitution
 */
function resolveSpecPath(configuredPath: string): string {
    // Replace ${workspaceFolder} with actual workspace path
    if (vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0) {
        const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;
        return configuredPath.replace('${workspaceFolder}', workspaceRoot);
    }

    // If no workspace, try to resolve relative to home directory
    return configuredPath.replace('${workspaceFolder}', process.cwd());
}

/**
 * Update API token in configuration
 */
export async function updateApiToken(token: string): Promise<void> {
    const config = vscode.workspace.getConfiguration('linearReqInserter');
    await config.update('apiToken', token, vscode.ConfigurationTarget.Global);
}

/**
 * Check if extension is configured
 */
export function isConfigured(): boolean {
    const config = getConfig();
    return !!config.apiToken && config.apiToken.length > 0;
}

/**
 * Get spec path from configuration
 */
export function getSpecPath(): string {
    const config = getConfig();
    return config.specPath;
}

/**
 * Validate configuration
 */
export function validateConfig(config: ExtensionConfig): string[] {
    const errors: string[] = [];

    if (!config.apiToken) {
        errors.push('Linear API token is not configured');
    }

    // Note: specPath validation happens at runtime when loading requirements

    return errors;
}
