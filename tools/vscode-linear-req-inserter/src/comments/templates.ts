/**
 * Comment templates for different formats
 */

import { Requirement } from '../linear/types';
import { getCommentPrefix, getCommentSuffix } from './detector';

export interface CommentFormatOptions {
    fileName: string;
    multiline: boolean;
    includeTicketLink?: boolean;
    ticketUrl?: string;
}

/**
 * Format requirements as comments
 */
export function formatRequirementsAsComments(
    requirements: Requirement[],
    options: CommentFormatOptions
): string {
    const prefix = getCommentPrefix(options.fileName);
    const suffix = getCommentSuffix(options.fileName);

    if (options.multiline) {
        return formatMultilineComments(requirements, prefix, suffix, options);
    } else {
        return formatSingleLineComment(requirements, prefix, suffix);
    }
}

/**
 * Format as multiline comments (one requirement per line)
 */
function formatMultilineComments(
    requirements: Requirement[],
    prefix: string,
    suffix: string,
    options: CommentFormatOptions
): string {
    const lines: string[] = [];

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
function formatSingleLineComment(
    requirements: Requirement[],
    prefix: string,
    suffix: string
): string {
    const reqList = requirements
        .map(req => `${req.fullId}: ${req.title}`)
        .join(', ');

    return `${prefix} ${reqList}${suffix}\n`;
}

/**
 * Format just requirement IDs (without titles)
 */
export function formatRequirementIdsOnly(
    requirements: Requirement[],
    fileName: string,
    multiline: boolean = true
): string {
    const prefix = getCommentPrefix(fileName);
    const suffix = getCommentSuffix(fileName);

    if (multiline) {
        const lines = requirements.map(req => `${prefix} ${req.fullId}${suffix}`);
        return lines.join('\n') + '\n';
    } else {
        const ids = requirements.map(req => req.fullId).join(', ');
        return `${prefix} ${ids}${suffix}\n`;
    }
}

/**
 * Get example comment for preview
 */
export function getExampleComment(fileName: string): string {
    const prefix = getCommentPrefix(fileName);
    const suffix = getCommentSuffix(fileName);

    return `${prefix} REQ-p00001: Example Requirement Title${suffix}`;
}
