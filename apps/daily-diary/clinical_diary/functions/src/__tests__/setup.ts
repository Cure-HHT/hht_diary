// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

/**
 * Jest setup file for Firebase Functions tests
 * Configures mocks and test environment
 */

// Set test environment variables
process.env.JWT_SECRET = "test-secret-key-for-testing-only";
process.env.GCLOUD_PROJECT = "test-project";
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "test-project",
  databaseURL: "https://test-project.firebaseio.com",
  storageBucket: "test-project.appspot.com",
});

// Mock console methods to reduce noise in tests (optional)
// Uncomment if you want cleaner test output
// global.console = {
//   ...console,
//   log: jest.fn(),
//   info: jest.fn(),
//   debug: jest.fn(),
// };

// Increase timeout for Firebase operations
jest.setTimeout(10000);
