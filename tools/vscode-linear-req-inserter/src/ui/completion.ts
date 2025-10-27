/**
 * Completion provider for text pattern triggers (//req, --req, #req, etc.)
 */

import * as vscode from 'vscode';
import { Requirement, IssueWithRequirements } from '../linear/types';

/**
 * Create completion items from requirements
 */
export function createCompletionItems(
    issuesWithReqs: IssueWithRequirements[],
    range: vscode.Range
): vscode.CompletionItem[] {
    const items: vscode.CompletionItem[] = [];

    for (const { issue, requirements } of issuesWithReqs) {
        for (const req of requirements) {
            const item = new vscode.CompletionItem(
                `${req.fullId}: ${req.title}`,
                vscode.CompletionItemKind.Reference
            );

            item.detail = `From ticket: ${issue.identifier} - ${issue.title}`;
            item.documentation = new vscode.MarkdownString(
                `**Level:** ${req.level}  \n` +
                `**Status:** ${req.status}  \n` +
                `**Ticket:** [${issue.identifier}](${issue.url})  \n\n` +
                `_${issue.title}_`
            );

            item.insertText = `${req.fullId}: ${req.title}`;
            item.range = range;
            item.sortText = `0-${req.id}`; // Sort by requirement ID

            items.push(item);
        }
    }

    return items;
}

/**
 * Check if current line contains a trigger pattern
 */
export function matchesTriggerPattern(line: string, position: vscode.Position): boolean {
    const textBeforeCursor = line.substring(0, position.character);

    // Match patterns like: //LINEAR, --LINEAR, #LINEAR, <!--LINEAR
    const patterns = [
        /\/\/\s*LINEAR$/i,       // //LINEAR
        /--\s*LINEAR$/i,         // --LINEAR
        /#\s*LINEAR$/i,          // #LINEAR
        /<!--\s*LINEAR$/i        // <!--LINEAR
    ];

    return patterns.some(pattern => pattern.test(textBeforeCursor));
}

/**
 * Get replacement range for the trigger pattern
 */
export function getTriggerReplacementRange(
    document: vscode.TextDocument,
    position: vscode.Position
): vscode.Range | undefined {
    const line = document.lineAt(position.line).text;
    const textBeforeCursor = line.substring(0, position.character);

    // Find where the pattern starts
    const match = textBeforeCursor.match(/(\/\/|--|#|<!--)\s*LINEAR$/i);
    if (!match || match.index === undefined) {
        return undefined;
    }

    const startChar = match!.index!;
    return new vscode.Range(
        new vscode.Position(position.line, startChar),
        position
    );
}
