"use strict";
/**
 * Comment templates for different formats
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatRequirementsAsComments = formatRequirementsAsComments;
exports.formatRequirementIdsOnly = formatRequirementIdsOnly;
exports.getExampleComment = getExampleComment;
const detector_1 = require("./detector");
/**
 * Format requirements as comments
 */
function formatRequirementsAsComments(requirements, options) {
    const prefix = (0, detector_1.getCommentPrefix)(options.fileName);
    const suffix = (0, detector_1.getCommentSuffix)(options.fileName);
    if (options.multiline) {
        return formatMultilineComments(requirements, prefix, suffix, options);
    }
    else {
        return formatSingleLineComment(requirements, prefix, suffix);
    }
}
/**
 * Format as multiline comments (one requirement per line)
 */
function formatMultilineComments(requirements, prefix, suffix, options) {
    const lines = [];
    // Add ticket link if requested
    if (options.includeTicketLink && options.ticketUrl) {
        lines.push(`${prefix} Linear: ${options.ticketUrl}${suffix}`);
    }
    // Add each requirement on its own line
    for (const req of requirements) {
        lines.push(`${prefix} ${req.fullId}: ${req.title}${suffix}`);
    }
    return lines.join('\n') + '\n';
}
/**
 * Format as single line comment (comma-separated)
 */
function formatSingleLineComment(requirements, prefix, suffix) {
    const reqList = requirements
        .map(req => `${req.fullId}: ${req.title}`)
        .join(', ');
    return `${prefix} ${reqList}${suffix}\n`;
}
/**
 * Format just requirement IDs (without titles)
 */
function formatRequirementIdsOnly(requirements, fileName, multiline = true) {
    const prefix = (0, detector_1.getCommentPrefix)(fileName);
    const suffix = (0, detector_1.getCommentSuffix)(fileName);
    if (multiline) {
        const lines = requirements.map(req => `${prefix} ${req.fullId}${suffix}`);
        return lines.join('\n') + '\n';
    }
    else {
        const ids = requirements.map(req => req.fullId).join(', ');
        return `${prefix} ${ids}${suffix}\n`;
    }
}
/**
 * Get example comment for preview
 */
function getExampleComment(fileName) {
    const prefix = (0, detector_1.getCommentPrefix)(fileName);
    const suffix = (0, detector_1.getCommentSuffix)(fileName);
    return `${prefix} REQ-p00001: Example Requirement Title${suffix}`;
}
//# sourceMappingURL=templates.js.map