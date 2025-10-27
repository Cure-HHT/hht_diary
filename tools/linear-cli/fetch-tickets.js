#!/usr/bin/env node
/**
 * Linear CLI tool for fetching and analyzing tickets
 *
 * IMPLEMENTS REQUIREMENTS:
 *   (Supporting tool for project management - no specific REQ-* yet)
 *
 * Usage:
 *   node fetch-tickets.js [options]
 *
 * Options:
 *   --token=<token>     Linear API token (or set LINEAR_API_TOKEN env var)
 *   --format=json       Output format (json or summary, default: summary)
 *   --status=all        Filter by status (all, backlog, active, blocked, done)
 */

const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// GraphQL query to fetch all assigned issues
const GET_ALL_ASSIGNED_ISSUES = `
  query GetAllAssignedIssues {
    viewer {
      id
      name
      email
      assignedIssues(
        orderBy: updatedAt
        first: 100
      ) {
        nodes {
          id
          identifier
          title
          description
          url
          priority
          priorityLabel
          createdAt
          updatedAt
          dueDate
          state {
            name
            type
          }
          project {
            name
            id
          }
          cycle {
            name
            number
          }
          labels {
            nodes {
              name
              color
            }
          }
          parent {
            identifier
            title
          }
          children {
            nodes {
              identifier
              title
              state {
                name
              }
            }
          }
          assignee {
            name
          }
          comments(first: 10) {
            nodes {
              id
              body
              createdAt
            }
          }
        }
      }
    }
  }
`;

/**
 * Execute GraphQL query against Linear API
 */
async function executeQuery(apiToken, query, variables = {}) {
    const response = await fetch(LINEAR_API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': apiToken,
        },
        body: JSON.stringify({ query, variables }),
    });

    if (!response.ok) {
        throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();

    if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors, null, 2)}`);
    }

    return result.data;
}

/**
 * Extract requirement IDs from text (description or comments)
 */
function extractRequirements(text) {
    if (!text) return [];
    const reqPattern = /REQ-[pod]\d{5}/gi;
    const matches = text.match(reqPattern) || [];
    return [...new Set(matches.map(req => req.toUpperCase()))];
}

/**
 * Analyze and categorize issues
 */
function analyzeIssues(issues) {
    const categories = {
        backlog: [],
        todo: [],
        inProgress: [],
        inReview: [],
        blocked: [],
        done: [],
        other: []
    };

    const stats = {
        total: issues.length,
        withRequirements: 0,
        overdue: 0,
        highPriority: 0,
        hasChildren: 0,
        hasParent: 0,
    };

    const today = new Date();

    for (const issue of issues) {
        // Extract requirements from description and comments
        const requirements = extractRequirements(issue.description);
        issue.comments.nodes.forEach(comment => {
            requirements.push(...extractRequirements(comment.body));
        });
        issue.requirements = [...new Set(requirements)];

        if (issue.requirements.length > 0) {
            stats.withRequirements++;
        }

        // Check if overdue
        if (issue.dueDate && new Date(issue.dueDate) < today && issue.state.type !== 'completed') {
            stats.overdue++;
            issue.isOverdue = true;
        }

        // Check priority
        if (issue.priority <= 2) { // Priority 1 (Urgent) or 2 (High)
            stats.highPriority++;
            issue.isHighPriority = true;
        }

        // Check for children/parent
        if (issue.children.nodes.length > 0) {
            stats.hasChildren++;
        }
        if (issue.parent) {
            stats.hasParent++;
        }

        // Categorize by state
        const stateName = issue.state.name.toLowerCase();
        const stateType = issue.state.type;

        if (stateType === 'backlog') {
            categories.backlog.push(issue);
        } else if (stateType === 'started' || stateName.includes('progress')) {
            categories.inProgress.push(issue);
        } else if (stateName.includes('review')) {
            categories.inReview.push(issue);
        } else if (stateName.includes('block')) {
            categories.blocked.push(issue);
        } else if (stateType === 'completed' || stateType === 'canceled') {
            categories.done.push(issue);
        } else if (stateType === 'unstarted' || stateName.includes('todo')) {
            categories.todo.push(issue);
        } else {
            categories.other.push(issue);
        }
    }

    return { categories, stats };
}

/**
 * Print summary format
 */
function printSummary(viewer, analysis) {
    const { categories, stats } = analysis;

    console.log('='.repeat(80));
    console.log(`LINEAR TICKETS SUMMARY - ${viewer.name} (${viewer.email})`);
    console.log('='.repeat(80));
    console.log();

    // Overall stats
    console.log('STATISTICS:');
    console.log(`  Total Issues:          ${stats.total}`);
    console.log(`  With Requirements:     ${stats.withRequirements}`);
    console.log(`  High Priority:         ${stats.highPriority}`);
    console.log(`  Overdue:               ${stats.overdue}`);
    console.log(`  Parent Issues:         ${stats.hasChildren}`);
    console.log(`  Sub-tasks:             ${stats.hasParent}`);
    console.log();

    // Status breakdown
    console.log('STATUS BREAKDOWN:');
    console.log(`  Backlog:               ${categories.backlog.length}`);
    console.log(`  Todo:                  ${categories.todo.length}`);
    console.log(`  In Progress:           ${categories.inProgress.length}`);
    console.log(`  In Review:             ${categories.inReview.length}`);
    console.log(`  Blocked:               ${categories.blocked.length}`);
    console.log(`  Done:                  ${categories.done.length}`);
    if (categories.other.length > 0) {
        console.log(`  Other:                 ${categories.other.length}`);
    }
    console.log();

    // Detailed breakdowns
    function printIssueList(title, issues, limit = null) {
        if (issues.length === 0) return;

        console.log('-'.repeat(80));
        console.log(title);
        console.log('-'.repeat(80));

        const displayIssues = limit ? issues.slice(0, limit) : issues;

        for (const issue of displayIssues) {
            const flags = [];
            if (issue.isOverdue) flags.push('OVERDUE');
            if (issue.isHighPriority) flags.push('HIGH-PRI');
            if (issue.parent) flags.push(`Parent: ${issue.parent.identifier}`);
            if (issue.children.nodes.length > 0) flags.push(`${issue.children.nodes.length} subtasks`);

            const flagStr = flags.length > 0 ? ` [${flags.join(', ')}]` : '';
            const priorityLabel = issue.priorityLabel ? `P${issue.priority} (${issue.priorityLabel})` : `P${issue.priority}`;
            const projectStr = issue.project ? ` | ${issue.project.name}` : '';

            console.log();
            console.log(`  ${issue.identifier}: ${issue.title}${flagStr}`);
            console.log(`    Priority: ${priorityLabel} | Status: ${issue.state.name}${projectStr}`);
            console.log(`    URL: ${issue.url}`);

            if (issue.requirements.length > 0) {
                console.log(`    Requirements: ${issue.requirements.join(', ')}`);
            }

            if (issue.labels.nodes.length > 0) {
                const labels = issue.labels.nodes.map(l => l.name).join(', ');
                console.log(`    Labels: ${labels}`);
            }

            if (issue.dueDate) {
                const dueDate = new Date(issue.dueDate).toISOString().split('T')[0];
                console.log(`    Due: ${dueDate}`);
            }
        }

        if (limit && issues.length > limit) {
            console.log();
            console.log(`  ... and ${issues.length - limit} more`);
        }

        console.log();
    }

    // Print active work
    printIssueList('IN PROGRESS', categories.inProgress);
    printIssueList('IN REVIEW', categories.inReview);
    printIssueList('BLOCKED', categories.blocked);

    // Print high priority todo items
    const highPriorityTodo = [...categories.backlog, ...categories.todo]
        .filter(i => i.isHighPriority)
        .sort((a, b) => a.priority - b.priority);

    if (highPriorityTodo.length > 0) {
        printIssueList('HIGH PRIORITY TODO/BACKLOG', highPriorityTodo, 10);
    }

    // Print overdue
    const overdueIssues = [...categories.backlog, ...categories.todo, ...categories.inProgress]
        .filter(i => i.isOverdue)
        .sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));

    if (overdueIssues.length > 0) {
        printIssueList('OVERDUE ITEMS', overdueIssues);
    }

    console.log('='.repeat(80));
    console.log('END OF SUMMARY');
    console.log('='.repeat(80));
}

/**
 * Main function
 */
async function main() {
    const args = process.argv.slice(2);

    // Parse arguments
    let apiToken = process.env.LINEAR_API_TOKEN;
    let format = 'summary';
    let statusFilter = 'all';

    for (const arg of args) {
        if (arg.startsWith('--token=')) {
            apiToken = arg.substring('--token='.length);
        } else if (arg.startsWith('--format=')) {
            format = arg.substring('--format='.length);
        } else if (arg.startsWith('--status=')) {
            statusFilter = arg.substring('--status='.length);
        } else if (arg === '--help' || arg === '-h') {
            console.log('Usage: node fetch-tickets.js [options]');
            console.log('');
            console.log('Options:');
            console.log('  --token=<token>     Linear API token (or set LINEAR_API_TOKEN env var)');
            console.log('  --format=json       Output format (json or summary, default: summary)');
            console.log('  --status=all        Filter by status (all, backlog, active, blocked, done)');
            console.log('');
            process.exit(0);
        }
    }

    if (!apiToken) {
        console.error('Error: Linear API token required');
        console.error('Set LINEAR_API_TOKEN environment variable or use --token=<token>');
        console.error('');
        console.error('Get your token from: https://linear.app/settings/api');
        process.exit(1);
    }

    try {
        console.error('Fetching tickets from Linear...');
        const data = await executeQuery(apiToken, GET_ALL_ASSIGNED_ISSUES);

        const issues = data.viewer.assignedIssues.nodes;
        const analysis = analyzeIssues(issues);

        if (format === 'json') {
            console.log(JSON.stringify({ viewer: data.viewer, analysis }, null, 2));
        } else {
            printSummary(data.viewer, analysis);
        }

    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

main();
