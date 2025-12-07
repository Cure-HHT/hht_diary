// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import * as jwt from "jsonwebtoken";

// Mock firebase-admin before importing auth
const mockTimestampNow = jest.fn().mockReturnValue({seconds: 1234567890});
const mockSet = jest.fn().mockResolvedValue(undefined);
const mockUpdate = jest.fn().mockResolvedValue(undefined);
const mockGet = jest.fn();
const mockDoc = jest.fn();
const mockCollection = jest.fn();
const mockWhere = jest.fn();
const mockLimit = jest.fn();

jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: Object.assign(
    jest.fn(() => ({
      collection: mockCollection,
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
import {register, login, changePassword} from "../auth";

// Test JWT secret (matches setup.ts)
const TEST_SECRET = "test-secret-key-for-testing-only";

// Valid SHA-256 hash (64 hex characters)
const VALID_PASSWORD_HASH =
  "a".repeat(64);
const NEW_PASSWORD_HASH =
  "b".repeat(64);

interface MockRequestOptions {
  method?: string;
  body?: Record<string, unknown> | null;
  headers?: Record<string, string>;
}

interface MockResponseType {
  status: jest.Mock;
  json: jest.Mock;
  _statusCode: number;
  _body: unknown;
  promise: Promise<void>;
}

function createMockRequest(options: MockRequestOptions): {
  method: string;
  body: Record<string, unknown> | null | undefined;
  headers: Record<string, string | undefined>;
} {
  return {
    method: options.method || "POST",
    body: options.body === null ? null : (options.body || {}),
    headers: options.headers || {},
  };
}

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

function createTestToken(authCode: string, userId: string): string {
  return jwt.sign(
    {authCode, userId, iat: Math.floor(Date.now() / 1000)},
    TEST_SECRET,
    {expiresIn: "1h", issuer: "hht-diary-mvp"}
  );
}

describe("Register Function", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Setup mock chain for Firestore
    mockCollection.mockReturnValue({
      doc: mockDoc,
    });
    mockDoc.mockReturnValue({
      get: mockGet,
      set: mockSet,
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing username", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {passwordHash: VALID_PASSWORD_HASH, appUuid: "test-uuid"},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("Username");
  });

  it("rejects username that is too short", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "abc", passwordHash: VALID_PASSWORD_HASH, appUuid: "x"},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("at least 6");
  });

  it("rejects username with @ symbol", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {
        username: "user@test",
        passwordHash: VALID_PASSWORD_HASH,
        appUuid: "x",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("@ symbol");
  });

  it("rejects username with invalid characters", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {
        username: "user!name",
        passwordHash: VALID_PASSWORD_HASH,
        appUuid: "x",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain(
      "letters, numbers, and underscores"
    );
  });

  it("rejects invalid password hash length", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "validuser", passwordHash: "tooshort", appUuid: "x"},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("Password");
  });

  it("rejects invalid password hash format (non-hex)", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {
        username: "validuser",
        passwordHash: "z".repeat(64), // not valid hex
        appUuid: "x",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("Invalid password");
  });

  it("rejects missing appUuid", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "validuser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "App UUID is required"});
  });

  it("rejects already taken username", async () => {
    mockGet.mockResolvedValueOnce({exists: true});

    const req = createMockRequest({
      method: "POST",
      body: {
        username: "existinguser",
        passwordHash: VALID_PASSWORD_HASH,
        appUuid: "test-uuid",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(409);
    expect(res._body).toEqual({error: "Username is already taken"});
  });

  it("successfully registers a new user", async () => {
    mockGet.mockResolvedValueOnce({exists: false});

    const req = createMockRequest({
      method: "POST",
      body: {
        username: "newuser123",
        passwordHash: VALID_PASSWORD_HASH,
        appUuid: "test-uuid",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toHaveProperty("jwt");
    expect(res._body).toHaveProperty("userId");
    expect(res._body).toHaveProperty("username", "newuser123");
    expect(mockSet).toHaveBeenCalled();
  });

  it("normalizes username to lowercase", async () => {
    mockGet.mockResolvedValueOnce({exists: false});

    const req = createMockRequest({
      method: "POST",
      body: {
        username: "NewUser123",
        passwordHash: VALID_PASSWORD_HASH,
        appUuid: "test-uuid",
      },
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect((res._body as {username: string}).username).toBe("newuser123");
    expect(mockDoc).toHaveBeenCalledWith("newuser123");
  });

  it("handles request with empty body (defensive logging)", async () => {
    // Tests the "no body" path in logging - req.body ? Object.keys(req.body) : "no body"
    // Note: With empty object, Object.keys returns [] which is truthy, so we test empty fields
    const req = createMockRequest({
      method: "POST",
      body: {}, // Empty body - all fields undefined
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    // Should fail validation since username is missing
    expect(res._statusCode).toBe(400);
  });

  it("handles request with undefined passwordHash", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "validuser", appUuid: "test-uuid"},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("Password");
  });

  it("handles request with null passwordHash", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "validuser", passwordHash: null, appUuid: "test-uuid"},
    });
    const res = createMockResponse();

    (register as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
  });
});

describe("Login Function", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCollection.mockReturnValue({
      doc: mockDoc,
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing username", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Username is required"});
  });

  it("rejects non-string username", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: 12345, passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Username is required"});
  });

  it("rejects missing password", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser"},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Password is required"});
  });

  it("rejects non-string password", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser", passwordHash: 12345},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Password is required"});
  });

  it("rejects user not found", async () => {
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({exists: false}),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "nonexistent", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid username or password"});
  });

  it("rejects user with no data", async () => {
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({exists: true, data: () => null}),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid username or password"});
  });

  it("rejects wrong password", async () => {
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          passwordHash: "different" + "a".repeat(55),
          authCode: "test-auth",
          userId: "test-user",
        }),
      }),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid username or password"});
  });

  it("successfully logs in with correct credentials", async () => {
    const mockUserRef = {
      update: mockUpdate,
    };
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          passwordHash: VALID_PASSWORD_HASH,
          authCode: "test-auth-code",
          userId: "test-user-id",
        }),
        ref: mockUserRef,
      }),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toHaveProperty("jwt");
    expect(res._body).toHaveProperty("userId", "test-user-id");
    expect(res._body).toHaveProperty("username", "testuser");
    expect(mockUpdate).toHaveBeenCalled();
  });

  it("normalizes username to lowercase during login", async () => {
    const mockUserRef = {
      update: mockUpdate,
    };
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          passwordHash: VALID_PASSWORD_HASH,
          authCode: "test-auth-code",
          userId: "test-user-id",
        }),
        ref: mockUserRef,
      }),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "TestUser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(mockDoc).toHaveBeenCalledWith("testuser");
  });

  it("handles request with empty body (defensive logging)", async () => {
    const req = createMockRequest({
      method: "POST",
      body: {}, // Empty body - all fields undefined
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect(res._body).toEqual({error: "Username is required"});
  });

  it("handles login with stored hash being null/undefined", async () => {
    mockDoc.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          passwordHash: null, // null stored hash
          authCode: "test-auth",
          userId: "test-user",
        }),
      }),
    });

    const req = createMockRequest({
      method: "POST",
      body: {username: "testuser", passwordHash: VALID_PASSWORD_HASH},
    });
    const res = createMockResponse();

    (login as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid username or password"});
  });
});

describe("ChangePassword Function", () => {
  const testAuthCode = "test-auth-code-12345";
  const testUserId = "test-user-id-12345";
  let validToken: string;

  beforeEach(() => {
    jest.clearAllMocks();
    validToken = createTestToken(testAuthCode, testUserId);

    mockCollection.mockReturnValue({
      where: mockWhere,
    });
    mockWhere.mockReturnValue({
      limit: mockLimit,
    });
  });

  it("rejects non-POST requests", async () => {
    const req = createMockRequest({method: "GET"});
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(405);
    expect(res._body).toEqual({error: "Method not allowed"});
  });

  it("rejects missing authorization", async () => {
    const req = createMockRequest({method: "POST"});
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
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

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects non-Bearer authorization", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Basic ${validToken}`},
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects invalid new password hash", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {currentPasswordHash: VALID_PASSWORD_HASH, newPasswordHash: "short"},
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(400);
    expect((res._body as {error: string}).error).toContain("Password");
  });

  it("rejects when user not found", async () => {
    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({empty: true}),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "User not found"});
  });

  it("rejects when user data not found", async () => {
    const mockUserRef = {
      get: jest.fn().mockResolvedValue({data: () => null}),
      update: mockUpdate,
    };

    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        empty: false,
        docs: [{
          data: () => ({userId: testUserId}),
          ref: mockUserRef,
        }],
      }),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "User data not found"});
  });

  it("rejects wrong current password", async () => {
    const mockUserRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({passwordHash: "different" + "a".repeat(55)}),
      }),
      update: mockUpdate,
    };

    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        empty: false,
        docs: [{
          data: () => ({userId: testUserId}),
          ref: mockUserRef,
        }],
      }),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Current password is incorrect"});
  });

  it("successfully changes password", async () => {
    const mockUserRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({passwordHash: VALID_PASSWORD_HASH}),
      }),
      update: mockUpdate,
    };

    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        empty: false,
        docs: [{
          data: () => ({userId: testUserId}),
          ref: mockUserRef,
        }],
      }),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(200);
    expect(res._body).toEqual({success: true});
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({passwordHash: NEW_PASSWORD_HASH})
    );
  });

  it("rejects token with missing authCode", async () => {
    // Create token without authCode
    const tokenWithoutAuthCode = jwt.sign(
      {userId: testUserId, iat: Math.floor(Date.now() / 1000)},
      TEST_SECRET,
      {expiresIn: "1h", issuer: "hht-diary-mvp"}
    );

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${tokenWithoutAuthCode}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("rejects token with missing userId", async () => {
    // Create token without userId
    const tokenWithoutUserId = jwt.sign(
      {authCode: testAuthCode, iat: Math.floor(Date.now() / 1000)},
      TEST_SECRET,
      {expiresIn: "1h", issuer: "hht-diary-mvp"}
    );

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${tokenWithoutUserId}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Invalid or missing authorization"});
  });

  it("handles empty body (defensive logging)", async () => {
    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {}, // Empty body - all fields undefined
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    // Should fail on new password validation (empty body)
    expect(res._statusCode).toBe(400);
  });

  it("handles undefined currentPasswordHash", async () => {
    const mockUserRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({passwordHash: VALID_PASSWORD_HASH}),
      }),
      update: mockUpdate,
    };

    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        empty: false,
        docs: [{
          data: () => ({userId: testUserId}),
          ref: mockUserRef,
        }],
      }),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        // currentPasswordHash is undefined
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    // Should fail because current password doesn't match
    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Current password is incorrect"});
  });

  it("handles stored passwordHash being null", async () => {
    const mockUserRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({passwordHash: null}), // null stored password
      }),
      update: mockUpdate,
    };

    mockLimit.mockReturnValue({
      get: jest.fn().mockResolvedValue({
        empty: false,
        docs: [{
          data: () => ({userId: testUserId}),
          ref: mockUserRef,
        }],
      }),
    });

    const req = createMockRequest({
      method: "POST",
      headers: {authorization: `Bearer ${validToken}`},
      body: {
        currentPasswordHash: VALID_PASSWORD_HASH,
        newPasswordHash: NEW_PASSWORD_HASH,
      },
    });
    const res = createMockResponse();

    (changePassword as (req: unknown, res: unknown) => void)(req, res);
    await res.promise;

    expect(res._statusCode).toBe(401);
    expect(res._body).toEqual({error: "Current password is incorrect"});
  });
});
