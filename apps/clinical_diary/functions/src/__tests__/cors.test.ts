// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import {
  corsHandlerFnc,
  setCORSHeaders,
  handleCors,
  handleNoPost,
} from "../cors";

// Mock Express request/response
interface MockRequest {
  method: string;
  headers: Record<string, string | undefined>;
}

interface MockResponse {
  _headers: Record<string, string>;
  _statusCode: number;
  setHeader: jest.Mock;
  status: jest.Mock;
  send: jest.Mock;
  end: jest.Mock;
}

/**
 * Create a mock Express request object.
 * @param {string} method - HTTP method
 * @param {string} origin - Origin header value
 * @return {MockRequest} Mock request object
 */
function createMockRequest(method = "GET", origin?: string): MockRequest {
  return {
    method,
    headers: {
      origin: origin || "https://hht-diary-mvp.web.app",
    },
  };
}

/**
 * Create a mock Express response object.
 * @return {MockResponse} Mock response object
 */
function createMockResponse(): MockResponse {
  const res: MockResponse = {
    _headers: {},
    _statusCode: 200,
    setHeader: jest.fn(),
    status: jest.fn(),
    send: jest.fn(),
    end: jest.fn(),
  };
  res.setHeader.mockImplementation((key: string, value: string) => {
    res._headers[key] = value;
    return res;
  });
  res.status.mockImplementation((code: number) => {
    res._statusCode = code;
    return res;
  });
  res.send.mockReturnValue(res);
  res.end.mockReturnValue(res);
  return res;
}

describe("CORS Utilities", () => {
  describe("corsHandlerFnc", () => {
    it("returns a function", () => {
      const handler = corsHandlerFnc();
      expect(typeof handler).toBe("function");
    });

    it("is a cors middleware wrapper", () => {
      // The corsHandlerFnc wraps the cors library
      // We don't test the actual cors library behavior here
      // since it's a third-party dependency
      const handler = corsHandlerFnc();
      expect(handler.length).toBe(3); // (req, res, next)
    });
  });

  describe("setCORSHeaders", () => {
    it("sets Access-Control-Allow-Origin header", () => {
      const res = createMockResponse();
      setCORSHeaders(res as never);

      expect(res.setHeader).toHaveBeenCalledWith(
        "Access-Control-Allow-Origin",
        expect.any(String)
      );
    });

    it("sets Access-Control-Allow-Methods header", () => {
      const res = createMockResponse();
      setCORSHeaders(res as never);

      expect(res.setHeader).toHaveBeenCalledWith(
        "Access-Control-Allow-Methods",
        "GET, POST, OPTIONS"
      );
    });

    it("sets Access-Control-Allow-Headers header", () => {
      const res = createMockResponse();
      setCORSHeaders(res as never);

      expect(res.setHeader).toHaveBeenCalledWith(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization"
      );
    });

    it("includes allowed origins in header", () => {
      const res = createMockResponse();
      setCORSHeaders(res as never);

      const originHeader = res._headers["Access-Control-Allow-Origin"];
      expect(originHeader).toContain("hht-diary-mvp.web.app");
    });
  });

  describe("handleCors", () => {
    it("returns true and sends 204 for OPTIONS requests", () => {
      const req = createMockRequest("OPTIONS");
      const res = createMockResponse();

      const result = handleCors(req as never, res as never);

      expect(result).toBe(true);
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });

    it("sets CORS headers for OPTIONS requests", () => {
      const req = createMockRequest("OPTIONS");
      const res = createMockResponse();

      handleCors(req as never, res as never);

      expect(res.setHeader).toHaveBeenCalledWith(
        "Access-Control-Allow-Origin",
        expect.any(String)
      );
    });

    it("returns false for non-OPTIONS requests", () => {
      const req = createMockRequest("GET");
      const res = createMockResponse();

      const result = handleCors(req as never, res as never);

      expect(result).toBe(false);
    });

    it("returns false for POST requests", () => {
      const req = createMockRequest("POST");
      const res = createMockResponse();

      const result = handleCors(req as never, res as never);

      expect(result).toBe(false);
    });
  });

  describe("handleNoPost", () => {
    it("returns true and sends 405 for non-POST requests", () => {
      const req = createMockRequest("GET");
      const res = createMockResponse();

      const result = handleNoPost(req as never, res as never);

      expect(result).toBe(true);
      expect(res.status).toHaveBeenCalledWith(405);
      expect(res.send).toHaveBeenCalledWith("Method Not Allowed");
    });

    it("returns false for POST requests", () => {
      const req = createMockRequest("POST");
      const res = createMockResponse();

      const result = handleNoPost(req as never, res as never);

      expect(result).toBe(false);
      expect(res.status).not.toHaveBeenCalled();
    });

    it("rejects PUT requests", () => {
      const req = createMockRequest("PUT");
      const res = createMockResponse();

      const result = handleNoPost(req as never, res as never);

      expect(result).toBe(true);
      expect(res._statusCode).toBe(405);
    });

    it("rejects DELETE requests", () => {
      const req = createMockRequest("DELETE");
      const res = createMockResponse();

      const result = handleNoPost(req as never, res as never);

      expect(result).toBe(true);
      expect(res._statusCode).toBe(405);
    });

    it("rejects PATCH requests", () => {
      const req = createMockRequest("PATCH");
      const res = createMockResponse();

      const result = handleNoPost(req as never, res as never);

      expect(result).toBe(true);
      expect(res._statusCode).toBe(405);
    });
  });
});
