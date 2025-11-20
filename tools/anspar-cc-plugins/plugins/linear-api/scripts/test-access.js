#!/usr/bin/env node
/**
 * Test Linear Access Configuration
 *
 * Diagnoses which Linear access method is available and provides
 * troubleshooting information.
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00053 (Development Environment and Tooling Setup)
 *
 * Supporting: CUR-390 - Linear MCP integration
 *
 * Usage:
 *   node scripts/test-access.js
 *   node scripts/test-access.js --verbose
 */

const config = require('../lib/config');
const accessDetector = require('../lib/access-detector');

async function main() {
  const verbose = process.argv.includes('--verbose');

  console.log('');
  console.log('╔═══════════════════════════════════════════════════════════════╗');
  console.log('║  Linear Access Configuration Test                             ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝');
  console.log('');

  // Step 1: Check access method
  console.log('🔍 Detecting Linear access method...');
  console.log('');

  const accessMethod = await accessDetector.detect();

  if (!accessMethod) {
    console.log('❌ No Linear access method available!');
    console.log('');
    console.log('You need either:');
    console.log('  1. Linear MCP connected in Claude Code (run: /mcp)');
    console.log('  2. LINEAR_API_TOKEN environment variable set');
    console.log('');
    console.log('For detailed setup instructions, see:');
    console.log('  tools/anspar-cc-plugins/plugins/linear-api/README.md');
    console.log('');
    process.exit(1);
  }

  // Step 2: Display access method
  if (accessMethod === 'mcp') {
    console.log('✅ LINEAR MCP DETECTED');
    console.log('');
    console.log('Access Method: Model Context Protocol (MCP)');
    console.log('Authentication: OAuth via Claude Code');
    console.log('Best for: Claude Code web (claude.ai/code)');
    console.log('');
    console.log('📋 MCP Configuration:');

    const detector = accessDetector.getDiagnostics();
    console.log(`   Config paths checked:`);
    for (const configPath of detector.mcpConfigPaths) {
      const exists = require('fs').existsSync(configPath);
      console.log(`     ${exists ? '✓' : '✗'} ${configPath}`);
    }
    console.log('');

    console.log('ℹ️  When using MCP mode, scripts will provide instructions');
    console.log('   for Claude Code to execute via its MCP connection.');
    console.log('');

  } else if (accessMethod === 'api') {
    console.log('✅ LINEAR API TOKEN DETECTED');
    console.log('');
    console.log('Access Method: Direct API (GraphQL)');
    console.log('Authentication: API Token');
    console.log('Best for: Claude Code CLI, automation, CI/CD');
    console.log('');
    console.log('📋 API Configuration:');
    console.log(`   Token: ${process.env.LINEAR_API_TOKEN ? '(set)' : '(not set)'}`);
    console.log(`   Team ID: ${config.getTeamId(false) || '(will auto-discover)'}`);
    console.log(`   Endpoint: ${config.getApiEndpoint()}`);
    console.log('');
  }

  // Step 3: Show configuration diagnostics
  if (verbose) {
    console.log('');
    console.log('🔧 DETAILED DIAGNOSTICS');
    console.log('');

    const diagnostics = config.getDiagnostics();

    console.log('Configuration:');
    console.log(`  Has Token: ${diagnostics.configuration.hasToken}`);
    console.log(`  Has Team ID: ${diagnostics.configuration.hasTeamId}`);
    console.log(`  API Endpoint: ${diagnostics.configuration.apiEndpoint}`);
    console.log('');

    console.log('Environment:');
    for (const [key, value] of Object.entries(diagnostics.environment)) {
      console.log(`  ${key}: ${value}`);
    }
    console.log('');

    console.log('Config Sources:');
    for (const [key, value] of Object.entries(diagnostics.configSources)) {
      console.log(`  ${key}: ${value}`);
    }
    console.log('');

    // Access detector diagnostics
    const accessDiag = accessDetector.getDiagnostics();
    console.log('Access Detector:');
    console.log(`  Cached Method: ${accessDiag.cachedMethod || 'none'}`);
    console.log(`  Last Check: ${accessDiag.lastCheck || 'never'}`);
    console.log(`  Cache Valid: ${accessDiag.cacheValid}`);
    console.log(`  API Token Available: ${accessDiag.apiTokenAvailable}`);
    console.log('');
  }

  // Step 4: Show next steps
  console.log('🎯 NEXT STEPS');
  console.log('');

  if (accessMethod === 'mcp') {
    console.log('You can now use Linear operations in Claude Code:');
    console.log('  - Ask Claude to create, fetch, or update Linear tickets');
    console.log('  - Claude will use its MCP connection automatically');
    console.log('');
    console.log('Example: "Please fetch Linear ticket CUR-390"');
    console.log('');
  } else if (accessMethod === 'api') {
    console.log('You can now use Linear operations via scripts:');
    console.log('  node scripts/fetch-tickets.js CUR-390');
    console.log('  node scripts/create-ticket.js --title="Test ticket"');
    console.log('  node scripts/search-tickets.js --query="bug"');
    console.log('');
    console.log('See README.md for full list of available scripts.');
    console.log('');
  }

  // Step 5: Test actual connectivity (if API mode)
  if (accessMethod === 'api' && !process.argv.includes('--skip-test')) {
    console.log('🧪 Testing connectivity...');
    console.log('');

    try {
      const graphqlClient = require('../lib/graphql-client');

      // Simple query to test connectivity
      const query = `
        query {
          viewer {
            id
            name
            email
          }
        }
      `;

      const result = await graphqlClient.execute(query);

      if (result && result.viewer) {
        console.log('✅ API Connection Successful!');
        console.log(`   Authenticated as: ${result.viewer.name} (${result.viewer.email})`);
        console.log('');
      }
    } catch (error) {
      console.log('❌ API Connection Failed');
      console.log(`   Error: ${error.message}`);
      console.log('');
      console.log('Please check:');
      console.log('  - Your LINEAR_API_TOKEN is valid');
      console.log('  - You have network connectivity');
      console.log('  - The Linear API is accessible');
      console.log('');
      process.exit(1);
    }
  }

  console.log('✨ Configuration test complete!');
  console.log('');
}

// Run
main().catch(error => {
  console.error('');
  console.error('❌ Test failed:', error.message);
  console.error('');
  if (process.env.DEBUG) {
    console.error(error.stack);
    console.error('');
  }
  process.exit(1);
});
