/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00081: User Document Schema
 *
 * User repository interface and in-memory implementation.
 */
import { WebUser } from '../models/web-user.model.js';
/**
 * Repository interface for user operations.
 */
export interface UserRepository {
    createUser(user: WebUser): Promise<void>;
    getUserByUsername(username: string): Promise<WebUser | null>;
    getUserById(userId: string): Promise<WebUser | null>;
    updateUser(user: WebUser): Promise<void>;
    usernameExists(username: string): Promise<boolean>;
}
/**
 * In-memory user repository for testing.
 */
export declare class InMemoryUserRepository implements UserRepository {
    private users;
    createUser(user: WebUser): Promise<void>;
    getUserByUsername(username: string): Promise<WebUser | null>;
    getUserById(userId: string): Promise<WebUser | null>;
    updateUser(user: WebUser): Promise<void>;
    usernameExists(username: string): Promise<boolean>;
    /** Clear all users (for testing) */
    clear(): void;
    /** Seed users (for testing) */
    seed(users: WebUser[]): void;
}
//# sourceMappingURL=user.repository.d.ts.map