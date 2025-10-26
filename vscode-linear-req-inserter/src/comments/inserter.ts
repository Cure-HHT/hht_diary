/**
 * Comment insertion logic for VS Code editor
 */

import * as vscode from 'vscode';
import { Requirement } from '../linear/types';
import { formatRequirementsAsComments, CommentFormatOptions } from './templates';

/**
 * Insert requirements as comments at cursor position
 */
export async function insertRequirementsAtCursor(
    editor: vscode.TextEditor,
    requirements: Requirement[],
    options: Partial<CommentFormatOptions> = {}
): Promise<boolean> {
    if (requirements.length === 0) {
        vscode.window.showWarningMessage('No requirements to insert');
        return false;
    }

    const config = vscode.workspace.getConfiguration('linearReqInserter');
    const multiline = config.get<string>('commentFormat', 'multiline') === 'multiline';
    const includeTicketLink = config.get<boolean>('includeTicketLink', false);

    const formatOptions: CommentFormatOptions = {
        fileName: editor.document.fileName,
        multiline,
        includeTicketLink,
        ...options
    };

    const commentText = formatRequirementsAsComments(requirements, formatOptions);

    // Insert at cursor position
    const success = await editor.edit(editBuilder => {
        const position = editor.selection.active;
        editBuilder.insert(position, commentText);
    });

    if (success) {
        // Move cursor to end of inserted text
        const lines = commentText.split('\n').length - 1;
        const newPosition = new vscode.Position(
            editor.selection.active.line + lines,
            0
        );
        editor.selection = new vscode.Selection(newPosition, newPosition);

        vscode.window.showInformationMessage(
            `Inserted ${requirements.length} requirement reference(s)`
        );
    } else {
        vscode.window.showErrorMessage('Failed to insert requirements');
    }

    return success;
}

/**
 * Get indentation at cursor position
 */
function getIndentationAtCursor(editor: vscode.TextEditor): string {
    const line = editor.document.lineAt(editor.selection.active.line);
    const match = line.text.match(/^(\s*)/);
    return match ? match[1] : '';
}

/**
 * Insert with proper indentation
 */
export async function insertRequirementsWithIndentation(
    editor: vscode.TextEditor,
    requirements: Requirement[],
    options: Partial<CommentFormatOptions> = {}
): Promise<boolean> {
    const indentation = getIndentationAtCursor(editor);

    // If at start of line, use current indentation
    if (editor.selection.active.character === 0) {
        return insertRequirementsAtCursor(editor, requirements, options);
    }

    // Otherwise, insert on new line with indentation
    const position = new vscode.Position(editor.selection.active.line + 1, 0);
    const newSelection = new vscode.Selection(position, position);

    editor.selection = newSelection;

    return insertRequirementsAtCursor(editor, requirements, options);
}
