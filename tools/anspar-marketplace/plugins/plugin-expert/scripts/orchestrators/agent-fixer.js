/**
 * Agent Fixer for Plugin-Expert
 * Generates corrected versions of agent files based on validation results
 * Layer 3: Process Coordinator
 */

const fs = require('fs');
const path = require('path');

/**
 * Generate a corrected version of an agent file
 * @param {string} content - Original agent content
 * @param {object} validationResult - Results from validateAgentFile()
 * @param {object} options - Fix options
 * @returns {object} {fixed: string, changes: Array, canAutoFix: boolean}
 */
function generateFixedAgent(content, validationResult, options = {}) {
  const {
    addMissingFrontmatter = true,
    addMissingSections = true,
    reduceEmphasis = true,
    fixHeadingHierarchy = true,
    addToolExamples = false  // Conservative - don't guess at tool invocations
  } = options;

  const changes = [];
  let fixed = content;
  let canAutoFix = true;

  // 1. Fix missing YAML frontmatter
  if (validationResult.errors.some(e => e.includes('Missing YAML frontmatter'))) {
    if (addMissingFrontmatter) {
      const agentName = extractAgentNameFromContent(content) || 'UnnamedAgent';
      const description = extractDescriptionFromContent(content) || `${agentName} agent for Claude Code`;

      const frontmatter = `---
name: ${agentName}
description: ${description}
---

`;
      fixed = frontmatter + fixed;
      changes.push({
        type: 'added',
        item: 'YAML frontmatter',
        details: `Added name: ${agentName}, description: ${description}`
      });
    } else {
      canAutoFix = false;
    }
  }

  // 2. Add missing sections
  if (addMissingSections) {
    const sections = validationResult.metrics || {};

    // Extract existing content after frontmatter
    let bodyStart = 0;
    if (fixed.startsWith('---\n')) {
      const endIndex = fixed.indexOf('\n---\n', 4);
      if (endIndex !== -1) {
        bodyStart = endIndex + 5;
      }
    }

    const frontmatter = fixed.substring(0, bodyStart);
    let body = fixed.substring(bodyStart);

    // Add missing Identity section
    if (!sections.hasIdentity && validationResult.warnings.some(w => w.includes('Missing Identity'))) {
      const agentName = extractAgentNameFromContent(fixed) || 'UnnamedAgent';
      const identitySection = `
# ${agentName} Agent

You are the ${agentName} agent, a specialized assistant for [describe purpose here].

## Purpose

[Describe what this agent does and when to use it]

`;
      body = identitySection + body;
      changes.push({
        type: 'added',
        item: 'Identity section',
        details: 'Added # Agent title and ## Purpose section'
      });
    }

    // Add missing Operational section
    if (!sections.hasOperationalApproach && validationResult.warnings.some(w => w.includes('Missing Operational'))) {
      const operationalSection = `
## Core Capabilities

You can:
- **[Capability 1]**: [Description]
- **[Capability 2]**: [Description]
- **[Capability 3]**: [Description]

## Workflow

When activated, follow these steps:

1. **[Step 1]**: [Description]
2. **[Step 2]**: [Description]
3. **[Step 3]**: [Description]

`;
      body = body + '\n' + operationalSection;
      changes.push({
        type: 'added',
        item: 'Operational section',
        details: 'Added ## Core Capabilities and ## Workflow sections (templates)'
      });
    }

    // Add missing Tools section
    if (!sections.hasAvailableTools && validationResult.warnings.some(w => w.includes('Missing Tools'))) {
      const toolsSection = `
## Available Tools

### Tool Name
**Script**: \`scripts/tool-name.sh\`

**Purpose**: [What this tool does]

**Usage**:
\`\`\`bash
bash \${CLAUDE_PLUGIN_ROOT}/scripts/tool-name.sh [args]
\`\`\`

**When to use**:
- [Scenario 1]
- [Scenario 2]

**Parameters**:
- \`arg1\`: [Description]
- \`arg2\`: [Description]

`;
      body = body + '\n' + toolsSection;
      changes.push({
        type: 'added',
        item: 'Tools section',
        details: 'Added ## Available Tools section (template)'
      });
    }

    fixed = frontmatter + body;
  }

  // 3. Reduce excessive emphasis
  if (reduceEmphasis && validationResult.metrics.emphasisCount > 20) {
    const reduction = reduceExcessiveEmphasis(fixed, validationResult.metrics.emphasisCount);
    if (reduction.changed) {
      fixed = reduction.content;
      changes.push({
        type: 'modified',
        item: 'Emphasis markers',
        details: `Reduced from ${validationResult.metrics.emphasisCount} to ~${reduction.newCount} (removed redundant emphasis)`
      });
    }
  }

  // 4. Fix heading hierarchy
  if (fixHeadingHierarchy && validationResult.warnings.some(w => w.includes('First heading should be level 1'))) {
    // Find first heading and ensure it's level 1
    const lines = fixed.split('\n');
    let firstHeadingIndex = -1;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].match(/^#{1,6}\s+/)) {
        firstHeadingIndex = i;
        break;
      }
    }

    if (firstHeadingIndex !== -1) {
      const match = lines[firstHeadingIndex].match(/^(#{2,6})\s+(.+)$/);
      if (match) {
        lines[firstHeadingIndex] = `# ${match[2]}`;
        fixed = lines.join('\n');
        changes.push({
          type: 'modified',
          item: 'Heading hierarchy',
          details: 'Changed first heading to level 1 (#)'
        });
      }
    }
  }

  return {
    fixed,
    changes,
    canAutoFix
  };
}

/**
 * Extract likely agent name from content
 * @param {string} content - Agent content
 * @returns {string|null} Agent name
 */
function extractAgentNameFromContent(content) {
  // Try to find name in frontmatter first
  const frontmatterMatch = content.match(/name:\s*(\S+)/);
  if (frontmatterMatch) {
    return frontmatterMatch[1];
  }

  // Try to find in first heading
  const headingMatch = content.match(/^#\s+(.+?)\s+Agent/m);
  if (headingMatch) {
    return headingMatch[1].trim().replace(/\s+/g, '');
  }

  // Try any first heading
  const anyHeadingMatch = content.match(/^#\s+(.+)/m);
  if (anyHeadingMatch) {
    return anyHeadingMatch[1].trim().replace(/\s+/g, '');
  }

  return null;
}

/**
 * Extract likely description from content
 * @param {string} content - Agent content
 * @returns {string|null} Description
 */
function extractDescriptionFromContent(content) {
  // Try to find description in frontmatter
  const frontmatterMatch = content.match(/description:\s*(.+)/);
  if (frontmatterMatch) {
    return frontmatterMatch[1].trim();
  }

  // Try to find "You are" statement
  const youAreMatch = content.match(/You are (?:the )?(.+?)[.,]/);
  if (youAreMatch) {
    return youAreMatch[1].trim();
  }

  // Try to find **Purpose** statement
  const purposeMatch = content.match(/\*\*Purpose\*\*:\s*(.+?)(?:\n|$)/);
  if (purposeMatch) {
    return purposeMatch[1].trim();
  }

  return null;
}

/**
 * Reduce excessive emphasis markers intelligently
 * @param {string} content - Agent content
 * @param {number} currentCount - Current emphasis count
 * @returns {object} {content: string, changed: boolean, newCount: number}
 */
function reduceExcessiveEmphasis(content, currentCount) {
  // Strategy: Remove emphasis from less critical contexts
  // Keep emphasis in:
  // - Section headers with emoji (⚡ CRITICAL, 🔒 SECURITY)
  // - ALWAYS/NEVER lists
  // - Error handling sections

  let modified = content;
  let changed = false;

  // 1. Remove redundant emphasis in regular paragraphs
  // Pattern: "**IMPORTANT**: Some text" -> "Important: Some text" (keep first occurrence in section)
  const lines = content.split('\n');
  const emphasisMarkers = ['CRITICAL', 'IMPORTANT', 'MUST', 'NEVER', 'ALWAYS', 'MANDATORY', 'WARNING', 'REQUIRED'];

  let inEmphasisSection = false;
  let emphasisInSection = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Reset counter on new section
    if (line.match(/^#{1,6}\s+/)) {
      inEmphasisSection = line.match(/⚡|🔒|🚨|⚠️|❌|CRITICAL|IMPORTANT/);
      emphasisInSection = 0;
      continue;
    }

    // Count emphasis in line
    const lineEmphasisCount = emphasisMarkers.reduce((count, marker) => {
      const regex = new RegExp(marker, 'gi');
      const matches = line.match(regex);
      return count + (matches ? matches.length : 0);
    }, 0);

    if (lineEmphasisCount > 0) {
      emphasisInSection += lineEmphasisCount;

      // If we already have 2+ emphasis markers in this section and it's not a critical section
      if (emphasisInSection > 2 && !inEmphasisSection) {
        // Reduce emphasis: **IMPORTANT** -> Important, **CRITICAL** -> Critical
        let modifiedLine = line;
        for (const marker of emphasisMarkers) {
          // Only de-emphasize inline markers, keep list items
          if (!line.trim().startsWith('-') && !line.trim().startsWith('*')) {
            modifiedLine = modifiedLine.replace(
              new RegExp(`\\*\\*${marker}\\*\\*`, 'gi'),
              marker.charAt(0) + marker.slice(1).toLowerCase()
            );
          }
        }

        if (modifiedLine !== line) {
          lines[i] = modifiedLine;
          changed = true;
        }
      }
    }
  }

  if (changed) {
    modified = lines.join('\n');
  }

  // Count new emphasis
  const newCount = emphasisMarkers.reduce((count, marker) => {
    const regex = new RegExp(marker, 'gi');
    const matches = modified.match(regex);
    return count + (matches ? matches.length : 0);
  }, 0);

  return {
    content: modified,
    changed,
    newCount
  };
}

/**
 * Apply fixes to a file and save as .fixed
 * @param {string} filePath - Original file path
 * @param {object} validationResult - Validation results
 * @param {object} options - Fix options
 * @returns {object} {fixedPath: string, changes: Array}
 */
function applyFixesToFile(filePath, validationResult, options = {}) {
  const content = fs.readFileSync(filePath, 'utf8');
  const result = generateFixedAgent(content, validationResult, options);

  const fixedPath = filePath + '.fixed';
  fs.writeFileSync(fixedPath, result.fixed, 'utf8');

  return {
    fixedPath,
    changes: result.changes,
    canAutoFix: result.canAutoFix
  };
}

/**
 * Generate a change summary report
 * @param {Array} changes - Array of change objects
 * @returns {string} Formatted report
 */
function generateChangeReport(changes) {
  if (changes.length === 0) {
    return 'No changes needed.';
  }

  const lines = ['Changes made:', ''];

  const added = changes.filter(c => c.type === 'added');
  const modified = changes.filter(c => c.type === 'modified');
  const removed = changes.filter(c => c.type === 'removed');

  if (added.length > 0) {
    lines.push('✅ ADDED:');
    added.forEach(c => lines.push(`   - ${c.item}: ${c.details}`));
    lines.push('');
  }

  if (modified.length > 0) {
    lines.push('🔧 MODIFIED:');
    modified.forEach(c => lines.push(`   - ${c.item}: ${c.details}`));
    lines.push('');
  }

  if (removed.length > 0) {
    lines.push('🗑️  REMOVED:');
    removed.forEach(c => lines.push(`   - ${c.item}: ${c.details}`));
    lines.push('');
  }

  return lines.join('\n');
}

module.exports = {
  generateFixedAgent,
  applyFixesToFile,
  generateChangeReport,
  extractAgentNameFromContent,
  extractDescriptionFromContent,
  reduceExcessiveEmphasis
};
