/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service
 *
 * Express application setup with auth routes.
 */
import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { ZodError } from 'zod';
import { createWebUser, isUserLocked, webUserToJson } from './models/web-user.model.js';
import { createDefaultSponsorConfig } from './models/sponsor-config.model.js';
import { loginSchema, registrationSchema, linkingCodeSchema, refreshTokenSchema, changePasswordSchema, } from './schemas/index.js';
import { ACCOUNT_LOCKOUT_CONFIG } from './config/index.js';
/**
 * Validation middleware factory.
 */
function validateBody(schema) {
    return (req, res, next) => {
        try {
            req.body = schema.parse(req.body);
            next();
        }
        catch (error) {
            if (error instanceof ZodError) {
                res.status(400).json({
                    message: error.errors.map((e) => e.message).join(', '),
                });
                return;
            }
            next(error);
        }
    };
}
/**
 * Create Express application with all routes configured.
 */
export function createApp(deps) {
    const app = express();
    app.use(express.json());
    // Health check
    app.get('/health', (_req, res) => {
        res.json({ status: 'ok' });
    });
    // POST /auth/validate-linking-code
    app.post('/auth/validate-linking-code', validateBody(linkingCodeSchema), async (req, res) => {
        const { linkingCode } = req.body;
        const pattern = await deps.sponsorPatternRepository.findByLinkingCode(linkingCode);
        if (!pattern) {
            res.status(400).json({ message: 'Invalid linking code' });
            return;
        }
        res.json({
            sponsorId: pattern.sponsorId,
            sponsorName: pattern.sponsorName,
            portalUrl: pattern.portalUrl,
        });
    });
    // POST /auth/register
    app.post('/auth/register', validateBody(registrationSchema), async (req, res) => {
        const body = req.body;
        // Validate linking code
        const pattern = await deps.sponsorPatternRepository.findByLinkingCode(body.linkingCode);
        if (!pattern) {
            res.status(400).json({ message: 'Invalid linking code' });
            return;
        }
        // Check username availability
        const exists = await deps.userRepository.usernameExists(body.username);
        if (exists) {
            res.status(409).json({ message: 'Username already taken' });
            return;
        }
        // Create user
        const user = createWebUser({
            id: uuidv4(),
            username: body.username,
            passwordHash: body.passwordHash,
            salt: body.salt,
            sponsorId: pattern.sponsorId,
            linkingCode: body.linkingCode,
            appUuid: body.appUuid,
        });
        await deps.userRepository.createUser(user);
        // Generate token
        const token = await deps.jwtService.generateToken({
            sub: user.id,
            username: user.username,
            sponsorId: user.sponsorId,
            sponsorUrl: pattern.portalUrl,
            appUuid: user.appUuid,
        });
        res.status(201).json({
            token,
            user: webUserToJson(user),
        });
    });
    // POST /auth/login
    app.post('/auth/login', validateBody(loginSchema), async (req, res) => {
        const { username, password, appUuid } = req.body;
        const rateLimitKey = `${req.ip ?? 'unknown'}:${username}`;
        // Rate limiting
        if (!deps.rateLimiter.checkLimit(rateLimitKey)) {
            const timeUntilReset = deps.rateLimiter.getTimeUntilReset(rateLimitKey);
            res.status(429).json({
                message: `Too many login attempts. Try again in ${Math.ceil((timeUntilReset ?? 60000) / 1000)} seconds.`,
            });
            return;
        }
        // Find user
        const user = await deps.userRepository.getUserByUsername(username);
        if (!user) {
            res.status(401).json({ message: 'Invalid username or password' });
            return;
        }
        // Check account lock
        if (isUserLocked(user)) {
            res.status(403).json({
                message: `Account is locked until ${user.lockedUntil}`,
            });
            return;
        }
        // Verify password
        const isValid = await deps.argon2Service.verify(password, user.passwordHash, user.salt);
        if (!isValid) {
            // Increment failed attempts
            const newFailedAttempts = user.failedAttempts + 1;
            const lockedUntil = newFailedAttempts >= ACCOUNT_LOCKOUT_CONFIG.MAX_FAILED_ATTEMPTS
                ? new Date(Date.now() + ACCOUNT_LOCKOUT_CONFIG.LOCKOUT_MINUTES * 60 * 1000).toISOString()
                : null;
            await deps.userRepository.updateUser({
                ...user,
                failedAttempts: newFailedAttempts,
                lockedUntil,
            });
            res.status(401).json({ message: 'Invalid username or password' });
            return;
        }
        // Get sponsor pattern for portal URL
        const pattern = await deps.sponsorPatternRepository.findBySponsorId(user.sponsorId);
        if (!pattern) {
            res.status(500).json({ message: 'Sponsor configuration error' });
            return;
        }
        // Reset failed attempts and update last login
        const updatedUser = {
            ...user,
            failedAttempts: 0,
            lockedUntil: null,
            lastLoginAt: new Date().toISOString(),
        };
        await deps.userRepository.updateUser(updatedUser);
        deps.rateLimiter.reset(rateLimitKey);
        // Generate token
        const token = await deps.jwtService.generateToken({
            sub: user.id,
            username: user.username,
            sponsorId: user.sponsorId,
            sponsorUrl: pattern.portalUrl,
            appUuid,
        });
        res.json({
            token,
            user: webUserToJson(updatedUser),
        });
    });
    // POST /auth/refresh
    app.post('/auth/refresh', validateBody(refreshTokenSchema), async (req, res) => {
        const { token } = req.body;
        const newToken = await deps.jwtService.refreshToken(token);
        if (!newToken) {
            res.status(401).json({ message: 'Invalid or expired token' });
            return;
        }
        const payload = await deps.jwtService.verifyToken(newToken);
        if (!payload) {
            res.status(401).json({ message: 'Token verification failed' });
            return;
        }
        const user = await deps.userRepository.getUserById(payload.sub);
        if (!user) {
            res.status(401).json({ message: 'User not found' });
            return;
        }
        res.json({
            token: newToken,
            user: webUserToJson(user),
        });
    });
    // POST /auth/change-password
    app.post('/auth/change-password', validateBody(changePasswordSchema), async (req, res) => {
        const body = req.body;
        const user = await deps.userRepository.getUserByUsername(body.username);
        if (!user) {
            res.status(401).json({ message: 'Invalid credentials' });
            return;
        }
        // Verify current password
        const isValid = await deps.argon2Service.verify(body.currentPassword, user.passwordHash, user.salt);
        if (!isValid) {
            res.status(401).json({ message: 'Invalid credentials' });
            return;
        }
        // Update password
        const updatedUser = {
            ...user,
            passwordHash: body.newPasswordHash,
            salt: body.newSalt,
        };
        await deps.userRepository.updateUser(updatedUser);
        // Get sponsor pattern
        const pattern = await deps.sponsorPatternRepository.findBySponsorId(user.sponsorId);
        if (!pattern) {
            res.status(500).json({ message: 'Sponsor configuration error' });
            return;
        }
        // Generate new token
        const token = await deps.jwtService.generateToken({
            sub: user.id,
            username: user.username,
            sponsorId: user.sponsorId,
            sponsorUrl: pattern.portalUrl,
            appUuid: user.appUuid,
        });
        res.json({
            token,
            user: webUserToJson(updatedUser),
        });
    });
    // GET /auth/sponsor-config/:sponsorId
    app.get('/auth/sponsor-config/:sponsorId', async (req, res) => {
        const { sponsorId } = req.params;
        if (!sponsorId) {
            res.status(400).json({ message: 'Sponsor ID required' });
            return;
        }
        const pattern = await deps.sponsorPatternRepository.findBySponsorId(sponsorId);
        if (!pattern) {
            // Return default config if sponsor not found
            res.json(createDefaultSponsorConfig(sponsorId));
            return;
        }
        // In production, this would fetch from Sponsor Portal
        // For now, return default config with sponsor name
        res.json(createDefaultSponsorConfig(sponsorId, pattern.sponsorName));
    });
    // Error handler
    app.use((err, _req, res, _next) => {
        console.error('Unhandled error:', err);
        res.status(500).json({ message: 'Internal server error' });
    });
    return app;
}
//# sourceMappingURL=app.js.map