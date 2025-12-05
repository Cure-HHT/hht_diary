/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service
 *
 * Server entry point.
 */
import { createApp } from './app.js';
import { JwtService } from './services/jwt.service.js';
import { Argon2Service } from './services/argon2.service.js';
import { RateLimiterService } from './services/rate-limiter.service.js';
import { InMemoryUserRepository } from './repositories/user.repository.js';
import { InMemorySponsorPatternRepository } from './repositories/sponsor-pattern.repository.js';
import { loadConfig, RATE_LIMIT_CONFIG } from './config/index.js';
async function main() {
    const config = loadConfig();
    // Initialize services
    const jwtService = await JwtService.fromConfig({
        privateKey: config.jwtPrivateKey,
        publicKey: config.jwtPublicKey,
        issuer: config.jwtIssuer,
    });
    const argon2Service = new Argon2Service();
    const rateLimiter = new RateLimiterService({
        maxAttempts: RATE_LIMIT_CONFIG.MAX_ATTEMPTS,
        windowDuration: RATE_LIMIT_CONFIG.WINDOW_MS,
    });
    // Initialize repositories
    // In production, replace with Firestore implementations
    const userRepository = new InMemoryUserRepository();
    const sponsorPatternRepository = new InMemorySponsorPatternRepository();
    const deps = {
        jwtService,
        argon2Service,
        rateLimiter,
        userRepository,
        sponsorPatternRepository,
    };
    const app = createApp(deps);
    app.listen(config.port, config.host, () => {
        console.log(`Auth server listening on ${config.host}:${config.port}`);
    });
}
main().catch((error) => {
    console.error('Failed to start server:', error);
    process.exit(1);
});
// Re-export for library usage
export { createApp } from './app.js';
export { JwtService } from './services/jwt.service.js';
export { Argon2Service } from './services/argon2.service.js';
export { RateLimiterService } from './services/rate-limiter.service.js';
export { InMemoryUserRepository, } from './repositories/user.repository.js';
export { InMemorySponsorPatternRepository, } from './repositories/sponsor-pattern.repository.js';
export * from './models/web-user.model.js';
export * from './models/sponsor-pattern.model.js';
export * from './models/sponsor-config.model.js';
export * from './schemas/index.js';
export * from './config/index.js';
//# sourceMappingURL=index.js.map