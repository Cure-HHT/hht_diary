// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import cors = require("cors");
import * as express from "express";

const ALLOWED_ORIGINS = [
  "https://hht-diary-mvp.web.app",
  "https://www.hht-diary-mvp.web.app",
];

/**
 * Creates a CORS handler middleware with configured origins.
 * @return {cors.CorsMiddleware} Configured CORS middleware
 */
export const corsHandlerFnc = (): ReturnType<typeof cors> => cors({
  origin: ALLOWED_ORIGINS,
  methods: ["GET", "POST", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
});

/**
 * Sets CORS headers on a response.
 * @param {express.Response} res - Express response object
 */
export function setCORSHeaders(res: express.Response): void {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGINS.join(", "));
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

/**
 * Handles CORS preflight (OPTIONS) requests.
 * @param {express.Request} req - Express request object
 * @param {express.Response} res - Express response object
 * @return {boolean} True if request was handled, false otherwise
 */
export function handleCors(
  req: express.Request,
  res: express.Response
): boolean {
  if (req.method === "OPTIONS") {
    setCORSHeaders(res);
    res.status(204).send();
    return true;
  }
  return false;
}

/**
 * Handles non-POST requests by returning 405 Method Not Allowed.
 * @param {express.Request} req - Express request object
 * @param {express.Response} res - Express response object
 * @return {boolean} True if request was rejected, false if POST
 */
export function handleNoPost(
  req: express.Request,
  res: express.Response
): boolean {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return true;
  }
  return false;
}
