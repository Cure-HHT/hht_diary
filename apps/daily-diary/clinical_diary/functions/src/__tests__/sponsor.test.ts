// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

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

// Mock the index to provide runtimeOpts
jest.mock("../index", () => ({
  runtimeOpts: {
    timeoutSeconds: 60,
    memory: "256MB",
  },
}));

// Now import the function
import {sponsorConfig} from "../sponsor";

interface MockRequestOptions {
  method?: string;
  query?: Record<string, string | undefined>;
}

interface MockResponseType {
  status: jest.Mock;
  json: jest.Mock;
  _statusCode: number;
  _body: unknown;
  promise: Promise<void>;
}

/**
 * Creates a mock Express request object for testing.
 * @param {MockRequestOptions} options - Request configuration options
 * @return {object} Mock request with method and query
 */
function createMockRequest(options: MockRequestOptions): {
  method: string;
  query: Record<string, string | undefined>;
} {
  return {
    method: options.method || "GET",
    query: options.query || {},
  };
}

/**
 * Creates a mock Express response object for testing.
 * @return {MockResponseType} Mock response with status, json, and promise
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

describe("SponsorConfig Function", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("HTTP Method Validation", () => {
    it("rejects non-GET requests with 405", async () => {
      const req = createMockRequest({method: "POST"});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(405);
      expect(res._body).toEqual({error: "Method not allowed"});
    });

    it("rejects PUT requests with 405", async () => {
      const req = createMockRequest({method: "PUT"});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(405);
      expect(res._body).toEqual({error: "Method not allowed"});
    });

    it("rejects DELETE requests with 405", async () => {
      const req = createMockRequest({method: "DELETE"});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(405);
      expect(res._body).toEqual({error: "Method not allowed"});
    });
  });

  describe("Parameter Validation", () => {
    it("rejects missing sponsorId with 400", async () => {
      const req = createMockRequest({method: "GET", query: {}});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(400);
      expect(res._body).toEqual({error: "sponsorId parameter is required"});
    });

    it("rejects empty sponsorId with 400", async () => {
      const req = createMockRequest({method: "GET", query: {sponsorId: ""}});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(400);
      expect(res._body).toEqual({error: "sponsorId parameter is required"});
    });

    it("rejects whitespace-only sponsorId with 400", async () => {
      const req = createMockRequest({method: "GET", query: {sponsorId: "   "}});
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(400);
      expect(res._body).toEqual({error: "sponsorId parameter is required"});
    });

    it("handles undefined sponsorId parameter", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: undefined},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(400);
      expect(res._body).toEqual({error: "sponsorId parameter is required"});
    });
  });

  describe("Known Sponsor: curehht", () => {
    it("returns default flags for curehht", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect(res._body).toEqual({
        sponsorId: "curehht",
        flags: {
          useReviewScreen: false,
          useAnimations: true,
          requireOldEntryJustification: false,
          enableShortDurationConfirmation: false,
          enableLongDurationConfirmation: false,
          longDurationThresholdMinutes: 60,
          availableFonts: ["Roboto", "OpenDyslexic", "AtkinsonHyperlegible"],
        },
        isDefault: false,
      });
    });

    it("handles curehht with uppercase letters", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "CureHHT"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect((res._body as {sponsorId: string}).sponsorId).toBe("curehht");
      expect((res._body as {isDefault: boolean}).isDefault).toBe(false);
    });

    it("handles curehht with mixed case and whitespace", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "  CureHHT  "},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect((res._body as {sponsorId: string}).sponsorId).toBe("curehht");
      expect((res._body as {isDefault: boolean}).isDefault).toBe(false);
    });
  });

  describe("Known Sponsor: callisto", () => {
    it("returns all validations enabled for callisto", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "callisto"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect(res._body).toEqual({
        sponsorId: "callisto",
        flags: {
          useReviewScreen: false,
          useAnimations: true,
          requireOldEntryJustification: true,
          enableShortDurationConfirmation: true,
          enableLongDurationConfirmation: true,
          longDurationThresholdMinutes: 60,
          availableFonts: ["Roboto", "OpenDyslexic", "AtkinsonHyperlegible"],
        },
        isDefault: false,
      });
    });

    it("handles callisto with uppercase letters", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "CALLISTO"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect((res._body as {sponsorId: string}).sponsorId).toBe("callisto");
      expect((res._body as {isDefault: boolean}).isDefault).toBe(false);
    });
  });

  describe("Unknown Sponsor Handling", () => {
    it("returns default flags for unknown sponsor", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "unknownsponsor"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect(res._body).toEqual({
        sponsorId: "unknownsponsor",
        flags: {
          useReviewScreen: false,
          useAnimations: true,
          requireOldEntryJustification: false,
          enableShortDurationConfirmation: false,
          enableLongDurationConfirmation: false,
          longDurationThresholdMinutes: 60,
          availableFonts: ["Roboto", "OpenDyslexic", "AtkinsonHyperlegible"],
        },
        isDefault: true,
      });
    });

    it("preserves unknown sponsor ID casing in response", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "UnKnOwN"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      // Response sponsorId should be lowercased and trimmed
      expect((res._body as {sponsorId: string}).sponsorId).toBe("unknown");
      expect((res._body as {isDefault: boolean}).isDefault).toBe(true);
    });

    it("handles numeric-looking sponsor ID", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "12345"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect((res._body as {sponsorId: string}).sponsorId).toBe("12345");
      expect((res._body as {isDefault: boolean}).isDefault).toBe(true);
    });

    it("handles special characters in unknown sponsor ID", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "sponsor-test_123"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._statusCode).toBe(200);
      expect((res._body as {sponsorId: string}).sponsorId).toBe(
        "sponsor-test_123"
      );
      expect((res._body as {isDefault: boolean}).isDefault).toBe(true);
    });
  });

  describe("Flag Value Verification", () => {
    it("curehht has all validation flags disabled", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      const flags = (res._body as {flags: Record<string, unknown>}).flags;
      expect(flags.requireOldEntryJustification).toBe(false);
      expect(flags.enableShortDurationConfirmation).toBe(false);
      expect(flags.enableLongDurationConfirmation).toBe(false);
    });

    it("callisto has all validation flags enabled", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "callisto"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      const flags = (res._body as {flags: Record<string, unknown>}).flags;
      expect(flags.requireOldEntryJustification).toBe(true);
      expect(flags.enableShortDurationConfirmation).toBe(true);
      expect(flags.enableLongDurationConfirmation).toBe(true);
    });

    it("both sponsors have useAnimations enabled", async () => {
      const reqCurehht = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const resCurehht = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(
        reqCurehht,
        resCurehht
      );
      await resCurehht.promise;

      const reqCallisto = createMockRequest({
        method: "GET",
        query: {sponsorId: "callisto"},
      });
      const resCallisto = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(
        reqCallisto,
        resCallisto
      );
      await resCallisto.promise;

      const flagsCurehht = (
        resCurehht._body as {flags: Record<string, unknown>}
      ).flags;
      const flagsCallisto = (
        resCallisto._body as {flags: Record<string, unknown>}
      ).flags;

      expect(flagsCurehht.useAnimations).toBe(true);
      expect(flagsCallisto.useAnimations).toBe(true);
    });

    it("both sponsors have useReviewScreen disabled", async () => {
      const reqCurehht = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const resCurehht = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(
        reqCurehht,
        resCurehht
      );
      await resCurehht.promise;

      const reqCallisto = createMockRequest({
        method: "GET",
        query: {sponsorId: "callisto"},
      });
      const resCallisto = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(
        reqCallisto,
        resCallisto
      );
      await resCallisto.promise;

      const flagsCurehht = (
        resCurehht._body as {flags: Record<string, unknown>}
      ).flags;
      const flagsCallisto = (
        resCallisto._body as {flags: Record<string, unknown>}
      ).flags;

      expect(flagsCurehht.useReviewScreen).toBe(false);
      expect(flagsCallisto.useReviewScreen).toBe(false);
    });

    it("longDurationThresholdMinutes is 60 for all sponsors", async () => {
      const sponsors = ["curehht", "callisto", "unknown"];

      for (const sponsorId of sponsors) {
        const req = createMockRequest({
          method: "GET",
          query: {sponsorId},
        });
        const res = createMockResponse();

        (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
        await res.promise;

        const flags = (res._body as {flags: Record<string, unknown>}).flags;
        expect(flags.longDurationThresholdMinutes).toBe(60);
      }
    });
  });

  describe("Response Structure", () => {
    it("response contains all required fields", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      expect(res._body).toHaveProperty("sponsorId");
      expect(res._body).toHaveProperty("flags");
      expect(res._body).toHaveProperty("isDefault");
    });

    it("flags object contains all required properties", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      const flags = (res._body as {flags: Record<string, unknown>}).flags;
      expect(flags).toHaveProperty("useReviewScreen");
      expect(flags).toHaveProperty("useAnimations");
      expect(flags).toHaveProperty("requireOldEntryJustification");
      expect(flags).toHaveProperty("enableShortDurationConfirmation");
      expect(flags).toHaveProperty("enableLongDurationConfirmation");
      expect(flags).toHaveProperty("longDurationThresholdMinutes");
      expect(flags).toHaveProperty("availableFonts");
    });

    it("flag values have correct types", async () => {
      const req = createMockRequest({
        method: "GET",
        query: {sponsorId: "curehht"},
      });
      const res = createMockResponse();

      (sponsorConfig as (req: unknown, res: unknown) => void)(req, res);
      await res.promise;

      const flags = (res._body as {flags: Record<string, unknown>}).flags;
      expect(typeof flags.useReviewScreen).toBe("boolean");
      expect(typeof flags.useAnimations).toBe("boolean");
      expect(typeof flags.requireOldEntryJustification).toBe("boolean");
      expect(typeof flags.enableShortDurationConfirmation).toBe("boolean");
      expect(typeof flags.enableLongDurationConfirmation).toBe("boolean");
      expect(typeof flags.longDurationThresholdMinutes).toBe("number");
      expect(Array.isArray(flags.availableFonts)).toBe(true);
    });
  });
});
