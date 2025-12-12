// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Jest configuration for INTEGRATION tests only.
// Uses real project ID for Firebase emulator testing.

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.integration.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  // Use integration-specific setup that doesn't mock the project ID
  setupFilesAfterEnv: ['<rootDir>/src/__tests__/setup.integration.ts'],
  testTimeout: 30000,
  verbose: true,
};
