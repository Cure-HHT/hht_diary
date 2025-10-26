/**
 * In-memory cache for requirements
 */

import { Requirement } from '../linear/types';
import { loadRequirementsFromSpec } from './loader';

export class RequirementCache {
    private cache: Map<string, Requirement> = new Map();
    private lastLoadTime: number = 0;
    private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes

    /**
     * Load or refresh requirements from spec directory
     */
    refresh(specPath: string): void {
        this.cache = loadRequirementsFromSpec(specPath);
        this.lastLoadTime = Date.now();
    }

    /**
     * Get requirement by ID
     */
    get(id: string): Requirement | undefined {
        // Remove REQ- prefix if present
        const cleanId = id.replace(/^REQ-/, '');
        return this.cache.get(cleanId);
    }

    /**
     * Get multiple requirements
     */
    getMultiple(ids: string[]): Requirement[] {
        return ids
            .map(id => this.get(id))
            .filter((req): req is Requirement => req !== undefined);
    }

    /**
     * Get all requirements
     */
    getAll(): Requirement[] {
        return Array.from(this.cache.values());
    }

    /**
     * Check if cache needs refresh
     */
    needsRefresh(): boolean {
        return Date.now() - this.lastLoadTime > this.CACHE_TTL;
    }

    /**
     * Get cache size
     */
    size(): number {
        return this.cache.size;
    }

    /**
     * Clear cache
     */
    clear(): void {
        this.cache.clear();
        this.lastLoadTime = 0;
    }
}

// Global cache instance
export const requirementCache = new RequirementCache();
