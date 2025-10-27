"use strict";
/**
 * Completion provider for text pattern triggers (//req, --req, #req, etc.)
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
exports.createCompletionItems = createCompletionItems;
exports.matchesTriggerPattern = matchesTriggerPattern;
exports.getTriggerReplacementRange = getTriggerReplacementRange;
const vscode = __importStar(require("vscode"));
/**
 * Create completion items from requirements
 */
function createCompletionItems(issuesWithReqs, range) {
    const items = [];
    for (const { issue, requirements } of issuesWithReqs) {
        for (const req of requirements) {
            const item = new vscode.CompletionItem(`${req.fullId}: ${req.title}`, vscode.CompletionItemKind.Reference);
            item.detail = `From ticket: ${issue.identifier} - ${issue.title}`;
            item.documentation = new vscode.MarkdownString(`**Level:** ${req.level}  \n` +
                `**Status:** ${req.status}  \n` +
                `**Ticket:** [${issue.identifier}](${issue.url})  \n\n` +
                `_${issue.title}_`);
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
function matchesTriggerPattern(line, position) {
    const textBeforeCursor = line.substring(0, position.character);
    // Match patterns like: //LINEAR, --LINEAR, #LINEAR, <!--LINEAR
    const patterns = [
        /\/\/\s*LINEAR$/i, // //LINEAR
        /--\s*LINEAR$/i, // --LINEAR
        /#\s*LINEAR$/i, // #LINEAR
        /<!--\s*LINEAR$/i // <!--LINEAR
    ];
    return patterns.some(pattern => pattern.test(textBeforeCursor));
}
/**
 * Get replacement range for the trigger pattern
 */
function getTriggerReplacementRange(document, position) {
    const line = document.lineAt(position.line).text;
    const textBeforeCursor = line.substring(0, position.character);
    // Find where the pattern starts
    const match = textBeforeCursor.match(/(\/\/|--|#|<!--)\s*LINEAR$/i);
    if (!match || match.index === undefined) {
        return undefined;
    }
    const startChar = match.index;
    return new vscode.Range(new vscode.Position(position.line, startChar), position);
}
//# sourceMappingURL=completion.js.map