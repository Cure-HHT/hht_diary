// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

/**
 * Jest setup file for Firebase Functions INTEGRATION tests
 * Uses real project ID for emulator testing
 */

// For integration tests, use the real project ID (must match firebase.json)
process.env.GCLOUD_PROJECT = "hht-diary-mvp";

// No JWT secret needed for integration tests - we're testing HTTP endpoints
// process.env.JWT_SECRET is not set

// Increase timeout for Firebase operations and emulator communication
jest.setTimeout(30000);
