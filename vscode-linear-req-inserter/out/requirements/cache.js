"use strict";
/**
 * In-memory cache for requirements
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.requirementCache = exports.RequirementCache = void 0;
const loader_1 = require("./loader");
class RequirementCache {
    constructor() {
        this.cache = new Map();
        this.lastLoadTime = 0;
        this.CACHE_TTL = 5 * 60 * 1000; // 5 minutes
    }
    /**
     * Load or refresh requirements from spec directory
     */
    refresh(specPath) {
        this.cache = (0, loader_1.loadRequirementsFromSpec)(specPath);
        this.lastLoadTime = Date.now();
    }
    /**
     * Get requirement by ID
     */
    get(id) {
        // Remove REQ- prefix if present
        const cleanId = id.replace(/^REQ-/, '');
        return this.cache.get(cleanId);
    }
    /**
     * Get multiple requirements
     */
    getMultiple(ids) {
        return ids
            .map(id => this.get(id))
            .filter((req) => req !== undefined);
    }
    /**
     * Get all requirements
     */
    getAll() {
        return Array.from(this.cache.values());
    }
    /**
     * Check if cache needs refresh
     */
    needsRefresh() {
        return Date.now() - this.lastLoadTime > this.CACHE_TTL;
    }
    /**
     * Get cache size
     */
    size() {
        return this.cache.size;
    }
    /**
     * Clear cache
     */
    clear() {
        this.cache.clear();
        this.lastLoadTime = 0;
    }
}
exports.RequirementCache = RequirementCache;
// Global cache instance
exports.requirementCache = new RequirementCache();
//# sourceMappingURL=cache.js.map