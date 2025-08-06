/**
 * Advanced Intelligent Caching System
 * Implements smart caching strategies for improved performance
 */

class IntelligentCache {
  constructor() {
    this.cache = new Map();
    this.priorities = new Map();
    this.accessTimes = new Map();
    this.maxSize = 100; // Maximum number of cached items
    this.ttl = 5 * 60 * 1000; // 5 minutes default TTL
    this.compressionThreshold = 1024; // 1KB
    
    // Initialize performance monitoring
    this.stats = {
      hits: 0,
      misses: 0,
      evictions: 0,
      compressionSaves: 0
    };
    
    // Start cleanup interval
    this.startCleanupInterval();
  }

  /**
   * Store item in cache with intelligent priority and compression
   */
  set(key, value, options = {}) {
    const {
      priority = 1,
      ttl = this.ttl,
      compress = true,
      tags = []
    } = options;

    // Remove expired items if cache is full
    if (this.cache.size >= this.maxSize) {
      this.evictLeastUsed();
    }

    const item = {
      value: compress && this.shouldCompress(value) ? this.compress(value) : value,
      compressed: compress && this.shouldCompress(value),
      timestamp: Date.now(),
      ttl,
      accessCount: 0,
      tags,
      size: this.calculateSize(value)
    };

    this.cache.set(key, item);
    this.priorities.set(key, priority);
    this.accessTimes.set(key, Date.now());

    // Log compression savings
    if (item.compressed) {
      this.stats.compressionSaves++;
    }

    return this;
  }

  /**
   * Retrieve item from cache with LRU tracking
   */
  get(key) {
    const item = this.cache.get(key);
    
    if (!item) {
      this.stats.misses++;
      return undefined;
    }

    // Check if expired
    if (this.isExpired(item)) {
      this.delete(key);
      this.stats.misses++;
      return undefined;
    }

    // Update access tracking
    item.accessCount++;
    this.accessTimes.set(key, Date.now());
    this.stats.hits++;

    // Return decompressed value if needed
    return item.compressed ? this.decompress(item.value) : item.value;
  }

  /**
   * Smart memoization for expensive operations
   */
  memoize(fn, keyGenerator = (...args) => JSON.stringify(args)) {
    return (...args) => {
      const key = `memoized:${fn.name}:${keyGenerator(...args)}`;
      
      let result = this.get(key);
      if (result === undefined) {
        result = fn(...args);
        this.set(key, result, { 
          priority: 2, // Higher priority for computed values
          ttl: 10 * 60 * 1000, // 10 minutes for memoized results
          tags: ['memoized', fn.name]
        });
      }
      
      return result;
    };
  }

  /**
   * Cache API responses with smart invalidation
   */
  cacheApiResponse(url, response, options = {}) {
    const key = `api:${url}`;
    const {
      maxAge = 2 * 60 * 1000, // 2 minutes for API responses
      staleWhileRevalidate = true
    } = options;

    this.set(key, {
      data: response,
      url,
      cached: Date.now(),
      staleWhileRevalidate
    }, {
      priority: 3, // High priority for API responses
      ttl: maxAge,
      tags: ['api', this.extractDomainFromUrl(url)]
    });
  }

  /**
   * Get cached API response with stale-while-revalidate support
   */
  getCachedApiResponse(url) {
    const key = `api:${url}`;
    const cached = this.get(key);
    
    if (!cached) return null;

    // Check if we should trigger background refresh
    const age = Date.now() - cached.cached;
    const shouldRevalidate = cached.staleWhileRevalidate && age > (cached.ttl * 0.8);
    
    return {
      data: cached.data,
      stale: shouldRevalidate,
      age
    };
  }

  /**
   * Invalidate cache by tags
   */
  invalidateByTag(tag) {
    let evicted = 0;
    for (const [key, item] of this.cache.entries()) {
      if (item.tags && item.tags.includes(tag)) {
        this.delete(key);
        evicted++;
      }
    }
    return evicted;
  }

  /**
   * Preload critical resources
   */
  preload(items) {
    for (const { key, loader, priority = 1 } of items) {
      if (!this.cache.has(key)) {
        // Load asynchronously
        Promise.resolve(loader()).then(value => {
          this.set(key, value, { priority, tags: ['preloaded'] });
        }).catch(error => {
          console.warn(`Failed to preload ${key}:`, error);
        });
      }
    }
  }

  /**
   * Get cache statistics
   */
  getStats() {
    const hitRate = this.stats.hits / (this.stats.hits + this.stats.misses) * 100;
    const totalSize = Array.from(this.cache.values())
      .reduce((sum, item) => sum + (item.size || 0), 0);

    return {
      ...this.stats,
      hitRate: hitRate.toFixed(2),
      size: this.cache.size,
      totalSizeKB: (totalSize / 1024).toFixed(2),
      avgItemSize: this.cache.size > 0 ? (totalSize / this.cache.size).toFixed(0) : 0
    };
  }

  // Private methods

  isExpired(item) {
    return Date.now() - item.timestamp > item.ttl;
  }

  evictLeastUsed() {
    let leastUsedKey = null;
    let leastUsedScore = Infinity;

    for (const [key, item] of this.cache.entries()) {
      const priority = this.priorities.get(key) || 1;
      const accessTime = this.accessTimes.get(key) || 0;
      const score = (item.accessCount * priority) - (Date.now() - accessTime);
      
      if (score < leastUsedScore) {
        leastUsedScore = score;
        leastUsedKey = key;
      }
    }

    if (leastUsedKey) {
      this.delete(leastUsedKey);
      this.stats.evictions++;
    }
  }

  shouldCompress(value) {
    const size = this.calculateSize(value);
    return size > this.compressionThreshold;
  }

  compress(value) {
    // Simple compression using JSON + base64 (in production, use proper compression)
    try {
      const json = JSON.stringify(value);
      return btoa(json);
    } catch {
      return value;
    }
  }

  decompress(compressed) {
    try {
      const json = atob(compressed);
      return JSON.parse(json);
    } catch {
      return compressed;
    }
  }

  calculateSize(value) {
    try {
      return new Blob([JSON.stringify(value)]).size;
    } catch {
      return 0;
    }
  }

  extractDomainFromUrl(url) {
    try {
      return new URL(url).hostname;
    } catch {
      return 'unknown';
    }
  }

  delete(key) {
    this.cache.delete(key);
    this.priorities.delete(key);
    this.accessTimes.delete(key);
  }

  clear() {
    this.cache.clear();
    this.priorities.clear();
    this.accessTimes.clear();
    this.stats = { hits: 0, misses: 0, evictions: 0, compressionSaves: 0 };
  }

  startCleanupInterval() {
    // Clean up expired items every 2 minutes
    setInterval(() => {
      for (const [key, item] of this.cache.entries()) {
        if (this.isExpired(item)) {
          this.delete(key);
        }
      }
    }, 2 * 60 * 1000);
  }
}

// Create singleton instance
const intelligentCache = new IntelligentCache();

// Export for use in other modules
export default intelligentCache;
