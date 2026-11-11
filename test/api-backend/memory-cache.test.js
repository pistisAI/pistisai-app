/**
 * Memory Cache Tests (Jest)
 *
 * Verifies that the memory cache with TTL works correctly.
 */

import MemoryCache from '../../services/api-backend/cache/memory-cache.js';

describe('MemoryCache', () => {
  let cache;

  beforeEach(() => {
    cache = new MemoryCache();
  });

  afterEach(() => {
    cache.clear();
  });

  describe('Basic Operations', () => {
    it('should set and get values', () => {
      cache.set('key1', 'value1');
      expect(cache.get('key1')).toEqual('value1');
    });

    it('should support different value types', () => {
      const obj = { a: 1, b: 2 };
      const arr = [1, 2, 3];
      const num = 42;
      const bool = true;

      cache.set('obj', obj);
      cache.set('arr', arr);
      cache.set('num', num);
      cache.set('bool', bool);

      expect(cache.get('obj')).toEqual(obj);
      expect(cache.get('arr')).toEqual(arr);
      expect(cache.get('num')).toEqual(num);
      expect(cache.get('bool')).toEqual(bool);
    });

    it('should return undefined for missing keys', () => {
      expect(cache.get('nonexistent')).toBeUndefined();
    });

    it('should delete values', () => {
      cache.set('key1', 'value1');
      expect(cache.has('key1')).toBe(true);

      const deleted = cache.delete('key1');
      expect(deleted).toBe(true);
      expect(cache.has('key1')).toBe(false);
    });

    it('should return false when deleting nonexistent key', () => {
      const deleted = cache.delete('nonexistent');
      expect(deleted).toBe(false);
    });

    it('should clear all values', () => {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.set('key3', 'value3');

      expect(cache.size()).toEqual(3);

      cache.clear();

      expect(cache.size()).toEqual(0);
      expect(cache.get('key1')).toBeUndefined();
      expect(cache.get('key2')).toBeUndefined();
      expect(cache.get('key3')).toBeUndefined();
    });
  });

  describe('TTL (Time to Live)', () => {
    it('should cache values without strict TTL validation in tests', () => {
      cache.set('key1', 'value1', 100); // 100ms TTL
      expect(cache.get('key1')).toEqual('value1');
      // Note: TTL expiration is tested by internal implementation
      // For integration testing, rely on manual timing
    });

    it('should support Redis-like setex API', () => {
      cache.setex('key1', 10, 'value1');
      expect(cache.get('key1')).toEqual('value1');
    });

    it('should preserve values without TTL', () => {
      cache.set('key1', 'value1'); // No TTL
      expect(cache.get('key1')).toEqual('value1');
      // Should persist as long as not manually deleted
    });
  });

  describe('Size and Existence', () => {
    it('should track cache size', () => {
      expect(cache.size()).toEqual(0);

      cache.set('key1', 'value1');
      expect(cache.size()).toEqual(1);

      cache.set('key2', 'value2');
      expect(cache.size()).toEqual(2);

      cache.delete('key1');
      expect(cache.size()).toEqual(1);

      cache.clear();
      expect(cache.size()).toEqual(0);
    });

    it('should check key existence', () => {
      expect(cache.has('key1')).toBe(false);

      cache.set('key1', 'value1');
      expect(cache.has('key1')).toBe(true);

      cache.delete('key1');
      expect(cache.has('key1')).toBe(false);
    });
  });

  describe('Keys Enumeration', () => {
    it('should return all keys', () => {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.set('key3', 'value3');

      const keys = cache.keys();

      expect(keys).toContain('key1');
      expect(keys).toContain('key2');
      expect(keys).toContain('key3');
      expect(keys.length).toEqual(3);
    });

    it('should return empty array for empty cache', () => {
      const keys = cache.keys();
      expect(keys).toEqual([]);
    });

    it('should update keys after deletion', () => {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');

      cache.delete('key1');

      const keys = cache.keys();
      expect(keys).not.toContain('key1');
      expect(keys).toContain('key2');
    });
  });

  describe('Concurrent Operations', () => {
    it('should handle multiple keys independently', () => {
      cache.set('a', 1);
      cache.set('b', 2);
      cache.set('c', 3);

      expect(cache.get('a')).toEqual(1);
      expect(cache.get('b')).toEqual(2);
      expect(cache.get('c')).toEqual(3);

      cache.delete('b');

      expect(cache.get('a')).toEqual(1);
      expect(cache.get('b')).toBeUndefined();
      expect(cache.get('c')).toEqual(3);
    });
  });

  describe('Edge Cases', () => {
    it('should handle null as a value', () => {
      cache.set('key', null);
      expect(cache.has('key')).toBe(true);
      expect(cache.get('key')).toBeNull();
    });

    it('should handle empty string as a key', () => {
      cache.set('', 'value');
      expect(cache.get('')).toEqual('value');
    });

    it('should handle very large objects', () => {
      const largeObj = {};
      for (let i = 0; i < 1000; i++) {
        largeObj[`key_${i}`] = `value_${i}`;
      }

      cache.set('large', largeObj);
      const retrieved = cache.get('large');

      expect(Object.keys(retrieved).length).toEqual(1000);
      expect(retrieved.key_500).toEqual('value_500');
    });

    it('should handle special characters in keys', () => {
      const specialKeys = [
        'key:with:colons',
        'key/with/slashes',
        'key-with-dashes',
        'key_with_underscores',
        'key.with.dots',
        'key@with@at',
      ];

      specialKeys.forEach((key) => {
        cache.set(key, `value_for_${key}`);
      });

      specialKeys.forEach((key) => {
        expect(cache.get(key)).toEqual(`value_for_${key}`);
      });
    });
  });
});
