/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00081: User Document Schema
 *
 * User repository interface and in-memory implementation.
 */
/**
 * In-memory user repository for testing.
 */
export class InMemoryUserRepository {
    users = new Map();
    async createUser(user) {
        this.users.set(user.id, { ...user });
    }
    async getUserByUsername(username) {
        for (const user of this.users.values()) {
            if (user.username.toLowerCase() === username.toLowerCase()) {
                return { ...user };
            }
        }
        return null;
    }
    async getUserById(userId) {
        const user = this.users.get(userId);
        return user ? { ...user } : null;
    }
    async updateUser(user) {
        if (!this.users.has(user.id)) {
            throw new Error(`User ${user.id} not found`);
        }
        this.users.set(user.id, { ...user });
    }
    async usernameExists(username) {
        for (const user of this.users.values()) {
            if (user.username.toLowerCase() === username.toLowerCase()) {
                return true;
            }
        }
        return false;
    }
    /** Clear all users (for testing) */
    clear() {
        this.users.clear();
    }
    /** Seed users (for testing) */
    seed(users) {
        for (const user of users) {
            this.users.set(user.id, { ...user });
        }
    }
}
//# sourceMappingURL=user.repository.js.map