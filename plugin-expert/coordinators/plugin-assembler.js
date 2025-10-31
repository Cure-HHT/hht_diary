/**
 * Plugin Assembler for Plugin-Expert
 * Coordinate all builders to assemble a complete plugin
 * Layer 3: Process Coordinator (depends on Layers 1 & 2)
 */

const fs = require('fs');
const path = require('path');

// Layer 1 utilities
const { PathManager } = require('../utilities/path-manager');
const { safeWrite } = require('../utilities/file-ops');
const { safeJSONStringify } = require('../utilities/escape-helpers');

// Layer 2 builders
const { buildPluginMetadata, buildMarketplaceMetadata } = require('../builders/metadata-builder');
const { buildSkillPrompt, buildAgentPrompt, buildCommandPrompt } = require('../builders/prompt-builder');
const { buildCommands, buildSingleCommand } = require('../builders/command-builder');
const { buildHooksConfig } = require('../builders/hook-builder');
const { buildDocumentation } = require('../builders/docs-builder');
const { buildTestSuite, createTestFiles } = require('../builders/test-builder');
const { createPluginStructure } = require('../builders/organization');

/**
 * Assemble a complete plugin from specifications
 * @param {object} spec - Plugin specification
 * @param {string} outputPath - Where to create the plugin
 * @param {object} options - Assembly options
 * @returns {Promise<object>} Assembly result
 */
async function assemblePlugin(spec, outputPath, options = {}) {
  const {
    createTests = true,
    createDocs = true,
    createExamples = false,
    backup = true,
    validate = true
  } = options;

  const pathManager = new PathManager(outputPath);
  const result = {
    success: false,
    path: outputPath,
    created: [],
    errors: [],
    warnings: []
  };

  try {
    // Step 1: Create directory structure
    console.log('Creating plugin structure...');
    const structureResult = createPluginStructure(outputPath, {
      createFiles: false
    });
    result.created.push(...structureResult.created);

    // Step 2: Build and write metadata
    console.log('Building metadata...');
    const metadata = await buildMetadata(spec, pathManager);
    result.created.push('.claude-plugin/plugin.json');

    // Step 3: Build components
    console.log('Building components...');
    const components = await buildComponents(spec, pathManager);
    result.created.push(...components.created);

    // Step 4: Build documentation
    if (createDocs) {
      console.log('Building documentation...');
      const docs = await buildDocs(spec, components, pathManager);
      result.created.push(...docs.created);
    }

    // Step 5: Build tests
    if (createTests) {
      console.log('Building tests...');
      const tests = buildTestSuite(spec, components, outputPath);
      const testResult = createTestFiles(tests, outputPath);
      result.created.push(...testResult.created);
    }

    // Step 6: Create examples
    if (createExamples) {
      console.log('Creating examples...');
      const examples = await createExampleFiles(spec, pathManager);
      result.created.push(...examples.created);
    }

    // Step 7: Validate if requested
    if (validate) {
      console.log('Validating plugin...');
      const validation = await validateAssembledPlugin(outputPath);
      result.warnings.push(...validation.warnings);
      if (!validation.valid) {
        result.errors.push(...validation.errors);
      }
    }

    result.success = result.errors.length === 0;

  } catch (error) {
    result.errors.push(`Assembly failed: ${error.message}`);
  }

  return result;
}

/**
 * Build and write plugin metadata
 * @param {object} spec - Plugin specification
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Metadata result
 */
async function buildMetadata(spec, pathManager) {
  // Build plugin.json
  const pluginMetadata = buildPluginMetadata({
    name: spec.name,
    version: spec.version,
    description: spec.description,
    author: spec.author,
    keywords: spec.keywords,
    repository: spec.repository,
    homepage: spec.homepage,
    license: spec.license
  });

  // Write plugin.json
  const pluginJsonPath = pathManager.getConfigFilePath('plugin.json');
  await safeWrite(pluginJsonPath, safeJSONStringify(pluginMetadata, 2), false);

  // Build and write marketplace.json if needed
  if (spec.marketplace) {
    const marketplaceMetadata = buildMarketplaceMetadata(spec.marketplace);
    const marketplacePath = pathManager.getConfigFilePath('marketplace.json');
    await safeWrite(marketplacePath, safeJSONStringify(marketplaceMetadata, 2), false);
  }

  return { pluginMetadata, marketplaceMetadata: spec.marketplace };
}

/**
 * Build all plugin components
 * @param {object} spec - Plugin specification
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Components result
 */
async function buildComponents(spec, pathManager) {
  const result = {
    commands: [],
    agents: [],
    skills: [],
    hooks: [],
    created: []
  };

  // Build commands
  if (spec.commands && spec.commands.length > 0) {
    for (const cmdSpec of spec.commands) {
      const command = typeof cmdSpec === 'string'
        ? { name: cmdSpec, description: `${cmdSpec} command` }
        : cmdSpec;

      const built = buildSingleCommand(command, pathManager);
      await safeWrite(built.filePath, built.content, false);
      result.commands.push(built);
      result.created.push(`commands/${built.fileName}`);
    }
  }

  // Build agents
  if (spec.agents && spec.agents.length > 0) {
    for (const agentSpec of spec.agents) {
      const agent = typeof agentSpec === 'string'
        ? { name: agentSpec, description: `${agentSpec} agent` }
        : agentSpec;

      const built = buildAgentPrompt(agent);
      const filePath = pathManager.getComponentItemPath('agents', agent.name, '.md');
      await safeWrite(filePath, built.prompt, false);
      result.agents.push(built);
      result.created.push(`agents/${agent.name}.md`);
    }
  }

  // Build skills
  if (spec.skills && spec.skills.length > 0) {
    for (const skillSpec of spec.skills) {
      const skill = typeof skillSpec === 'string'
        ? { name: skillSpec, description: `${skillSpec} skill` }
        : skillSpec;

      const built = buildSkillPrompt(skill);
      const skillDir = pathManager.resolve('skills', skill.name);
      pathManager.ensureDir('skills', skill.name);
      const filePath = path.join(skillDir, 'SKILL.md');
      await safeWrite(filePath, built.prompt, false);
      result.skills.push(built);
      result.created.push(`skills/${skill.name}/SKILL.md`);
    }
  }

  // Build hooks
  if (spec.hooks && spec.hooks.length > 0) {
    const hooksConfig = buildHooksConfig(spec.hooks, pathManager.getBasePath());
    const hooksPath = pathManager.resolve('hooks', 'hooks.json');
    await safeWrite(hooksPath, safeJSONStringify(hooksConfig, 2), false);
    result.hooks = hooksConfig.hooks;
    result.created.push('hooks/hooks.json');

    // Create hook scripts
    for (const hook of spec.hooks) {
      if (hook.script) {
        const scriptPath = pathManager.resolve('hooks', hook.script);
        const scriptContent = generateHookScript(hook.event);
        await safeWrite(scriptPath, scriptContent, false);

        // Make executable
        if (process.platform !== 'win32') {
          fs.chmodSync(scriptPath, '755');
        }

        result.created.push(`hooks/${hook.script}`);
      }
    }
  }

  return result;
}

/**
 * Build documentation files
 * @param {object} spec - Plugin specification
 * @param {object} components - Built components
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Documentation result
 */
async function buildDocs(spec, components, pathManager) {
  const result = { created: [] };

  const docs = buildDocumentation(spec, components, pathManager.getBasePath());

  // Write README
  if (docs.readme) {
    await safeWrite(pathManager.resolve('README.md'), docs.readme, false);
    result.created.push('README.md');
  }

  // Write other documentation files
  const docFiles = {
    'docs/INSTALLATION.md': docs.installation,
    'docs/USAGE.md': docs.usage,
    'CONTRIBUTING.md': docs.contributing,
    'CHANGELOG.md': docs.changelog
  };

  for (const [filePath, content] of Object.entries(docFiles)) {
    if (content) {
      const fullPath = pathManager.resolve(...filePath.split('/'));
      // Ensure docs directory exists
      if (filePath.startsWith('docs/')) {
        pathManager.ensureDir('docs');
      }
      await safeWrite(fullPath, content, false);
      result.created.push(filePath);
    }
  }

  return result;
}

/**
 * Create example files for the plugin
 * @param {object} spec - Plugin specification
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Examples result
 */
async function createExampleFiles(spec, pathManager) {
  const result = { created: [] };

  pathManager.ensureDir('examples');

  // Create example for each command
  if (spec.commands && spec.commands.length > 0) {
    const commandExamples = spec.commands.map(cmd => {
      const name = typeof cmd === 'string' ? cmd : cmd.name;
      return `# Example: /${name}

\`\`\`bash
/${name}
\`\`\`

Expected output:
[Command executes successfully]
`;
    }).join('\n---\n\n');

    await safeWrite(
      pathManager.resolve('examples', 'commands.md'),
      commandExamples,
      false
    );
    result.created.push('examples/commands.md');
  }

  // Create configuration example
  const configExample = `# Example Configuration

## Custom plugin.json

\`\`\`json
${safeJSONStringify({
  ...spec,
  custom_option: 'value',
  advanced: {
    setting1: true,
    setting2: 'example'
  }
}, 2)}
\`\`\`

## Environment Variables

\`\`\`bash
export PLUGIN_SETTING="value"
export PLUGIN_DEBUG=true
\`\`\`
`;

  await safeWrite(
    pathManager.resolve('examples', 'configuration.md'),
    configExample,
    false
  );
  result.created.push('examples/configuration.md');

  return result;
}

/**
 * Generate hook script content
 * @param {string} event - Hook event type
 * @returns {string} Script content
 */
function generateHookScript(event) {
  return `#!/bin/bash
# Hook script for ${event}

# Access environment variables
TOOL_NAME="\${CLAUDE_TOOL_NAME:-}"
SESSION_ID="\${CLAUDE_SESSION_ID:-}"

# Log the event
echo "[${event}] Tool: \$TOOL_NAME, Session: \$SESSION_ID"

# Add your custom logic here

# Exit with 0 to continue, non-zero to abort
exit 0`;
}

/**
 * Validate the assembled plugin
 * @param {string} pluginPath - Path to plugin
 * @returns {Promise<object>} Validation result
 */
async function validateAssembledPlugin(pluginPath) {
  const { parsePlugin } = require('../builders/parser');
  const { validateOrganization } = require('../builders/organization');

  const result = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Parse and validate structure
  const parsed = parsePlugin(pluginPath);
  if (!parsed.valid) {
    result.valid = false;
    result.errors.push(...parsed.errors);
  }
  result.warnings.push(...parsed.warnings);

  // Validate organization
  const orgValidation = validateOrganization(pluginPath);
  if (!orgValidation.valid) {
    result.valid = false;
    result.errors.push(...orgValidation.issues);
  }
  result.warnings.push(...orgValidation.suggestions);

  return result;
}

/**
 * Plan the architecture for a plugin
 * @param {object} spec - Plugin specification
 * @returns {object} Architecture plan
 */
function planArchitecture(spec) {
  const plan = {
    structure: {
      directories: [],
      files: []
    },
    dependencies: {},
    integration: []
  };

  // Plan directory structure
  plan.structure.directories.push('.claude-plugin');

  if (spec.commands && spec.commands.length > 0) {
    plan.structure.directories.push('commands');
    plan.structure.files.push(...spec.commands.map(c =>
      `commands/${typeof c === 'string' ? c : c.name}.md`
    ));
  }

  if (spec.agents && spec.agents.length > 0) {
    plan.structure.directories.push('agents');
    plan.structure.files.push(...spec.agents.map(a =>
      `agents/${typeof a === 'string' ? a : a.name}.md`
    ));
  }

  if (spec.skills && spec.skills.length > 0) {
    plan.structure.directories.push('skills');
    spec.skills.forEach(s => {
      const name = typeof s === 'string' ? s : s.name;
      plan.structure.directories.push(`skills/${name}`);
      plan.structure.files.push(`skills/${name}/SKILL.md`);
    });
  }

  if (spec.hooks && spec.hooks.length > 0) {
    plan.structure.directories.push('hooks');
    plan.structure.files.push('hooks/hooks.json');
  }

  // Plan dependencies
  if (spec.agents && spec.commands) {
    plan.dependencies['command-agent'] = 'Commands may invoke agents';
  }

  if (spec.hooks && spec.commands) {
    plan.dependencies['hook-command'] = 'Hooks may be triggered by commands';
  }

  // Plan integration points
  if (spec.hooks) {
    spec.hooks.forEach(hook => {
      plan.integration.push({
        type: 'hook',
        event: hook.event || hook,
        description: `Integrate with ${hook.event || hook} event`
      });
    });
  }

  return plan;
}

module.exports = {
  assemblePlugin,
  buildMetadata,
  buildComponents,
  buildDocs,
  createExampleFiles,
  generateHookScript,
  validateAssembledPlugin,
  planArchitecture
};