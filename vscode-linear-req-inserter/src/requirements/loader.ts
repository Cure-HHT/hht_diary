/**
 * Loader for reading requirement definitions from spec/ files
 */

import * as fs from 'fs';
import * as path from 'path';
import { Requirement } from '../linear/types';
import { formatRequirementId, getRequirementLevel } from './parser';

// Pattern to match requirement headers: ### REQ-p00001: Title
const REQ_HEADER_PATTERN = /^###\s+REQ-([pod]\d{5}):\s+(.+)$/gm;

// Pattern to extract metadata
const METADATA_PATTERN = /\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:[^\|]+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)/;

/**
 * Parse requirements from a single markdown file
 */
function parseRequirementsFromFile(filePath: string): Requirement[] {
    try {
        const content = fs.readFileSync(filePath, 'utf-8');
        const requirements: Requirement[] = [];

        let match;
        while ((match = REQ_HEADER_PATTERN.exec(content)) !== null) {
            const id = match[1]; // e.g., "p00001"
            const title = match[2].trim();

            // Try to extract status from following lines
            const remainingContent = content.substring(match.index + match[0].length, match.index + match[0].length + 500);
            const metadataMatch = remainingContent.match(METADATA_PATTERN);

            const level = getRequirementLevel(id);
            const status = metadataMatch ? metadataMatch[2] as 'Active' | 'Draft' | 'Deprecated' : 'Active';

            // Skip invalid requirement IDs
            if (level === null) {
                continue;
            }

            requirements.push({
                id,
                fullId: formatRequirementId(id),
                title,
                level,
                status
            });
        }

        return requirements;
    } catch (error) {
        console.error(`Failed to parse requirements from ${filePath}:`, error);
        return [];
    }
}

/**
 * Load all requirements from spec directory
 */
export function loadRequirementsFromSpec(specPath: string): Map<string, Requirement> {
    const requirements = new Map<string, Requirement>();

    try {
        // Check if spec directory exists
        if (!fs.existsSync(specPath)) {
            console.warn(`Spec directory not found: ${specPath}`);
            return requirements;
        }

        // Read all .md files in spec directory
        const files = fs.readdirSync(specPath)
            .filter(file => file.endsWith('.md') && file !== 'requirements-format.md')
            .map(file => path.join(specPath, file));

        // Parse requirements from each file
        for (const file of files) {
            const fileRequirements = parseRequirementsFromFile(file);
            for (const req of fileRequirements) {
                requirements.set(req.id, req);
            }
        }

        console.log(`Loaded ${requirements.size} requirements from ${specPath}`);
    } catch (error) {
        console.error(`Failed to load requirements from ${specPath}:`, error);
    }

    return requirements;
}

/**
 * Get requirement by ID from cache
 */
export function getRequirement(id: string, requirementMap: Map<string, Requirement>): Requirement | undefined {
    // Handle both formats: "p00001" and "REQ-p00001"
    const cleanId = id.replace(/^REQ-/, '');
    return requirementMap.get(cleanId);
}

/**
 * Get multiple requirements by IDs
 */
export function getRequirements(ids: string[], requirementMap: Map<string, Requirement>): Requirement[] {
    return ids
        .map(id => getRequirement(id, requirementMap))
        .filter((req): req is Requirement => req !== undefined);
}
