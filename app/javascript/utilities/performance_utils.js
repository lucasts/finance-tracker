/**
 * Performance Utilities for Finance Tracker
 * Provides tools for monitoring and optimizing performance
 */

import intelligentCache from 'services/intelligent_cache';

class PerformanceUtils {
  constructor() {
    this.metrics = new Map();
    this.observers = new Map();
    this.setupPerformanceMonitoring();
  }

  /**
   * Measure and cache expensive operations
   */
  measureAndCache(name, operation, cacheOptions = {}) {
    const start = performance.now();
    
    // Try to get from cache first
    const cached = intelligentCache.get(`perf:${name}`);
    if (cached !== undefined) {
      return cached;
    }

    // Execute operation and cache result
    const result = operation();
    const duration = performance.now() - start;
    
    // Store performance metrics
    this.recordMetric(name, duration);
    
    // Cache result with performance-based TTL
    const ttl = this.calculateOptimalTTL(duration);
    intelligentCache.set(`perf:${name}`, result, {
      ttl,
      priority: 2,
      tags: ['performance', name],
      ...cacheOptions
    });

    return result;
  }

  /**
   * Debounced cache operations for frequent updates
   */
  debouncedCache(key, value, delay = 300) {
    const debouncedKey = `debounced:${key}`;
    
    // Clear existing timeout
    if (this.observers.has(debouncedKey)) {
      clearTimeout(this.observers.get(debouncedKey));
    }

    // Set new timeout
    const timeoutId = setTimeout(() => {
      intelligentCache.set(key, value, {
        tags: ['debounced'],
        priority: 1
      });
      this.observers.delete(debouncedKey);
    }, delay);

    this.observers.set(debouncedKey, timeoutId);
  }

  /**
   * Batch cache operations for better performance
   */
  batchSet(items) {
    const batchStart = performance.now();
    
    for (const { key, value, options = {} } of items) {
      intelligentCache.set(key, value, {
        tags: ['batched'],
        ...options
      });
    }

    const duration = performance.now() - batchStart;
    this.recordMetric('cache-batch-set', duration);
    
    return duration;
  }

  /**
   * Batch get operations with single miss handling
   */
  batchGet(keys, missHandler = null) {
    const results = new Map();
    const misses = [];
    
    for (const key of keys) {
      const value = intelligentCache.get(key);
      if (value !== undefined) {
        results.set(key, value);
      } else {
        misses.push(key);
      }
    }

    // Handle misses in batch if handler provided
    if (missHandler && misses.length > 0) {
      const missedValues = missHandler(misses);
      for (const [key, value] of Object.entries(missedValues)) {
        results.set(key, value);
        // Cache the newly loaded values
        intelligentCache.set(key, value, {
          tags: ['batch-loaded'],
          priority: 2
        });
      }
    }

    return results;
  }

  /**
   * Smart preloading based on user behavior patterns
   */
  smartPreload(patterns) {
    const preloadCandidates = this.analyzePreloadCandidates(patterns);
    
    for (const candidate of preloadCandidates) {
      this.preloadResource(candidate);
    }
  }

  /**
   * Memory pressure aware caching
   */
  adaptToMemoryPressure() {
    if ('memory' in performance) {
      const memInfo = performance.memory;
      const memoryPressure = memInfo.usedJSHeapSize / memInfo.totalJSHeapSize;
      
      if (memoryPressure > 0.8) {
        // High memory pressure - aggressive cleanup
        this.aggressiveCleanup();
      } else if (memoryPressure > 0.6) {
        // Medium pressure - normal cleanup
        this.normalCleanup();
      }
    }
  }

  /**
   * Get performance insights
   */
  getPerformanceInsights() {
    const cacheStats = intelligentCache.getStats();
    const metrics = Object.fromEntries(this.metrics);
    
    return {
      cache: cacheStats,
      metrics,
      recommendations: this.generateRecommendations(cacheStats, metrics),
      memoryUsage: this.getMemoryUsage()
    };
  }

  // Private methods

  setupPerformanceMonitoring() {
    // Monitor cache performance
    setInterval(() => {
      this.adaptToMemoryPressure();
    }, 30000); // Every 30 seconds

    // Setup performance observers if available
    if ('PerformanceObserver' in window) {
      this.setupPerformanceObserver();
    }
  }

  setupPerformanceObserver() {
    try {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'measure') {
            this.recordMetric(entry.name, entry.duration);
          }
        }
      });
      observer.observe({ entryTypes: ['measure'] });
    } catch (e) {
      console.warn('Performance Observer not fully supported:', e);
    }
  }

  recordMetric(name, value) {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, {
        count: 0,
        total: 0,
        min: Infinity,
        max: -Infinity,
        avg: 0
      });
    }

    const metric = this.metrics.get(name);
    metric.count++;
    metric.total += value;
    metric.min = Math.min(metric.min, value);
    metric.max = Math.max(metric.max, value);
    metric.avg = metric.total / metric.count;
  }

  calculateOptimalTTL(operationDuration) {
    // Longer operations get longer cache TTL
    if (operationDuration > 100) return 10 * 60 * 1000; // 10 minutes
    if (operationDuration > 50) return 5 * 60 * 1000;   // 5 minutes
    if (operationDuration > 10) return 2 * 60 * 1000;   // 2 minutes
    return 60 * 1000; // 1 minute
  }

  analyzePreloadCandidates(patterns) {
    // Simple heuristic - in production this would be more sophisticated
    return patterns
      .filter(pattern => pattern.frequency > 0.7) // High frequency
      .sort((a, b) => b.priority - a.priority)
      .slice(0, 5); // Top 5 candidates
  }

  preloadResource(candidate) {
    if (!intelligentCache.get(candidate.key)) {
      candidate.loader().then(data => {
        intelligentCache.set(candidate.key, data, {
          priority: 3,
          tags: ['preloaded', 'smart'],
          ttl: 15 * 60 * 1000 // 15 minutes for preloaded
        });
      }).catch(error => {
        console.warn(`Smart preload failed for ${candidate.key}:`, error);
      });
    }
  }

  aggressiveCleanup() {
    // Remove low priority and least used items
    intelligentCache.invalidateByTag('temporary');
    intelligentCache.invalidateByTag('debounced');
    // Force eviction of bottom 20% by access count
  }

  normalCleanup() {
    // Remove only temporary items
    intelligentCache.invalidateByTag('temporary');
  }

  generateRecommendations(cacheStats, metrics) {
    const recommendations = [];

    if (parseFloat(cacheStats.hitRate) < 70) {
      recommendations.push('Consider increasing cache TTL or improving cache key strategies');
    }

    if (cacheStats.evictions > cacheStats.hits * 0.1) {
      recommendations.push('Cache size might be too small, consider increasing maxSize');
    }

    if (parseFloat(cacheStats.totalSizeKB) > 1000) {
      recommendations.push('Large cache size detected, consider implementing compression');
    }

    return recommendations;
  }

  getMemoryUsage() {
    if ('memory' in performance) {
      const mem = performance.memory;
      return {
        used: (mem.usedJSHeapSize / 1024 / 1024).toFixed(2) + ' MB',
        total: (mem.totalJSHeapSize / 1024 / 1024).toFixed(2) + ' MB',
        limit: (mem.jsHeapSizeLimit / 1024 / 1024).toFixed(2) + ' MB'
      };
    }
    return null;
  }
}

// Create singleton instance
const performanceUtils = new PerformanceUtils();

export default performanceUtils;
