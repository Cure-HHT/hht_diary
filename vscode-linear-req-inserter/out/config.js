"use strict";
/**
 * Extension configuration management
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
exports.getConfig = getConfig;
exports.updateApiToken = updateApiToken;
exports.isConfigured = isConfigured;
exports.getSpecPath = getSpecPath;
exports.validateConfig = validateConfig;
const vscode = __importStar(require("vscode"));
/**
 * Get extension configuration
 */
function getConfig() {
    const config = vscode.workspace.getConfiguration('linearReqInserter');
    return {
        apiToken: config.get('apiToken', ''),
        teamId: config.get('teamId', ''),
        specPath: resolveSpecPath(config.get('specPath', '${workspaceFolder}/spec')),
        commentFormat: config.get('commentFormat', 'multiline'),
        includeTicketLink: config.get('includeTicketLink', false)
    };
}
/**
 * Resolve spec path with variable substitution
 */
function resolveSpecPath(configuredPath) {
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
async function updateApiToken(token) {
    const config = vscode.workspace.getConfiguration('linearReqInserter');
    await config.update('apiToken', token, vscode.ConfigurationTarget.Global);
}
/**
 * Check if extension is configured
 */
function isConfigured() {
    const config = getConfig();
    return !!config.apiToken && config.apiToken.length > 0;
}
/**
 * Get spec path from configuration
 */
function getSpecPath() {
    const config = getConfig();
    return config.specPath;
}
/**
 * Validate configuration
 */
function validateConfig(config) {
    const errors = [];
    if (!config.apiToken) {
        errors.push('Linear API token is not configured');
    }
    // Note: specPath validation happens at runtime when loading requirements
    return errors;
}
//# sourceMappingURL=config.js.map