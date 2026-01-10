// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import * as jwt from "jsonwebtoken";

// Mock firebase-admin before importing index
const mockTimestampNow = jest.fn().mockReturnValue({seconds: 1234567890});
const mockSet = jest.fn().mockResolvedValue(undefined);
const mockUpdate = jest.fn().mockResolvedValue(undefined);
const mockGet = jest.fn();
const mockDoc = jest.fn();
const mockCollection = jest.fn();
const mockWhere = jest.fn();
const mockLimit = jest.fn();
const mockOrderBy = jest.fn();
const mockBatch = jest.fn();
const mockBatchSet = jest.fn();
const mockBatchCommit = jest.fn().mockResolvedValue(undefined);

jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: Object.assign(
    jest.fn(() => ({
      collection: mockCollection,
      batch: mockBatch,
    })),
    {
      Timestamp: {
        now: mockTimestampNow,
      },
    }
  ),
}));

// Mock CORS to pass through immediately
jest.mock("../cors", () => ({
  corsHandlerFnc: () => (
    _req: unknown,
    _res: unknown,
    next: () => Promise<void>
  ) => {
    // Call next and return its promise
    return next();
  },
}));

// Mock firebase-functions to return simple handler wrappers
jest.mock("firebase-functions/v1", () => ({
  runWith: () => ({
    region: () => ({
      https: {
        onRequest: (handler: (req: unknown, res: unknown) => void) => handler,
      },
    }),
  }),
}));

// Now import the functions
import {enroll, health, sync, getRecords} from "../index";

// Test JWT secret (matches setup.ts)
const TEST_SECRET = "test-secret-key-for-testing-only";

interface MockRequestOptions {
  method?: string;
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
}

interface MockResponseType {
  status: jest.Mock;
  json: jest.Mock;
  _statusCode: number;
  _body: unknown;
  promise: Promise<void>;
}

/**
 * Create a mock Express request object.
 * @param {MockRequestOptions} options - Request options
 * @return {object} Mock request object
 */
function createMockRequest(options: MockRequestOptions): {
  method: string;
  body: Record<string, unknown>;
  headers: Record<string, string | undefined>;
} {
  return {
    method: options.method || "POST",
    body: options.body || {},
    headers: options.headers || {},
  };
}

/**
 * Create a mock Express response object with promise-based json.
 * @return {MockResponseType} Mock response object
 */
function createMockResponse(): MockResponseType {
  // eslint-disable-next-line @typescript-eslint/no-empty-function
  let resolvePromise: () => void = () => {};
  const promise = new Promise<void>((resolve) => {
    resolvePromise = resolve;
  });

  const res: MockResponseType = {
    _statusCode: 200,
    _body: null as unknown,
    promise,
    status: jest.fn(),
    json: jest.fn(),
  };

  res.status.mockImplementation((code: number) => {
    res._statusCode = code;
    return res;
  });

  res.json.mockImplementation((body: unknown) => {
    res._body = body;
    resolvePromise();
    return res;
  });

  return res;
}

/**
 * Create a valid JWT token for testing.
 * @param {string} authCode - The auth code
 * @param {string} userId - The user ID
 * @return {string} JWT token
 */
function createTestToken(authCode: string, userId: string): string {
  return jwt.sign(
    {authCode, userId, iat: Math.floor(Date.now() / 1000)},
    TEST_SECRET,
    {expiresIn: "1h", issuer: "hht-diary-mvp"}
  );
}

describe("Health Function", () => {
  it("returns status ok with timestamp and region", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (health as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._body).toMatchObject({
      status: "ok",
      region: "europe-west1",
    });
    expect((res._body as {timestamp: string}).timestamp).toBeDefined();
  });
});

describe("Enroll Function", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Setup mock chain for Firestore
    mockCollection.mockReturnValue({
      where: mockWhere,
      doc: mockDoc,
    });
    mockWhere.mockReturnValue({
      limit: mockLimit,
    });
    mockLimit.mockReturnValue({
      get: mockGet,
    });
    mockDoc.mockReturnValue({
      set: mockSet,
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing enrollment code", async () => {
    const req = createMockRequest({method: "POST", body: {}});
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Enrollment code is required"});
  });

  it("rejects non-string enrollment code", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {code: 12345},
    });
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Enrollment code is required"});
  });

  it("rejects invalid enrollment code format", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {code: "INVALID"},
    });
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Invalid enrollment code"});
  });

  it("rejects already used enrollment code", async () => {
    mockGet.mockResolvedValueOnce({empty: false});

    const req = createMockRequest({
      method: "POST",
      body: {code: "CUREHHT1"},
    });
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(409);
    expect(res._body).toEqual({
      error: "This enrollment code has already been used",
    });
  });

  it("successfully enrolls with valid code", async () => {
    mockGet.mockResolvedValueOnce({empty: true});

    const req = createMockRequest({
      method: "POST",
      body: {code: "CUREHHT1"},
    });
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toHaveProperty("jwt");
    expect(res._body).toHaveProperty("userId");
    expect(mockSet).toHaveBeenCalled();
  });

  it("normalizes lowercase enrollment code", async () => {
    mockGet.mockResolvedValueOnce({empty: true});

    const req = createMockRequest({
      method: "POST",
      body: {code: "curehht5"},
    });
    const res = createMockResponse();

    (enroll as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(mockWhere).toHaveBeenCalledWith(
      "enrollmentCode",
      "==",
      "CUREHHT5"
    );
  });
});

describe("Sync Function", () => {
  const testAuthCode = "test-auth-code-12345";
  const testUserId = "test-user-id-12345";
  let validToken: string;

  beforeEach(() => {
    jest.clearAllMocks();
    validToken = createTestToken(testAuthCode, testUserId);

    // Setup mock chain for user lookup
    const mockUserRef = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({exists: false}),
        }),
      }),
      update: mockUpdate,
    };

    mockCollection.mockReturnValue({
      where: mockWhere,
    });
    mockWhere.mockReturnValue({
      limit: mockLimit,
    });
    mockLimit.mockReturnValue({
      get: mockGet,
    });

    // Mock batch operations
    mockBatch.mockReturnValue({
      set: mockBatchSet,
      commit: mockBatchCommit,
    });

    // Default: user exists
    mockGet.mockResolvedValue({
      empty: false,
      docs: [{
        data: () => ({userId: testUserId}),
        ref: mockUserRef,
      }],
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing authorization", async () => {
    const req = createMockRequest({method: "POST"});
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects invalid authorization token", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: "Bearer invalid-token"},
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects when user not found", async () => {
    mockGet.mockResolvedValueOnce({empty: true});

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {records: []},
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "User not found"});
  });

  it("rejects non-array records", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {records: "not-an-array"},
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Records must be an array"});
  });

  it("successfully syncs empty records array", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {records: []},
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toEqual({success: true});
  });

  it("syncs records with valid IDs", async () => {
    const mockRecordRef = {
      get: jest.fn().mockResolvedValue({exists: false}),
    };
    const mockUserRef = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue(mockRecordRef),
      }),
      update: mockUpdate,
    };

    mockGet.mockResolvedValue({
      empty: false,
      docs: [{
        data: () => ({userId: testUserId}),
        ref: mockUserRef,
      }],
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        records: [
          {id: "record-1", data: "test1"},
          {id: "record-2", data: "test2"},
        ],
      },
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toEqual({success: true});
    expect(mockBatchCommit).toHaveBeenCalled();
  });

  it("skips records without id", async () => {
    const mockRecordRef = {
      get: jest.fn().mockResolvedValue({exists: false}),
    };
    const mockUserRef = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue(mockRecordRef),
      }),
      update: mockUpdate,
    };

    mockGet.mockResolvedValue({
      empty: false,
      docs: [{
        data: () => ({userId: testUserId}),
        ref: mockUserRef,
      }],
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        records: [
          {data: "no-id-record"},
          {id: "valid-record", data: "test"},
        ],
      },
    });
    const res = createMockResponse();

    (sync as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toEqual({success: true});
  });
});

describe("GetRecords Function", () => {
  const testAuthCode = "test-auth-code-12345";
  const testUserId = "test-user-id-12345";
  let validToken: string;

  beforeEach(() => {
    jest.clearAllMocks();
    validToken = createTestToken(testAuthCode, testUserId);

    // Setup mock chain
    mockCollection.mockReturnValue({
      where: mockWhere,
    });
    mockWhere.mockReturnValue({
      limit: mockLimit,
    });
    mockLimit.mockReturnValue({
      get: mockGet,
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (getRecords as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing authorization", async () => {
    const req = createMockRequest({method: "POST"});
    const res = createMockResponse();

    (getRecords as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects when user not found", async () => {
    mockGet.mockResolvedValueOnce({empty: true});

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
    });
    const res = createMockResponse();

    (getRecords as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "User not found"});
  });

  it("returns empty records array when no records exist", async () => {
    const mockUserRef = {
      collection: jest.fn().mockReturnValue({
        orderBy: mockOrderBy,
      }),
    };
    mockOrderBy.mockReturnValue({
      get: jest.fn().mockResolvedValue({docs: []}),
    });

    mockGet.mockResolvedValue({
      empty: false,
      docs: [{
        data: () => ({userId: testUserId}),
        ref: mockUserRef,
      }],
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
    });
    const res = createMockResponse();

    (getRecords as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toEqual({records: []});
  });

  it("returns records with data", async () => {
    const mockRecords = [
      {id: "record-1", data: () => ({severity: "mild", date: "2024-01-01"})},
      {id: "record-2", data: () => ({severity: "severe", date: "2024-01-02"})},
    ];

    const mockUserRef = {
      collection: jest.fn().mockReturnValue({
        orderBy: mockOrderBy,
      }),
    };
    mockOrderBy.mockReturnValue({
      get: jest.fn().mockResolvedValue({docs: mockRecords}),
    });

    mockGet.mockResolvedValue({
      empty: false,
      docs: [{
        data: () => ({userId: testUserId}),
        ref: mockUserRef,
      }],
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
    });
    const res = createMockResponse();

    (getRecords as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect((res._body as {records: unknown[]}).records).toHaveLength(2);
    expect((res._body as {records: Array<{id: string}>}).records[0].id)
      .toBe("record-1");
  });
});
