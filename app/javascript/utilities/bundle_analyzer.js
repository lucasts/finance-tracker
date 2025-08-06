/**
 * Bundle Analyzer - Analyze and optimize JavaScript bundle sizes
 * Provides detailed insights into bundle composition and optimization opportunities
 */

class BundleAnalyzer {
  constructor() {
    this.modules = new Map();
    this.dependencies = new Map();
    this.loadTimes = new Map();
    this.setupAnalysis();
  }

  async setupAnalysis() {
    // Setup performance observer for resource loading
    if ('PerformanceObserver' in window) {
      this.setupResourceObserver();
    }

    // Setup module tracking
    this.trackModuleLoading();
    
    // Analyze current page modules
    await this.analyzeCurrentModules();
  }

  setupResourceObserver() {
    try {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'resource' && this.isJavaScriptResource(entry)) {
            this.recordResourceMetrics(entry);
          }
        }
      });
      
      observer.observe({ entryTypes: ['resource'] });
    } catch (e) {
      console.warn('Performance Observer for resources not supported:', e);
    }
  }

  isJavaScriptResource(entry) {
    return entry.name.includes('.js') || 
           entry.name.includes('javascript') ||
           entry.initiatorType === 'script';
  }

  recordResourceMetrics(entry) {
    const resourceInfo = {
      name: this.getResourceName(entry.name),
      size: entry.transferSize || entry.encodedBodySize || 0,
      loadTime: entry.responseEnd - entry.requestStart,
      cacheHit: entry.transferSize === 0,
      compression: this.calculateCompressionRatio(entry),
      critical: this.isCriticalResource(entry.name)
    };

    this.modules.set(resourceInfo.name, resourceInfo);
  }

  getResourceName(url) {
    try {
      const urlObj = new URL(url);
      return urlObj.pathname.split('/').pop() || urlObj.pathname;
    } catch {
      return url;
    }
  }

  calculateCompressionRatio(entry) {
    if (entry.decodedBodySize && entry.encodedBodySize) {
      return ((entry.decodedBodySize - entry.encodedBodySize) / entry.decodedBodySize * 100).toFixed(1);
    }
    return 0;
  }

  isCriticalResource(url) {
    const criticalPatterns = [
      'application.js',
      'controllers.js',
      'stimulus',
      'turbo'
    ];
    
    return criticalPatterns.some(pattern => url.includes(pattern));
  }

  trackModuleLoading() {
    // Track dynamic imports
    const originalImport = window.import || eval('import');
    if (originalImport) {
      window.import = async (specifier) => {
        const startTime = performance.now();
        try {
          const module = await originalImport(specifier);
          const loadTime = performance.now() - startTime;
          
          this.recordDynamicImport(specifier, loadTime, true);
          return module;
        } catch (error) {
          const loadTime = performance.now() - startTime;
          this.recordDynamicImport(specifier, loadTime, false);
          throw error;
        }
      };
    }
  }

  recordDynamicImport(specifier, loadTime, success) {
    this.loadTimes.set(specifier, {
      loadTime,
      success,
      timestamp: Date.now()
    });
  }

  async analyzeCurrentModules() {
    // Analyze modules that are already loaded
    const scripts = document.querySelectorAll('script[src]');
    
    for (const script of scripts) {
      await this.analyzeScriptTag(script);
    }
  }

  async analyzeScriptTag(script) {
    const src = script.src;
    if (!src) return;

    try {
      // Get resource details from Performance API
      const entries = performance.getEntriesByName(src, 'resource');
      if (entries.length > 0) {
        this.recordResourceMetrics(entries[0]);
      }
    } catch (error) {
      console.warn(`Failed to analyze script: ${src}`, error);
    }
  }

  generateReport() {
    const report = {
      summary: this.generateSummary(),
      modules: this.generateModuleReport(),
      recommendations: this.generateRecommendations(),
      charts: this.generateChartData(),
      timestamp: new Date().toISOString()
    };

    return report;
  }

  generateSummary() {
    const modules = Array.from(this.modules.values());
    const totalSize = modules.reduce((sum, mod) => sum + mod.size, 0);
    const totalLoadTime = modules.reduce((sum, mod) => sum + mod.loadTime, 0);
    const criticalModules = modules.filter(mod => mod.critical);
    const cachedModules = modules.filter(mod => mod.cacheHit);

    return {
      totalModules: modules.length,
      totalSizeKB: (totalSize / 1024).toFixed(2),
      avgLoadTimeMs: modules.length > 0 ? (totalLoadTime / modules.length).toFixed(2) : 0,
      criticalModules: criticalModules.length,
      cacheHitRate: modules.length > 0 ? (cachedModules.length / modules.length * 100).toFixed(1) : 0,
      compressionSavings: this.calculateTotalCompressionSavings(modules)
    };
  }

  calculateTotalCompressionSavings(modules) {
    const totalSavings = modules.reduce((sum, mod) => {
      return sum + (parseFloat(mod.compression) || 0);
    }, 0);
    
    return modules.length > 0 ? (totalSavings / modules.length).toFixed(1) : 0;
  }

  generateModuleReport() {
    return Array.from(this.modules.entries())
      .map(([name, info]) => ({
        name,
        ...info,
        sizeKB: (info.size / 1024).toFixed(2),
        loadTimeMs: info.loadTime.toFixed(2)
      }))
      .sort((a, b) => b.size - a.size); // Sort by size descending
  }

  generateRecommendations() {
    const recommendations = [];
    const modules = Array.from(this.modules.values());

    // Large modules
    const largeModules = modules.filter(mod => mod.size > 100 * 1024); // > 100KB
    if (largeModules.length > 0) {
      recommendations.push({
        type: 'size',
        priority: 'high',
        title: 'Large Modules Detected',
        description: `${largeModules.length} modules are larger than 100KB. Consider code splitting.`,
        modules: largeModules.map(mod => mod.name)
      });
    }

    // Slow loading modules
    const slowModules = modules.filter(mod => mod.loadTime > 1000); // > 1s
    if (slowModules.length > 0) {
      recommendations.push({
        type: 'performance',
        priority: 'medium',
        title: 'Slow Loading Modules',
        description: `${slowModules.length} modules take more than 1 second to load.`,
        modules: slowModules.map(mod => mod.name)
      });
    }

    // Poor compression
    const poorCompressionModules = modules.filter(mod => 
      parseFloat(mod.compression) < 30 && mod.size > 50 * 1024
    );
    if (poorCompressionModules.length > 0) {
      recommendations.push({
        type: 'compression',
        priority: 'low',
        title: 'Poor Compression Ratio',
        description: 'Some large modules have poor compression. Check server configuration.',
        modules: poorCompressionModules.map(mod => mod.name)
      });
    }

    // Low cache hit rate
    const cacheHitRate = modules.filter(mod => mod.cacheHit).length / modules.length * 100;
    if (cacheHitRate < 50) {
      recommendations.push({
        type: 'caching',
        priority: 'medium',
        title: 'Low Cache Hit Rate',
        description: `Only ${cacheHitRate.toFixed(1)}% of modules are served from cache.`,
        suggestion: 'Review cache headers and Service Worker configuration.'
      });
    }

    return recommendations;
  }

  generateChartData() {
    const modules = Array.from(this.modules.values());
    
    return {
      sizeDistribution: this.generateSizeDistributionData(modules),
      loadTimeDistribution: this.generateLoadTimeDistributionData(modules),
      compressionEffectiveness: this.generateCompressionData(modules),
      criticalVsNonCritical: this.generateCriticalityData(modules)
    };
  }

  generateSizeDistributionData(modules) {
    const ranges = [
      { label: '< 10KB', min: 0, max: 10 * 1024 },
      { label: '10-50KB', min: 10 * 1024, max: 50 * 1024 },
      { label: '50-100KB', min: 50 * 1024, max: 100 * 1024 },
      { label: '100-500KB', min: 100 * 1024, max: 500 * 1024 },
      { label: '> 500KB', min: 500 * 1024, max: Infinity }
    ];

    return ranges.map(range => ({
      label: range.label,
      count: modules.filter(mod => mod.size >= range.min && mod.size < range.max).length
    }));
  }

  generateLoadTimeDistributionData(modules) {
    const ranges = [
      { label: '< 100ms', min: 0, max: 100 },
      { label: '100-500ms', min: 100, max: 500 },
      { label: '500ms-1s', min: 500, max: 1000 },
      { label: '1-2s', min: 1000, max: 2000 },
      { label: '> 2s', min: 2000, max: Infinity }
    ];

    return ranges.map(range => ({
      label: range.label,
      count: modules.filter(mod => mod.loadTime >= range.min && mod.loadTime < range.max).length
    }));
  }

  generateCompressionData(modules) {
    return modules
      .filter(mod => mod.compression > 0)
      .map(mod => ({
        name: mod.name,
        compression: parseFloat(mod.compression),
        size: mod.size
      }))
      .sort((a, b) => b.compression - a.compression);
  }

  generateCriticalityData(modules) {
    const critical = modules.filter(mod => mod.critical);
    const nonCritical = modules.filter(mod => !mod.critical);

    return {
      critical: {
        count: critical.length,
        totalSize: critical.reduce((sum, mod) => sum + mod.size, 0),
        avgLoadTime: critical.length > 0 ? 
          critical.reduce((sum, mod) => sum + mod.loadTime, 0) / critical.length : 0
      },
      nonCritical: {
        count: nonCritical.length,
        totalSize: nonCritical.reduce((sum, mod) => sum + mod.size, 0),
        avgLoadTime: nonCritical.length > 0 ? 
          nonCritical.reduce((sum, mod) => sum + mod.loadTime, 0) / nonCritical.length : 0
      }
    };
  }

  exportReport(format = 'json') {
    const report = this.generateReport();
    
    switch (format) {
      case 'json':
        return JSON.stringify(report, null, 2);
      case 'csv':
        return this.convertToCSV(report.modules);
      case 'console':
        this.logReportToConsole(report);
        return report;
      default:
        return report;
    }
  }

  convertToCSV(modules) {
    const headers = ['Name', 'Size (KB)', 'Load Time (ms)', 'Critical', 'Cache Hit', 'Compression (%)'];
    const rows = modules.map(mod => [
      mod.name,
      mod.sizeKB,
      mod.loadTimeMs,
      mod.critical ? 'Yes' : 'No',
      mod.cacheHit ? 'Yes' : 'No',
      mod.compression
    ]);

    return [headers, ...rows].map(row => row.join(',')).join('\n');
  }

  logReportToConsole(report) {
    console.group('📊 Bundle Analysis Report');
    
    console.group('📋 Summary');
    console.table(report.summary);
    console.groupEnd();

    console.group('📦 Modules');
    console.table(report.modules);
    console.groupEnd();

    if (report.recommendations.length > 0) {
      console.group('💡 Recommendations');
      report.recommendations.forEach(rec => {
        console.warn(`${rec.priority.toUpperCase()}: ${rec.title} - ${rec.description}`);
      });
      console.groupEnd();
    }

    console.groupEnd();
  }

  // Public API methods
  async startAnalysis() {
    console.log('🔍 Starting bundle analysis...');
    await this.analyzeCurrentModules();
    return this.generateReport();
  }

  getQuickStats() {
    return this.generateSummary();
  }

  getRecommendations() {
    return this.generateRecommendations();
  }
}

// Create singleton instance
const bundleAnalyzer = new BundleAnalyzer();

// Export for use in other modules
export default bundleAnalyzer;
