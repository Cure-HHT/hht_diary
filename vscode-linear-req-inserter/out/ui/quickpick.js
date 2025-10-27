"use strict";
/**
 * QuickPick UI for selecting requirements from Linear tickets
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
exports.showRequirementPicker = showRequirementPicker;
exports.showTicketThenRequirementPicker = showTicketThenRequirementPicker;
exports.promptForApiToken = promptForApiToken;
const vscode = __importStar(require("vscode"));
/**
 * Show requirement picker for user to select
 */
async function showRequirementPicker(issuesWithReqs) {
    if (issuesWithReqs.length === 0) {
        vscode.window.showInformationMessage('No in-progress tickets found with requirement references');
        return undefined;
    }
    // Build flat list of all requirements with their source tickets
    const items = [];
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
        vscode.window.showInformationMessage('No requirements found in your in-progress tickets');
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
    const uniqueReqs = new Map();
    for (const item of selected) {
        uniqueReqs.set(item.requirement.id, item.requirement);
    }
    return Array.from(uniqueReqs.values());
}
/**
 * Show ticket picker first, then requirement picker
 */
async function showTicketThenRequirementPicker(issuesWithReqs) {
    if (issuesWithReqs.length === 0) {
        vscode.window.showInformationMessage('No in-progress tickets found with requirement references');
        return undefined;
    }
    // First, show ticket picker
    const issueItems = issuesWithReqs.map(({ issue, requirements }) => ({
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
    const reqItems = selectedIssue.requirements.map(req => ({
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
async function promptForApiToken() {
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
//# sourceMappingURL=quickpick.js.map