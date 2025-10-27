"use strict";
/**
 * Parser for extracting requirement IDs from Linear ticket text
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractRequirementIds = extractRequirementIds;
exports.extractRequirementsFromIssue = extractRequirementsFromIssue;
exports.isValidRequirementId = isValidRequirementId;
exports.formatRequirementId = formatRequirementId;
exports.getRequirementLevel = getRequirementLevel;
// Pattern to match REQ-p00001, REQ-o00042, REQ-d00156
const REQ_PATTERN = /REQ-([pod]\d{5})/gi;
/**
 * Extract all requirement IDs from text
 */
function extractRequirementIds(text) {
    if (!text) {
        return [];
    }
    const matches = Array.from(text.matchAll(REQ_PATTERN));
    const ids = matches.map(match => match[1]); // Extract just the ID part (e.g., "p00001")
    // Remove duplicates
    return Array.from(new Set(ids));
}
/**
 * Extract requirement IDs from Linear issue (description + comments)
 */
function extractRequirementsFromIssue(description = '', comments = []) {
    const descriptionIds = extractRequirementIds(description);
    const commentIds = comments.flatMap(comment => extractRequirementIds(comment.body));
    // Combine and deduplicate
    return Array.from(new Set([...descriptionIds, ...commentIds]));
}
/**
 * Validate requirement ID format
 */
function isValidRequirementId(id) {
    return /^[pod]\d{5}$/.test(id);
}
/**
 * Format requirement ID to full form (e.g., "p00001" -> "REQ-p00001")
 */
function formatRequirementId(id) {
    if (id.startsWith('REQ-')) {
        return id;
    }
    return `REQ-${id}`;
}
/**
 * Get requirement level from ID
 */
function getRequirementLevel(id) {
    const match = id.match(/^([pod])\d{5}$/);
    if (!match) {
        return null;
    }
    switch (match[1]) {
        case 'p': return 'PRD';
        case 'o': return 'OPS';
        case 'd': return 'DEV';
        default: return null;
    }
}
//# sourceMappingURL=parser.js.map