#!/usr/bin/env node

/**
 * Test Agent Validation
 * Run the enhanced validator on all agent files in anspar-marketplace
 */

const fs = require('fs');
const path = require('path');

// Import the fixer
const fixer = require('./orchestrators/agent-fixer');

// Find all agent files
const marketplacePath = path.join(__dirname, '../..');
console.log(`📂 Searching for agents in: ${marketplacePath}\n`);

const pluginDirs = fs.readdirSync(marketplacePath)
  .filter(name => {
    const fullPath = path.join(marketplacePath, name);
    try {
      return fs.statSync(fullPath).isDirectory() && name !== 'docs';
    } catch (err) {
      return false;
    }
  });

console.log('🧪 Testing Agent Validation on All Plugins\n');
console.log('='.repeat(60));
console.log('');

const results = [];
let totalAgents = 0;
let passedAgents = 0;
let failedAgents = 0;

// Test each plugin
for (const pluginName of pluginDirs) {
  const agentsDir = path.join(marketplacePath, pluginName, 'agents');

  if (!fs.existsSync(agentsDir)) {
    continue;
  }

  const agentFiles = fs.readdirSync(agentsDir)
    .filter(name => name.endsWith('.md'));

  for (const agentFile of agentFiles) {
    const agentPath = path.join(agentsDir, agentFile);
    totalAgents++;

    console.log(`📄 ${pluginName}/agents/${agentFile}`);
    console.log('-'.repeat(60));

    try {
      // Note: We need to access the validateAgentFile function
      // For now, we'll read the file and do basic validation
      const content = fs.readFileSync(agentPath, 'utf8');

      const result = validateAgent(content, agentPath);
      results.push({
        plugin: pluginName,
        agent: agentFile,
        ...result
      });

      // Display results
      if (result.errors.length > 0) {
        console.log('❌ ERRORS:');
        result.errors.forEach(err => console.log(`   - ${err}`));
        failedAgents++;
      } else {
        passedAgents++;
      }

      if (result.warnings.length > 0) {
        console.log('⚠️  WARNINGS:');
        result.warnings.forEach(warn => console.log(`   - ${warn}`));
      }

      if (result.suggestions.length > 0) {
        console.log('💡 SUGGESTIONS:');
        result.suggestions.forEach(sug => console.log(`   - ${sug}`));
      }

      if (result.metrics) {
        console.log('\n📊 METRICS:');
        console.log(`   Sections: ${result.metrics.sectionCount}`);
        console.log(`   Emphasis: ${result.metrics.emphasisCount}`);
        console.log(`   Identity: ${result.metrics.hasIdentity ? '✓' : '✗'}`);
        console.log(`   Operational: ${result.metrics.hasOperationalApproach ? '✓' : '✗'}`);
        console.log(`   Tools: ${result.metrics.hasAvailableTools ? '✓' : '✗'}`);
        console.log(`   Examples: ${result.metrics.hasExamples ? '✓' : '✗'}`);
      }

      // Generate fixed version if there are issues
      if (result.errors.length > 0 || result.warnings.length > 0) {
        console.log('\n🔧 GENERATING FIXED VERSION...');

        try {
          const fixResult = fixer.generateFixedAgent(content, result, {
            addMissingFrontmatter: true,
            addMissingSections: true,
            reduceEmphasis: result.metrics && result.metrics.emphasisCount > 20,
            fixHeadingHierarchy: true,
            addToolExamples: false
          });

          // Save fixed version
          const fixedPath = agentPath + '.fixed';
          fs.writeFileSync(fixedPath, fixResult.fixed, 'utf8');

          if (fixResult.changes.length > 0) {
            console.log('\n📝 CHANGES APPLIED:');
            fixResult.changes.forEach(change => {
              const icon = change.type === 'added' ? '➕' : change.type === 'modified' ? '🔧' : '➖';
              console.log(`   ${icon} ${change.item}: ${change.details}`);
            });

            console.log(`\n💾 Fixed version saved to:`);
            console.log(`   ${fixedPath}`);
            console.log(`\n   To apply: mv "${fixedPath}" "${agentPath}"`);
          } else {
            console.log('   No automated fixes available for these issues.');
          }
        } catch (fixError) {
          console.log(`   ⚠️  Could not generate fixes: ${fixError.message}`);
        }
      }

      if (result.errors.length === 0 && result.warnings.length === 0) {
        console.log('\n✅ PASS - No issues found');
      } else if (result.errors.length === 0) {
        console.log('\n✅ PASS - Minor warnings only');
      } else {
        console.log('\n❌ FAIL - Errors must be fixed');
      }

    } catch (error) {
      console.log(`❌ ERROR: ${error.message}`);
      failedAgents++;
      results.push({
        plugin: pluginName,
        agent: agentFile,
        errors: [error.message],
        warnings: [],
        suggestions: []
      });
    }

    console.log('');
  }
}

console.log('='.repeat(60));
console.log('\n📊 SUMMARY\n');
console.log(`Total agents tested: ${totalAgents}`);
console.log(`Passed: ${passedAgents} (${((passedAgents/totalAgents)*100).toFixed(1)}%)`);
console.log(`Failed: ${failedAgents} (${((failedAgents/totalAgents)*100).toFixed(1)}%)`);

console.log('\n🏆 LEADERBOARD\n');

// Sort results by quality (fewer errors + warnings = better)
const sortedResults = results.sort((a, b) => {
  const scoreA = (a.errors.length * 3) + (a.warnings.length * 1);
  const scoreB = (b.errors.length * 3) + (b.warnings.length * 1);
  return scoreA - scoreB;
});

sortedResults.slice(0, 5).forEach((result, index) => {
  const score = (result.errors.length * 3) + (result.warnings.length * 1);
  const grade = score === 0 ? 'A+' : score < 3 ? 'A' : score < 5 ? 'B' : score < 8 ? 'C' : 'D';
  console.log(`${index + 1}. ${result.plugin}/${result.agent} - Grade: ${grade} (${result.errors.length}E, ${result.warnings.length}W)`);
});

console.log('\n❌ NEEDS IMPROVEMENT\n');

sortedResults.slice(-5).reverse().forEach((result, index) => {
  const score = (result.errors.length * 3) + (result.warnings.length * 1);
  console.log(`${index + 1}. ${result.plugin}/${result.agent} - (${result.errors.length}E, ${result.warnings.length}W, ${result.suggestions.length}S)`);
  if (result.errors.length > 0) {
    result.errors.slice(0, 2).forEach(err => console.log(`      - ${err}`));
  }
});

console.log('\n' + '='.repeat(60));

/**
 * Validate agent content (inline implementation of the validator logic)
 */
function validateAgent(content, filePath) {
  const result = {
    errors: [],
    warnings: [],
    suggestions: [],
    metrics: {
      emphasisCount: 0,
      sectionCount: 0,
      hasIdentity: false,
      hasOperationalApproach: false,
      hasAvailableTools: false,
      hasExamples: false
    }
  };

  // 1. YAML Frontmatter Validation
  if (!content.startsWith('---\n')) {
    result.errors.push('Missing YAML frontmatter');
    return result;
  }

  const endIndex = content.indexOf('\n---\n', 4);
  if (endIndex === -1) {
    result.errors.push('Unclosed YAML frontmatter');
    return result;
  }

  const frontmatter = content.substring(4, endIndex);
  const body = content.substring(endIndex + 5);

  if (!frontmatter.includes('name:')) {
    result.errors.push('Missing "name:" field in frontmatter');
  }
  if (!frontmatter.includes('description:')) {
    result.errors.push('Missing "description:" field in frontmatter');
  }

  // 2. Section extraction
  const sections = extractSections(body);
  result.metrics.sectionCount = sections.length;

  if (sections.length === 0) {
    result.errors.push('Agent has no section headers');
    return result;
  }

  const sectionNames = sections.map(s => s.title.toLowerCase());

  // Check for required sections
  const identityPatterns = ['role', 'purpose', 'identity', 'overview', 'who you are'];
  result.metrics.hasIdentity = sectionNames.some(name =>
    identityPatterns.some(pattern => name.includes(pattern))
  );

  const operationalPatterns = ['capabilities', 'core capabilities', 'workflow', 'operational'];
  result.metrics.hasOperationalApproach = sectionNames.some(name =>
    operationalPatterns.some(pattern => name.includes(pattern))
  );

  const toolsPatterns = ['available tools', 'available skills', 'tools', 'skills'];
  result.metrics.hasAvailableTools = sectionNames.some(name =>
    toolsPatterns.some(pattern => name.includes(pattern))
  );

  const examplePatterns = ['example', 'usage'];
  result.metrics.hasExamples = sectionNames.some(name =>
    examplePatterns.some(pattern => name.includes(pattern))
  );

  // Report missing sections
  if (!result.metrics.hasIdentity) {
    result.warnings.push('Missing Identity section');
  }
  if (!result.metrics.hasOperationalApproach) {
    result.warnings.push('Missing Operational section');
  }
  if (!result.metrics.hasAvailableTools) {
    result.warnings.push('Missing Tools section');
  }
  if (!result.metrics.hasExamples) {
    result.suggestions.push('Consider adding Examples section');
  }

  // 3. Emphasis validation
  const emphasisMarkers = ['CRITICAL', 'IMPORTANT', 'MUST', 'NEVER', 'ALWAYS', 'MANDATORY', 'WARNING', 'REQUIRED'];
  result.metrics.emphasisCount = countEmphasisMarkers(body, emphasisMarkers);

  const wordCount = body.split(/\s+/).length;
  const emphasisRatio = result.metrics.emphasisCount / wordCount;

  if (result.metrics.emphasisCount === 0) {
    result.suggestions.push('Consider using emphasis markers for critical points');
  } else if (result.metrics.emphasisCount > 20) {
    result.warnings.push(`Too many emphasis markers (${result.metrics.emphasisCount}). Limit to 5-15.`);
  } else if (result.metrics.emphasisCount > 15) {
    result.suggestions.push(`High emphasis count (${result.metrics.emphasisCount})`);
  } else if (emphasisRatio > 0.05) {
    result.warnings.push(`Emphasis overuse (${(emphasisRatio * 100).toFixed(1)}%)`);
  }

  // 4. Content quality checks
  if (result.metrics.hasAvailableTools) {
    const toolsSection = sections.find(s =>
      ['available tools', 'available skills'].some(p => s.title.toLowerCase().includes(p))
    );

    if (toolsSection) {
      const hasInvocationExamples =
        toolsSection.content.includes('${CLAUDE_PLUGIN_ROOT}') ||
        toolsSection.content.includes('bash') ||
        toolsSection.content.includes('```') ||
        toolsSection.content.includes('node ') ||
        toolsSection.content.includes('python ');

      if (!hasInvocationExamples) {
        result.warnings.push('Tools section should show HOW to invoke');
      }
    }
  }

  const hasAutoInvoke = body.toLowerCase().includes('auto-invoke') ||
                        body.toLowerCase().includes('when to invoke') ||
                        body.toLowerCase().includes('when to use');
  if (!hasAutoInvoke) {
    result.suggestions.push('Consider adding auto-invocation triggers');
  }

  if (body.trim().length < 200) {
    result.warnings.push('Agent body too short (<200 chars)');
  }

  // 5. Structural checks
  const headingLevels = extractHeadingLevels(body);
  if (headingLevels.length > 0 && headingLevels[0] !== 1) {
    result.warnings.push('First heading should be level 1 (# Title)');
  }

  return result;
}

function extractSections(content) {
  const sections = [];
  const lines = content.split('\n');
  let currentSection = null;

  for (const line of lines) {
    const match = line.match(/^(#{1,6})\s+(.+)$/);
    if (match) {
      if (currentSection) {
        sections.push(currentSection);
      }
      currentSection = {
        title: match[2].trim(),
        level: match[1].length,
        content: ''
      };
    } else if (currentSection) {
      currentSection.content += line + '\n';
    }
  }

  if (currentSection) {
    sections.push(currentSection);
  }

  return sections;
}

function extractHeadingLevels(content) {
  const levels = [];
  const lines = content.split('\n');

  for (const line of lines) {
    const match = line.match(/^(#{1,6})\s+/);
    if (match) {
      levels.push(match[1].length);
    }
  }

  return levels;
}

function countEmphasisMarkers(content, markers) {
  let count = 0;
  for (const marker of markers) {
    const regex = new RegExp(marker, 'gi');
    const matches = content.match(regex);
    if (matches) {
      count += matches.length;
    }
  }
  return count;
}
