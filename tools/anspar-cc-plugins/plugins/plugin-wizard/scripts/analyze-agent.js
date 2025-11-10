#!/usr/bin/env node
/**
 * Parse agent markdown file and extract:
 * - YAML frontmatter (name, description, tools)
 * - Skills mentioned in content
 * - Hooks referenced
 * - Slash commands used
 */

const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  let agentPath = null;

  for (const arg of args) {
    if (arg.startsWith('--agent-path=')) {
      agentPath = arg.split('=')[1];
    } else if (!arg.startsWith('--')) {
      agentPath = arg;
    }
  }

  if (!agentPath) {
    console.error('ERROR: --agent-path required');
    console.error('Usage: analyze-agent.js --agent-path=/path/to/agent.md');
    process.exit(1);
  }

  return { agentPath };
}

function parseFrontmatter(content) {
  const frontmatterRegex = /^---\s*\n([\s\S]*?)\n---/;
  const match = content.match(frontmatterRegex);

  if (!match) {
    return null;
  }

  const frontmatter = {};
  const lines = match[1].split('\n');

  for (const line of lines) {
    const colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      const key = line.substring(0, colonIndex).trim();
      const value = line.substring(colonIndex + 1).trim();
      frontmatter[key] = value;
    }
  }

  return frontmatter;
}

function extractSkills(content) {
  const skills = [];

  // Look for patterns like:
  // - skill-name.skill: Description
  // - bash skills/skill-name.skill
  // ### skill-name

  const skillPatterns = [
    /[-*]\s+(\w+[-\w]*\.skill)[:\s]+([^\n]+)/g,
    /bash\s+skills\/(\w+[-\w]*)\.skill/g,
    /###\s+(\w+[-\w]*)\n([^\n]+)/g
  ];

  for (const pattern of skillPatterns) {
    let match;
    while ((match = pattern.exec(content)) !== null) {
      const name = match[1].replace('.skill', '');
      const description = match[2] || 'No description';

      // Avoid duplicates
      if (!skills.find(s => s.name === name)) {
        skills.push({ name, description: description.trim() });
      }
    }
  }

  return skills;
}

function extractHooks(content) {
  const hooks = [];

  // Look for patterns like:
  // - SessionStart: Description
  // - UserPromptSubmit hook
  // **SessionStart**

  const hookTypes = ['SessionStart', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse'];

  for (const hookType of hookTypes) {
    // Check if hook type is mentioned
    const regex = new RegExp(`(?:[-*]\\s+)?(?:\\*\\*)?${hookType}(?:\\*\\*)?[:\\s]+([^\\n]+)`, 'gi');
    const match = content.match(regex);

    if (match) {
      const description = match[0].replace(/[-*\s]*\**/g, '').replace(hookType, '').replace(':', '').trim();
      hooks.push({
        type: hookType,
        description: description || `${hookType} hook`
      });
    }
  }

  return hooks;
}

function extractCommands(content) {
  const commands = [];

  // Look for patterns like:
  // - /plugin:command-name: Description
  // /plugin:command ARGS

  const commandPattern = /\/(\w+[-\w]*):(\w+[-\w]*)(?:\s+([A-Z_]+))?[:\s]*([^\n]*)/g;

  let match;
  while ((match = commandPattern.exec(content)) !== null) {
    const plugin = match[1];
    const command = match[2];
    const args = match[3] || '';
    const description = match[4] || 'No description';

    const name = `${plugin}:${command}`;

    // Avoid duplicates
    if (!commands.find(c => c.name === name)) {
      commands.push({
        name,
        command,
        plugin,
        args: args.trim(),
        description: description.trim()
      });
    }
  }

  return commands;
}

function analyzeAgent(agentPath) {
  if (!fs.existsSync(agentPath)) {
    console.error(`ERROR: Agent file not found: ${agentPath}`);
    process.exit(1);
  }

  const content = fs.readFileSync(agentPath, 'utf8');

  // Parse frontmatter
  const frontmatter = parseFrontmatter(content);

  if (!frontmatter) {
    console.error('ERROR: Agent file missing YAML frontmatter');
    console.error('');
    console.error('Expected:');
    console.error('---');
    console.error('name: agent-name');
    console.error('description: One-sentence description');
    console.error('---');
    process.exit(1);
  }

  if (!frontmatter.name || !frontmatter.description) {
    console.error('ERROR: Agent frontmatter missing required fields (name, description)');
    process.exit(1);
  }

  // Extract components
  const skills = extractSkills(content);
  const hooks = extractHooks(content);
  const commands = extractCommands(content);

  // Build result
  const result = {
    frontmatter,
    skills,
    hooks,
    commands,
    agentPath,
    agentFilename: path.basename(agentPath)
  };

  // Output as JSON
  console.log(JSON.stringify(result, null, 2));
}

const { agentPath } = parseArgs();
analyzeAgent(agentPath);
