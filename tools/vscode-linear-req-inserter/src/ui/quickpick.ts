/**
 * QuickPick UI for selecting requirements from Linear tickets
 */

import * as vscode from 'vscode';
import { LinearIssue, Requirement, IssueWithRequirements } from '../linear/types';

interface RequirementQuickPickItem extends vscode.QuickPickItem {
    requirement: Requirement;
    issue: LinearIssue;
}

interface IssueQuickPickItem extends vscode.QuickPickItem {
    issue: LinearIssue;
    requirements: Requirement[];
}

/**
 * Show requirement picker for user to select
 */
export async function showRequirementPicker(
    issuesWithReqs: IssueWithRequirements[]
): Promise<Requirement[] | undefined> {
    if (issuesWithReqs.length === 0) {
        vscode.window.showInformationMessage(
            'No in-progress tickets found with requirement references'
        );
        return undefined;
    }

    // Build flat list of all requirements with their source tickets
    const items: RequirementQuickPickItem[] = [];

    for (const { issue, requirements } of issuesWithReqs) {
        for (const req of requirements) {
            items.push({
                label: `$(symbol-field) ${req.fullId}`,
                description: req.title,
                detail: `From: ${issue.identifier} - ${issue.title}`,
                requirement: req,
                issue: issue
            });
        }
    }

    if (items.length === 0) {
        vscode.window.showInformationMessage(
            'No requirements found in your in-progress tickets'
        );
        return undefined;
    }

    // Show multi-select picker
    const selected = await vscode.window.showQuickPick(items, {
        placeHolder: 'Select requirements to insert (use Tab to select multiple)',
        canPickMany: true,
        matchOnDescription: true,
        matchOnDetail: true
    });

    if (!selected || selected.length === 0) {
        return undefined;
    }

    // Remove duplicates based on requirement ID
    const uniqueReqs = new Map<string, Requirement>();
    for (const item of selected) {
        uniqueReqs.set(item.requirement.id, item.requirement);
    }

    return Array.from(uniqueReqs.values());
}

/**
 * Show ticket picker first, then requirement picker
 */
export async function showTicketThenRequirementPicker(
    issuesWithReqs: IssueWithRequirements[]
): Promise<Requirement[] | undefined> {
    if (issuesWithReqs.length === 0) {
        vscode.window.showInformationMessage(
            'No in-progress tickets found with requirement references'
        );
        return undefined;
    }

    // First, show ticket picker
    const issueItems: IssueQuickPickItem[] = issuesWithReqs.map(({ issue, requirements }) => ({
        label: `$(issues) ${issue.identifier}`,
        description: issue.title,
        detail: `${requirements.length} requirement(s) - ${issue.state.name}`,
        issue,
        requirements
    }));

    const selectedIssue = await vscode.window.showQuickPick(issueItems, {
        placeHolder: 'Select a ticket',
        matchOnDescription: true
    });

    if (!selectedIssue) {
        return undefined;
    }

    // Then show requirements from that ticket
    const reqItems: RequirementQuickPickItem[] = selectedIssue.requirements.map(req => ({
        label: `$(symbol-field) ${req.fullId}`,
        description: req.title,
        detail: `Level: ${req.level} | Status: ${req.status}`,
        requirement: req,
        issue: selectedIssue.issue
    }));

    const selected = await vscode.window.showQuickPick(reqItems, {
        placeHolder: 'Select requirements to insert (use Tab for multiple)',
        canPickMany: true,
        matchOnDescription: true
    });

    if (!selected || selected.length === 0) {
        return undefined;
    }

    return selected.map(item => item.requirement);
}

/**
 * Show configuration prompt for API token
 */
export async function promptForApiToken(): Promise<string | undefined> {
    const token = await vscode.window.showInputBox({
        prompt: 'Enter your Linear API token',
        placeHolder: 'lin_api_...',
        password: true,
        validateInput: (value) => {
            if (!value) {
                return 'Token is required';
            }
            if (!value.startsWith('lin_api_')) {
                return 'Token should start with "lin_api_"';
            }
            return undefined;
        }
    });

    return token;
}
