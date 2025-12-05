/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service
 *
 * Express application setup with auth routes.
 */
import { Express } from 'express';
import { JwtService } from './services/jwt.service.js';
import { Argon2Service } from './services/argon2.service.js';
import { RateLimiterService } from './services/rate-limiter.service.js';
import { UserRepository } from './repositories/user.repository.js';
import { SponsorPatternRepository } from './repositories/sponsor-pattern.repository.js';
export interface AppDependencies {
    jwtService: JwtService;
    argon2Service: Argon2Service;
    rateLimiter: RateLimiterService;
    userRepository: UserRepository;
    sponsorPatternRepository: SponsorPatternRepository;
}
/**
 * Create Express application with all routes configured.
 */
export declare function createApp(deps: AppDependencies): Express;
//# sourceMappingURL=app.d.ts.map