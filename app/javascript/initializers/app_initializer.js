// Application Initializer
// Centralized initialization system for all frontend modules

import { application } from "controllers/application"
import ASSET_CONFIG from "config/assets"
import intelligentCache from "services/intelligent_cache"
import performanceUtils from "utilities/performance_utils"

class AppInitializer {
  constructor() {
    this.config = ASSET_CONFIG;
    this.modules = new Map();
    this.initialized = false;
  }

  // Register a module for initialization
  registerModule(name, initFunction, dependencies = []) {
    this.modules.set(name, {
      init: initFunction,
      dependencies,
      initialized: false
    });
  }

  // Initialize all registered modules in dependency order
  async initializeAll() {
    if (this.initialized) return;

    console.log('🚀 Initializing Finance Tracker Frontend...');
    
    try {
      // Initialize core modules first
      await this.initializeCoreModules();
      
      // Initialize feature modules
      await this.initializeFeatureModules();
      
      // Initialize third-party integrations
      await this.initializeIntegrations();
      
      this.initialized = true;
      console.log('✅ Frontend initialization complete');
      
      // Dispatch ready event
      document.dispatchEvent(new CustomEvent('app:ready', {
        detail: { config: this.config }
      }));
      
    } catch (error) {
      console.error('❌ Frontend initialization failed:', error);
      this.handleInitializationError(error);
    }
  }

  async initializeCoreModules() {
    // Initialize Stimulus application
    if (!application.started) {
      application.start();
    }

    // Initialize intelligent caching system
    console.log('📦 Setting up intelligent caching...');
    this.setupCachePreloading();

    // Set up global error handling
    this.setupErrorHandling();

    // Initialize performance monitoring
    console.log('📊 Setting up performance monitoring...');
    this.setupPerformanceMonitoring();
  }

  async initializeFeatureModules() {
    // Initialize animations if enabled
    if (this.config.features.animations) {
      await this.initializeAnimations();
    }

    // Initialize chart library
    if (this.config.features.chartLibrary) {
      await this.initializeCharts();
    }

    // Initialize progressive enhancement features
    await this.initializeProgressiveEnhancement();
  }

  async initializeIntegrations() {
    // Future: Service Worker, Analytics, etc.
    if (this.config.performance.enableServiceWorker) {
      await this.initializeServiceWorker();
    }
  }

  async initializeAnimations() {
    // Set up CSS animation preferences
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    
    if (prefersReducedMotion.matches) {
      document.documentElement.classList.add('reduce-motion');
      this.config.features.animations = false;
    }

    // Listen for changes in motion preferences
    prefersReducedMotion.addEventListener('change', (e) => {
      if (e.matches) {
        document.documentElement.classList.add('reduce-motion');
        this.config.features.animations = false;
      } else {
        document.documentElement.classList.remove('reduce-motion');
        this.config.features.animations = true;
      }
    });
  }

  async initializeCharts() {
    // Set up chart defaults based on configuration
    if (window.ApexCharts) {
      window.ApexCharts.exec = window.ApexCharts.exec || function() {};
    }
  }

  async initializeProgressiveEnhancement() {
    // Add classes for feature detection
    document.documentElement.classList.add('js-enabled');
    
    if ('serviceWorker' in navigator) {
      document.documentElement.classList.add('sw-supported');
    }
    
    if ('IntersectionObserver' in window) {
      document.documentElement.classList.add('intersection-observer');
    }
  }

  async initializeServiceWorker() {
    // Future enhancement
    console.log('Service Worker initialization would go here');
  }

  setupErrorHandling() {
    // Global error handler for unhandled JavaScript errors
    window.addEventListener('error', (event) => {
      console.error('Unhandled error:', event.error);
      this.logError('javascript', event.error);
    });

    // Global handler for unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      console.error('Unhandled promise rejection:', event.reason);
      this.logError('promise', event.reason);
    });
  }

  setupCachePreloading() {
    // Preload critical application data
    intelligentCache.preload([
      {
        key: 'currency-formatter-config',
        loader: () => Promise.resolve(this.config.currency),
        priority: 3
      },
      {
        key: 'user-preferences',
        loader: () => this.loadUserPreferences(),
        priority: 2
      }
    ]);

    // Set up cache invalidation on navigation
    document.addEventListener('turbo:before-cache', () => {
      intelligentCache.invalidateByTag('temporary');
    });
  }

  setupPerformanceMonitoring() {
    // Monitor cache performance
    setInterval(() => {
      const insights = performanceUtils.getPerformanceInsights();
      console.debug('Performance insights:', insights);
      
      // Auto-optimize based on insights
      if (insights.recommendations.length > 0) {
        console.info('Performance recommendations:', insights.recommendations);
      }
    }, 60000); // Every minute

    // Smart preloading based on user behavior
    this.setupBehaviorTracking();
  }

  setupBehaviorTracking() {
    let navigationPattern = [];
    
    document.addEventListener('turbo:load', () => {
      const currentPath = window.location.pathname;
      navigationPattern.push({
        path: currentPath,
        timestamp: Date.now()
      });

      // Keep only last 10 navigation events
      if (navigationPattern.length > 10) {
        navigationPattern = navigationPattern.slice(-10);
      }

      // Analyze patterns and preload likely next pages
      this.analyzeAndPreload(navigationPattern);
    });
  }

  analyzeAndPreload(pattern) {
    // Simple pattern analysis - in production this would be more sophisticated
    const recentPaths = pattern.slice(-3).map(p => p.path);
    const commonPatterns = [
      ['/transactions', '/accounts'],
      ['/accounts', '/transactions'],
      ['/overview', '/transactions'],
      ['/import_sessions', '/transactions']
    ];

    for (const [from, to] of commonPatterns) {
      if (recentPaths.includes(from) && !recentPaths.includes(to)) {
        // Preload likely next page data
        this.preloadPageData(to);
      }
    }
  }

  preloadPageData(path) {
    // This would preload critical data for the path
    // For now, just log the intention
    console.debug(`Would preload data for: ${path}`);
  }

  loadUserPreferences() {
    // Load user preferences from localStorage or API
    const stored = localStorage.getItem('user-preferences');
    return stored ? JSON.parse(stored) : {
      theme: 'auto',
      animations: true,
      currency: 'BRL'
    };
  }

  logError(type, error) {
    // In production, this would send to error tracking service
    const errorData = {
      type,
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      url: window.location.href
    };
    
    console.warn('Error logged:', errorData);
  }

  handleInitializationError(error) {
    // Fallback to basic functionality
    document.documentElement.classList.add('initialization-failed');
    
    // Show user-friendly message
    const errorElement = document.createElement('div');
    errorElement.className = 'alert alert-warning fixed top-4 right-4 z-50';
    errorElement.innerHTML = `
      <div>
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <span>Some features may be limited. Please refresh the page.</span>
      </div>
    `;
    
    document.body.appendChild(errorElement);
    
    // Auto-remove after 10 seconds
    setTimeout(() => {
      errorElement.remove();
    }, 10000);
  }
}

// Create global initializer instance
const appInitializer = new AppInitializer();

// Export for use in application.js
export { appInitializer, AppInitializer };
export default appInitializer;
