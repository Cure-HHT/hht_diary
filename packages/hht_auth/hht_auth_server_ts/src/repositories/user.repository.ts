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
export class InMemoryUserRepository implements UserRepository {
  private users: Map<string, WebUser> = new Map();

  async createUser(user: WebUser): Promise<void> {
    this.users.set(user.id, { ...user });
  }

  async getUserByUsername(username: string): Promise<WebUser | null> {
    for (const user of this.users.values()) {
      if (user.username.toLowerCase() === username.toLowerCase()) {
        return { ...user };
      }
    }
    return null;
  }

  async getUserById(userId: string): Promise<WebUser | null> {
    const user = this.users.get(userId);
    return user ? { ...user } : null;
  }

  async updateUser(user: WebUser): Promise<void> {
    if (!this.users.has(user.id)) {
      throw new Error(`User ${user.id} not found`);
    }
    this.users.set(user.id, { ...user });
  }

  async usernameExists(username: string): Promise<boolean> {
    for (const user of this.users.values()) {
      if (user.username.toLowerCase() === username.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /** Clear all users (for testing) */
  clear(): void {
    this.users.clear();
  }

  /** Seed users (for testing) */
  seed(users: WebUser[]): void {
    for (const user of users) {
      this.users.set(user.id, { ...user });
    }
  }
}
