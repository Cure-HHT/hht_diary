"use strict";
/**
 * Loader for reading requirement definitions from spec/ files
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
exports.loadRequirementsFromSpec = loadRequirementsFromSpec;
exports.getRequirement = getRequirement;
exports.getRequirements = getRequirements;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const parser_1 = require("./parser");
// Pattern to match requirement headers: ### REQ-p00001: Title
const REQ_HEADER_PATTERN = /^###\s+REQ-([pod]\d{5}):\s+(.+)$/gm;
// Pattern to extract metadata
const METADATA_PATTERN = /\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:[^\|]+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)/;
/**
 * Parse requirements from a single markdown file
 */
function parseRequirementsFromFile(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf-8');
        const requirements = [];
        let match;
        while ((match = REQ_HEADER_PATTERN.exec(content)) !== null) {
            const id = match[1]; // e.g., "p00001"
            const title = match[2].trim();
            // Try to extract status from following lines
            const remainingContent = content.substring(match.index + match[0].length, match.index + match[0].length + 500);
            const metadataMatch = remainingContent.match(METADATA_PATTERN);
            const level = (0, parser_1.getRequirementLevel)(id);
            const status = metadataMatch ? metadataMatch[2] : 'Active';
            // Skip invalid requirement IDs
            if (level === null) {
                continue;
            }
            requirements.push({
                id,
                fullId: (0, parser_1.formatRequirementId)(id),
                title,
                level,
                status
            });
        }
        return requirements;
    }
    catch (error) {
        console.error(`Failed to parse requirements from ${filePath}:`, error);
        return [];
    }
}
/**
 * Load all requirements from spec directory
 */
function loadRequirementsFromSpec(specPath) {
    const requirements = new Map();
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
    }
    catch (error) {
        console.error(`Failed to load requirements from ${specPath}:`, error);
    }
    return requirements;
}
/**
 * Get requirement by ID from cache
 */
function getRequirement(id, requirementMap) {
    // Handle both formats: "p00001" and "REQ-p00001"
    const cleanId = id.replace(/^REQ-/, '');
    return requirementMap.get(cleanId);
}
/**
 * Get multiple requirements by IDs
 */
function getRequirements(ids, requirementMap) {
    return ids
        .map(id => getRequirement(id, requirementMap))
        .filter((req) => req !== undefined);
}
//# sourceMappingURL=loader.js.map