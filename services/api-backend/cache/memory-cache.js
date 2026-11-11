/**
 * Memory Cache Implementation
 *
 * Simple in-memory cache with TTL support for development and testing.
 * For production, use Redis.
 *
 * @fileoverview Memory cache with TTL
 * @version 1.0.0
 */

export class MemoryCache {
  constructor() {
    this.store = new Map();
    this.timers = new Map();
  }

  /**
   * Set a value with optional TTL
   * @param {string} key - Cache key
   * @param {*} value - Value to cache
   * @param {number} ttlMs - Time to live in milliseconds (optional)
   */
  set(key, value, ttlMs) {
    // Clear existing timer if present
    if (this.timers.has(key)) {
      clearTimeout(this.timers.get(key));
    }

    this.store.set(key, value);

    // Set TTL if provided
    if (ttlMs) {
      const timer = setTimeout(() => {
        this.store.delete(key);
        this.timers.delete(key);
      }, ttlMs);

      this.timers.set(key, timer);
    }
  }

  /**
   * Set a value with TTL in seconds (Redis-like API)
   * @param {string} key - Cache key
   * @param {number} ttlSeconds - Time to live in seconds
   * @param {*} value - Value to cache
   */
  setex(key, ttlSeconds, value) {
    this.set(key, value, ttlSeconds * 1000);
  }

  /**
   * Get a value from cache
   * @param {string} key - Cache key
   * @returns {*} Cached value or undefined
   */
  get(key) {
    return this.store.get(key);
  }

  /**
   * Delete a value from cache
   * @param {string} key - Cache key
   * @returns {boolean} True if key existed
   */
  delete(key) {
    if (this.timers.has(key)) {
      clearTimeout(this.timers.get(key));
      this.timers.delete(key);
    }
    return this.store.delete(key);
  }

  /**
   * Clear all cache entries
   */
  clear() {
    this.timers.forEach((timer) => clearTimeout(timer));
    this.timers.clear();
    this.store.clear();
  }

  /**
   * Get cache size
   * @returns {number} Number of entries in cache
   */
  size() {
    return this.store.size;
  }

  /**
   * Check if key exists
   * @param {string} key - Cache key
   * @returns {boolean} True if key exists
   */
  has(key) {
    return this.store.has(key);
  }

  /**
   * Get all keys
   * @returns {string[]} Array of cache keys
   */
  keys() {
    return Array.from(this.store.keys());
  }
}

export default MemoryCache;
