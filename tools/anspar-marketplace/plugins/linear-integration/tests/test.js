#!/usr/bin/env node
// Plugin Test Runner

const fs = require('fs');
const path = require('path');

let testsPassed = 0;
let testsFailed = 0;

function runTest(name, testFn) {
    process.stdout.write(`Running: ${name}... `);
    try {
        if (testFn()) {
            console.log('\x1b[32mPASSED\x1b[0m');
            testsPassed++;
        } else {
            console.log('\x1b[31mFAILED\x1b[0m');
            testsFailed++;
        }
    } catch (error) {
        console.log('\x1b[31mFAILED\x1b[0m', error.message);
        testsFailed++;
    }
}

// Metadata Tests
console.log('=== Metadata Tests ===');
runTest('Plugin.json exists', () => {
    return fs.existsSync('.claude-plugin/plugin.json');
});

runTest('Valid plugin.json', () => {
    const content = fs.readFileSync('.claude-plugin/plugin.json', 'utf8');
    const data = JSON.parse(content);
    return data.name && data.version && data.description && data.author;
});

// Summary
console.log('\n=== Test Summary ===');
console.log(`Tests Passed: ${testsPassed}`);
console.log(`Tests Failed: ${testsFailed}`);

if (testsFailed === 0) {
    console.log('\x1b[32mAll tests passed!\x1b[0m');
    process.exit(0);
} else {
    console.log('\x1b[31mSome tests failed.\x1b[0m');
    process.exit(1);
}