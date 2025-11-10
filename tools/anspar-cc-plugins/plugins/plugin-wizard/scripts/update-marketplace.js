#!/usr/bin/env node
/**
 * Update marketplace.json to register a new plugin
 */

const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const params = {
    marketplacePath: null,
    pluginName: null,
    description: null,
    version: '1.0.0'
  };

  for (const arg of args) {
    if (arg.startsWith('--marketplace-path=')) {
      params.marketplacePath = arg.split('=')[1];
    } else if (arg.startsWith('--plugin-name=')) {
      params.pluginName = arg.split('=')[1];
    } else if (arg.startsWith('--description=')) {
      params.description = arg.split('=')[1];
    } else if (arg.startsWith('--version=')) {
      params.version = arg.split('=')[1];
    }
  }

  if (!params.marketplacePath || !params.pluginName) {
    console.error('ERROR: --marketplace-path and --plugin-name required');
    console.error('Usage: update-marketplace.js --marketplace-path=PATH --plugin-name=NAME [--description=DESC] [--version=VER]');
    process.exit(1);
  }

  return params;
}

function updateMarketplace(params) {
  const marketplaceJsonPath = path.join(params.marketplacePath, '.claude-plugin', 'marketplace.json');

  if (!fs.existsSync(marketplaceJsonPath)) {
    console.error(`ERROR: marketplace.json not found at: ${marketplaceJsonPath}`);
    process.exit(1);
  }

  // Read marketplace.json
  let marketplace;
  try {
    marketplace = JSON.parse(fs.readFileSync(marketplaceJsonPath, 'utf8'));
  } catch (error) {
    console.error(`ERROR: Failed to parse marketplace.json: ${error.message}`);
    process.exit(1);
  }

  // Check if plugin already registered
  if (marketplace.plugins.find(p => p.name === params.pluginName)) {
    console.error(`ERROR: Plugin '${params.pluginName}' is already registered in marketplace`);
    process.exit(1);
  }

  // Read plugin.json to get description if not provided
  const pluginJsonPath = path.join(params.marketplacePath, 'plugins', params.pluginName, '.claude-plugin', 'plugin.json');
  let pluginDescription = params.description;

  if (!pluginDescription && fs.existsSync(pluginJsonPath)) {
    try {
      const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
      pluginDescription = pluginJson.description || 'No description';
    } catch (error) {
      pluginDescription = 'No description';
    }
  }

  // Add plugin to marketplace
  const pluginEntry = {
    name: params.pluginName,
    source: `./plugins/${params.pluginName}`,
    description: pluginDescription || 'No description',
    version: params.version
  };

  marketplace.plugins.push(pluginEntry);

  // Write updated marketplace.json
  try {
    fs.writeFileSync(marketplaceJsonPath, JSON.stringify(marketplace, null, 2) + '\n');
    console.log(`Successfully registered plugin '${params.pluginName}' in marketplace`);
    console.log('');
    console.log('Plugin entry:');
    console.log(JSON.stringify(pluginEntry, null, 2));
  } catch (error) {
    console.error(`ERROR: Failed to write marketplace.json: ${error.message}`);
    process.exit(1);
  }
}

const params = parseArgs();
updateMarketplace(params);
