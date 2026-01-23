#!/usr/bin/env node
// =====================================================
// Seed GCP Identity Platform with Dev Admin Users
// =====================================================
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//
// Creates dev admin users in GCP Identity Platform for local
// development with --dev mode (real auth, local backend).
//
// Usage:
//   # Ensure you're authenticated
//   gcloud auth application-default login
//
//   # Run with required arguments
//   node seed_identity_users.js \
//     --project=myproject \
//     --env=dev \
//     --password=secretpass \
//     --users=alice@example.com,bob@example.com \
//     --user-names="Alice Smith,Bob Jones"
//
// Prerequisites:
//   npm install firebase-admin
//
// =====================================================

const admin = require('firebase-admin');

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {
    project: null,
    env: null,
    password: null,
    users: null,
    userNames: null,
  };

  for (const arg of args) {
    if (arg.startsWith('--project=')) {
      parsed.project = arg.split('=')[1];
    } else if (arg.startsWith('--env=')) {
      parsed.env = arg.split('=')[1];
    } else if (arg.startsWith('--password=')) {
      parsed.password = arg.split('=')[1];
    } else if (arg.startsWith('--users=')) {
      parsed.users = arg.split('=')[1].split(',').map(s => s.trim());
    } else if (arg.startsWith('--user-names=')) {
      parsed.userNames = arg.split('=')[1].split(',').map(s => s.trim());
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    }
  }

  return parsed;
}

function printUsage() {
  console.log(`
Usage: node seed_identity_users.js [OPTIONS]

Required arguments:
  --project=NAME       GCP project name (without environment suffix)
  --env=ENV            Environment (dev, qa, uat, prod)
  --password=PASS      Password for all created users
  --users=EMAILS       Comma-separated list of user emails
  --user-names=NAMES   Comma-separated list of display names (must match --users count)

Optional arguments:
  --help, -h           Show this help message

Example:
  node seed_identity_users.js \\
    --project=sponsor-portal \\
    --env=dev \\
    --password=mydevpass \\
    --users=alice@example.com,bob@example.com \\
    --user-names="Alice Smith,Bob Jones"

  This will create users in project: sponsor-portal-dev

Notes:
  - Requires gcloud auth: gcloud auth application-default login
  - Requires npm install firebase-admin
  - Existing users will have their password updated to match --password
  - Email verification is set to true for all users
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

  if (!args.password) {
    errors.push('--password is required');
  }

  if (!args.users || args.users.length === 0) {
    errors.push('--users is required (comma-separated email list)');
  }

  if (!args.userNames || args.userNames.length === 0) {
    errors.push('--user-names is required (comma-separated name list)');
  }

  if (args.users && args.userNames && args.users.length !== args.userNames.length) {
    errors.push(`--users has ${args.users.length} entries but --user-names has ${args.userNames.length} entries (must match)`);
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

async function createOrUpdateUser(email, displayName, password) {
  try {
    // Check if user exists
    const existing = await admin.auth().getUserByEmail(email).catch(() => null);

    if (existing) {
      // Update existing user's password and display name to ensure they match
      await admin.auth().updateUser(existing.uid, {
        password: password,
        displayName: displayName,
        emailVerified: true,
      });
      console.log(`  [UPDATED] ${email} (uid: ${existing.uid})`);
      return { status: 'updated', uid: existing.uid };
    }

    // Create new user
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
      emailVerified: true, // Skip email verification for dev
    });

    console.log(`  [CREATED] ${email} (uid: ${userRecord.uid})`);
    return { status: 'created', uid: userRecord.uid };

  } catch (err) {
    console.error(`  [ERROR] ${email}: ${err.message}`);
    return { status: 'error', error: err.message };
  }
}

async function seedUsers() {
  const args = parseArgs();
  validateArgs(args);

  const projectId = `${args.project}-${args.env}`;

  console.log('\n========================================');
  console.log('  Seeding GCP Identity Platform Users');
  console.log('========================================\n');
  console.log(`Project: ${projectId}`);
  console.log(`Users to create: ${args.users.length}\n`);

  const initialized = await initializeAdmin(projectId);
  if (!initialized) {
    process.exit(1);
  }

  console.log('\nCreating users...\n');

  const results = {
    created: 0,
    updated: 0,
    errors: 0,
  };

  for (let i = 0; i < args.users.length; i++) {
    const email = args.users[i];
    const displayName = args.userNames[i];
    const result = await createOrUpdateUser(email, displayName, args.password);
    results[result.status === 'error' ? 'errors' : result.status]++;
  }

  console.log('\n========================================');
  console.log('  Summary');
  console.log('========================================');
  console.log(`  Created: ${results.created}`);
  console.log(`  Updated: ${results.updated}`);
  console.log(`  Errors: ${results.errors}`);
  console.log('========================================\n');

  if (results.errors > 0) {
    console.log('Some users failed to create. Check the errors above.\n');
    process.exit(1);
  }

  console.log('All users ready. You can now run:');
  console.log('  ./tool/run_local.sh --dev\n');

  process.exit(0);
}

// Run
seedUsers().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
