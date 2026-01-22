#!/usr/bin/env node
// =====================================================
// Cleanup GCP Identity Platform Users
// =====================================================
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//
// Deletes all Identity Platform users EXCEPT protected dev admins.
// Used before integration tests to ensure clean state.
//
// Usage:
//   # Ensure you're authenticated
//   gcloud auth application-default login
//
//   # Run with required arguments
//   node cleanup_identity_users.js \
//     --project=myproject \
//     --env=dev
//
//   # With additional protected emails
//   node cleanup_identity_users.js \
//     --project=myproject \
//     --env=dev \
//     --protected=extra@example.com,another@example.com
//
// Prerequisites:
//   npm install firebase-admin
//
// =====================================================

const admin = require('firebase-admin');

// PROTECTED - Never delete these dev admin users
const PROTECTED_EMAILS = [
  'mike.bushe@anspar.org',
  'michael@anspar.org',
  'tom@anspar.org',
  'urayoan@anspar.org',
];

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {
    project: null,
    env: null,
    additionalProtected: [],
    dryRun: false,
  };

  for (const arg of args) {
    if (arg.startsWith('--project=')) {
      parsed.project = arg.split('=')[1];
    } else if (arg.startsWith('--env=')) {
      parsed.env = arg.split('=')[1];
    } else if (arg.startsWith('--protected=')) {
      parsed.additionalProtected = arg.split('=')[1].split(',').map(s => s.trim());
    } else if (arg === '--dry-run') {
      parsed.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    }
  }

  return parsed;
}

function printUsage() {
  console.log(`
Usage: node cleanup_identity_users.js [OPTIONS]

Required arguments:
  --project=NAME       GCP project name (without environment suffix)
  --env=ENV            Environment (dev, qa, uat, prod)

Optional arguments:
  --protected=EMAILS   Additional comma-separated emails to protect
  --dry-run            Show what would be deleted without actually deleting
  --help, -h           Show this help message

Example:
  node cleanup_identity_users.js \\
    --project=callisto4 \\
    --env=dev

  This will delete all users in project: callisto4-dev
  EXCEPT the protected dev admin emails.

Protected Emails (never deleted):
${PROTECTED_EMAILS.map(e => `  - ${e}`).join('\n')}

Notes:
  - Requires gcloud auth: gcloud auth application-default login
  - Requires npm install firebase-admin
  - Uses pagination to handle large user lists
  - Protected emails are case-insensitive
`);
}

function validateArgs(args) {
  const errors = [];

  if (!args.project) {
    errors.push('--project is required');
  }

  if (!args.env) {
    errors.push('--env is required (dev, qa, uat, prod)');
  }

  if (errors.length > 0) {
    console.error('\nError: Missing or invalid arguments:\n');
    errors.forEach(err => console.error(`  - ${err}`));
    console.error('\nRun with --help for usage information.\n');
    process.exit(1);
  }

  return true;
}

async function initializeAdmin(projectId) {
  try {
    // Initialize with application default credentials
    // Requires: gcloud auth application-default login
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: projectId,
    });
    console.log(`Initialized Firebase Admin for project: ${projectId}`);
    return true;
  } catch (err) {
    console.error('Failed to initialize Firebase Admin:', err.message);
    console.error('\nMake sure you have run:');
    console.error('  gcloud auth application-default login');
    return false;
  }
}

function isProtected(email, allProtected) {
  if (!email) return false;
  const lowerEmail = email.toLowerCase();
  return allProtected.some(p => p.toLowerCase() === lowerEmail);
}

async function cleanupUsers(args) {
  const projectId = `${args.project}-${args.env}`;

  // Combine default and additional protected emails
  const allProtected = [...PROTECTED_EMAILS, ...args.additionalProtected];

  console.log('\n========================================');
  console.log('  Cleaning GCP Identity Platform Users');
  console.log('========================================\n');
  console.log(`Project: ${projectId}`);
  console.log(`Dry run: ${args.dryRun ? 'Yes (no deletions)' : 'No (will delete)'}`);
  console.log(`\nProtected emails (${allProtected.length}):`);
  allProtected.forEach(e => console.log(`  - ${e}`));
  console.log('');

  const initialized = await initializeAdmin(projectId);
  if (!initialized) {
    process.exit(1);
  }

  console.log('\nScanning users...\n');

  const results = {
    deleted: 0,
    protected: 0,
    errors: 0,
  };

  let nextPageToken;
  let totalScanned = 0;

  do {
    try {
      // List up to 1000 users per page
      const listResult = await admin.auth().listUsers(1000, nextPageToken);

      for (const user of listResult.users) {
        totalScanned++;
        const email = user.email || '(no email)';

        if (isProtected(user.email, allProtected)) {
          console.log(`  [PROTECTED] ${email} (uid: ${user.uid})`);
          results.protected++;
          continue;
        }

        if (args.dryRun) {
          console.log(`  [WOULD DELETE] ${email} (uid: ${user.uid})`);
          results.deleted++;
        } else {
          try {
            await admin.auth().deleteUser(user.uid);
            console.log(`  [DELETED] ${email} (uid: ${user.uid})`);
            results.deleted++;
          } catch (deleteErr) {
            console.error(`  [ERROR] Failed to delete ${email}: ${deleteErr.message}`);
            results.errors++;
          }
        }
      }

      nextPageToken = listResult.pageToken;
    } catch (listErr) {
      console.error(`Error listing users: ${listErr.message}`);
      process.exit(1);
    }
  } while (nextPageToken);

  console.log('\n========================================');
  console.log('  Summary');
  console.log('========================================');
  console.log(`  Total scanned: ${totalScanned}`);
  console.log(`  ${args.dryRun ? 'Would delete' : 'Deleted'}: ${results.deleted}`);
  console.log(`  Protected: ${results.protected}`);
  console.log(`  Errors: ${results.errors}`);
  console.log('========================================\n');

  if (results.errors > 0) {
    console.log('Some users failed to delete. Check the errors above.\n');
    process.exit(1);
  }

  if (args.dryRun) {
    console.log('Dry run complete. No users were actually deleted.\n');
    console.log('Run without --dry-run to perform actual deletion.\n');
  } else {
    console.log('Cleanup complete. Identity Platform is ready for testing.\n');
  }

  process.exit(0);
}

// Main
const args = parseArgs();
validateArgs(args);
cleanupUsers(args).catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
