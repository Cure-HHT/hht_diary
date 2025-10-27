/**
 * Linear Requirement Inserter - VS Code Extension
 *
 * Integrates Linear project management with VS Code to insert requirement
 * references from in-progress tickets into code comments.
 */

import * as vscode from 'vscode';
import { LinearApiClient } from './linear/client';
import { extractRequirementsFromIssue } from './requirements/parser';
import { requirementCache } from './requirements/cache';
import { insertRequirementsAtCursor } from './comments/inserter';
import { showRequirementPicker, promptForApiToken } from './ui/quickpick';
import { getConfig, updateApiToken, isConfigured, getSpecPath } from './config';
import { IssueWithRequirements } from './linear/types';

let linearClient: LinearApiClient | null = null;

/**
 * Extension activation
 */
export function activate(context: vscode.ExtensionContext) {
    console.log('Linear Requirement Inserter is now active');

    // Initialize Linear client
    initializeLinearClient();

    // Load requirements cache
    refreshRequirementCache();

    // Register command: Insert Requirements
    const insertCommand = vscode.commands.registerCommand(
        'linearReqInserter.insertRequirements',
        async () => await handleInsertRequirements()
    );

    // Register configuration change handler
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration(e => {
            if (e.affectsConfiguration('linearReqInserter.apiToken')) {
                initializeLinearClient();
            }
            if (e.affectsConfiguration('linearReqInserter.specPath')) {
                refreshRequirementCache();
            }
        })
    );

    // Add to subscriptions
    context.subscriptions.push(insertCommand);

    // Show welcome message on first activation
    const hasShownWelcome = context.globalState.get<boolean>('hasShownWelcome', false);
    if (!hasShownWelcome) {
        showWelcomeMessage(context);
    }
}

/**
 * Extension deactivation
 */
export function deactivate() {
    linearClient = null;
    requirementCache.clear();
}

/**
 * Initialize Linear API client
 */
function initializeLinearClient(): void {
    const config = getConfig();

    if (!config.apiToken) {
        linearClient = null;
        return;
    }

    linearClient = new LinearApiClient({
        apiToken: config.apiToken,
        teamId: config.teamId
    });
}

/**
 * Refresh requirement cache from spec files
 */
function refreshRequirementCache(): void {
    const specPath = getSpecPath();
    try {
        requirementCache.refresh(specPath);
        console.log(`Loaded ${requirementCache.size()} requirements from ${specPath}`);
    } catch (error) {
        console.error('Failed to load requirements:', error);
    }
}

/**
 * Handle insert requirements command
 */
async function handleInsertRequirements(): Promise<void> {
    // Check if Linear is configured
    if (!isConfigured()) {
        const configure = await vscode.window.showInformationMessage(
            'Linear API token not configured. Would you like to configure it now?',
            'Configure', 'Cancel'
        );

        if (configure === 'Configure') {
            const token = await promptForApiToken();
            if (token) {
                await updateApiToken(token);
                initializeLinearClient();
            } else {
                return;
            }
        } else {
            return;
        }
    }

    // Get active editor
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showErrorMessage('No active editor');
        return;
    }

    // Refresh cache if needed
    if (requirementCache.needsRefresh()) {
        refreshRequirementCache();
    }

    // Fetch in-progress issues with requirements
    const issuesWithReqs = await fetchIssuesWithRequirements();
    if (!issuesWithReqs || issuesWithReqs.length === 0) {
        return;
    }

    // Show requirement picker
    const selectedReqs = await showRequirementPicker(issuesWithReqs);
    if (!selectedReqs || selectedReqs.length === 0) {
        return;
    }

    // Insert at cursor
    await insertRequirementsAtCursor(editor, selectedReqs);
}

/**
 * Fetch in-progress issues and extract requirements
 */
async function fetchIssuesWithRequirements(): Promise<IssueWithRequirements[] | null> {
    if (!linearClient || !linearClient.isConfigured()) {
        vscode.window.showErrorMessage('Linear client not configured');
        return null;
    }

    try {
        vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'Fetching Linear tickets...',
            cancellable: false
        }, async () => {
            // Fetching happens here
        });

        const issues = await linearClient.getInProgressIssues();

        if (issues.length === 0) {
            vscode.window.showInformationMessage(
                'No in-progress tickets found'
            );
            return null;
        }

        // Extract requirements from each issue
        const issuesWithReqs: IssueWithRequirements[] = [];

        console.log(`[Linear Req Inserter] Found ${issues.length} in-progress issues`);

        for (const issue of issues) {
            console.log(`[Linear Req Inserter] Processing issue ${issue.identifier}: ${issue.title}`);
            console.log(`[Linear Req Inserter]   Description: ${issue.description?.substring(0, 200) || '(empty)'}`);
            console.log(`[Linear Req Inserter]   Comments count: ${issue.comments.nodes.length}`);

            const reqIds = extractRequirementsFromIssue(
                issue.description,
                issue.comments.nodes
            );

            console.log(`[Linear Req Inserter]   Extracted requirement IDs: ${reqIds.join(', ') || '(none)'}`);

            if (reqIds.length > 0) {
                const requirements = requirementCache.getMultiple(reqIds);
                console.log(`[Linear Req Inserter]   Found ${requirements.length} requirements in cache`);
                if (requirements.length > 0) {
                    issuesWithReqs.push({ issue, requirements });
                }
            }
        }

        console.log(`[Linear Req Inserter] Total issues with requirements: ${issuesWithReqs.length}`);
        return issuesWithReqs;
    } catch (error) {
        vscode.window.showErrorMessage(`Failed to fetch Linear tickets: ${error}`);
        return null;
    }
}

/**
 * Show welcome message
 */
async function showWelcomeMessage(context: vscode.ExtensionContext): Promise<void> {
    const response = await vscode.window.showInformationMessage(
        'Welcome to Linear Requirement Inserter! Configure your Linear API token to get started.',
        'Configure Now', 'Later'
    );

    if (response === 'Configure Now') {
        const token = await promptForApiToken();
        if (token) {
            await updateApiToken(token);
            initializeLinearClient();
        }
    }

    context.globalState.update('hasShownWelcome', true);
}
