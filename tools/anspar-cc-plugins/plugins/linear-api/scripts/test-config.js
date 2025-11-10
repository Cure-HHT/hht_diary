#!/usr/bin/env node
/**
 * Test script to verify Linear plugin configuration
 * This demonstrates the improved config handling
 */

const config = require('../lib/config');

async function testConfig() {
    console.log('🔍 Testing Linear Plugin Configuration');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');

    // Check for token
    const token = config.getToken(false);
    if (token) {
        console.log('✅ API Token: Found');
        console.log(`   Source: ${token.startsWith('lin_api_') ? 'Valid format' : 'Invalid format'}`);
    } else {
        console.log('❌ API Token: Not found');
        console.log('   Run with --token=YOUR_TOKEN or see setup instructions');
    }

    // Check for team ID
    let teamId = config.getTeamId(false);
    if (teamId) {
        console.log('✅ Team ID: ' + teamId);
    } else {
        console.log('⚠️  Team ID: Not set, attempting auto-discovery...');
        if (token) {
            teamId = await config.discoverTeamId();
            if (teamId) {
                console.log('✅ Team ID discovered: ' + teamId);
            }
        }
    }

    // Show paths
    console.log('');
    console.log('📁 Plugin Paths:');
    const paths = config.getConfig().paths;
    console.log(`   Plugin Root: ${paths.pluginRoot}`);
    console.log(`   Project Root: ${paths.projectRoot}`);
    console.log(`   Scripts: ${paths.scripts}`);
    console.log(`   Cache: ${paths.cache}`);

    // Show API endpoint
    console.log('');
    console.log('🌐 API Endpoint: ' + config.getApiEndpoint());

    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (token && teamId) {
        console.log('✅ Configuration is complete!');
        return 0;
    } else {
        console.log('⚠️  Configuration is incomplete');
        console.log('');
        console.log('To complete setup:');
        if (!token) {
            console.log('1. Get your Linear API token from: https://linear.app/settings/api');
            console.log('2. Save it using one of the methods shown above');
        }
        if (!teamId) {
            console.log('3. Team ID will be auto-discovered once token is set');
        }
        return 1;
    }
}

// Run test
testConfig().then(process.exit).catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});