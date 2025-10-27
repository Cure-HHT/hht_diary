"use strict";
/**
 * Comment insertion logic for VS Code editor
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.insertRequirementsAtCursor = insertRequirementsAtCursor;
exports.insertRequirementsWithIndentation = insertRequirementsWithIndentation;
const vscode = __importStar(require("vscode"));
const templates_1 = require("./templates");
/**
 * Insert requirements as comments at cursor position
 */
async function insertRequirementsAtCursor(editor, requirements, options = {}) {
    if (requirements.length === 0) {
        vscode.window.showWarningMessage('No requirements to insert');
        return false;
    }
    const config = vscode.workspace.getConfiguration('linearReqInserter');
    const multiline = config.get('commentFormat', 'multiline') === 'multiline';
    const includeTicketLink = config.get('includeTicketLink', false);
    const formatOptions = {
        fileName: editor.document.fileName,
        multiline,
        includeTicketLink,
        ...options
    };
    const commentText = (0, templates_1.formatRequirementsAsComments)(requirements, formatOptions);
    // Insert at cursor position
    const success = await editor.edit(editBuilder => {
        const position = editor.selection.active;
        editBuilder.insert(position, commentText);
    });
    if (success) {
        // Move cursor to end of inserted text
        const lines = commentText.split('\n').length - 1;
        const newPosition = new vscode.Position(editor.selection.active.line + lines, 0);
        editor.selection = new vscode.Selection(newPosition, newPosition);
        vscode.window.showInformationMessage(`Inserted ${requirements.length} requirement reference(s)`);
    }
    else {
        vscode.window.showErrorMessage('Failed to insert requirements');
    }
    return success;
}
/**
 * Get indentation at cursor position
 */
function getIndentationAtCursor(editor) {
    const line = editor.document.lineAt(editor.selection.active.line);
    const match = line.text.match(/^(\s*)/);
    return match ? match[1] : '';
}
/**
 * Insert with proper indentation
 */
async function insertRequirementsWithIndentation(editor, requirements, options = {}) {
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
//# sourceMappingURL=inserter.js.map