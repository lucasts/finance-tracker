/**
 * Resource Preloader - Intelligent preloading of critical resources
 * Implements various preloading strategies for improved performance
 */

class ResourcePreloader {
  constructor() {
    this.preloadedResources = new Set();
    this.preloadQueue = [];
    this.isPreloading = false;
    this.priorities = {
      critical: 1,
      high: 2,
      medium: 3,
      low: 4
    };
    
    // Initialize preloading strategies
    this.setupIntersectionObserver();
    this.setupIdlePreloading();
  }

  /**
   * Preload critical resources immediately
   */
  preloadCritical() {
    const criticalResources = [
      { href: '/assets/application.css', as: 'style', priority: 'critical' },
      { href: '/assets/application.js', as: 'script', priority: 'critical' },
      { href: '/favicon.ico', as: 'image', priority: 'high' }
    ];

    criticalResources.forEach(resource => {
      this.preloadResource(resource);
    });
  }

  /**
   * Preload resources based on user navigation patterns
   */
  preloadBasedOnBehavior(navigationHistory = []) {
    const likelyNextPages = this.predictNextPages(navigationHistory);
    
    likelyNextPages.forEach(page => {
      this.preloadPage(page.url, page.priority);
    });
  }

  /**
   * Preload page resources
   */
  preloadPage(url, priority = 'medium') {
    // Preload the HTML
    this.preloadResource({
      href: url,
      as: 'document',
      priority
    });

    // Preload likely page-specific assets
    const pageAssets = this.getPageSpecificAssets(url);
    pageAssets.forEach(asset => {
      this.preloadResource(asset);
    });
  }

  /**
   * Preload a single resource
   */
  preloadResource(resource) {
    if (this.preloadedResources.has(resource.href)) {
      return; // Already preloaded
    }

    const { href, as, type, priority = 'medium', crossOrigin } = resource;

    // Create preload link
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = href;
    link.as = as;
    
    if (type) link.type = type;
    if (crossOrigin) link.crossOrigin = crossOrigin;

    // Set priority if supported
    if ('fetchPriority' in link) {
      link.fetchPriority = this.mapPriorityToFetchPriority(priority);
    }

    // Add to queue based on priority
    this.addToQueue(link, priority);
  }

  /**
   * Preload images that are likely to be viewed
   */
  preloadImages(selector = 'img[data-src]') {
    const images = document.querySelectorAll(selector);
    
    images.forEach(img => {
      if (this.shouldPreloadImage(img)) {
        this.preloadResource({
          href: img.dataset.src,
          as: 'image',
          priority: 'low'
        });
      }
    });
  }

  /**
   * Preload fonts early to prevent FOUT
   */
  preloadFonts() {
    const fontResources = [
      {
        href: '/assets/fonts/system-font.woff2',
        as: 'font',
        type: 'font/woff2',
        crossOrigin: 'anonymous',
        priority: 'high'
      }
    ];

    fontResources.forEach(font => {
      this.preloadResource(font);
    });
  }

  /**
   * Prefetch resources for future navigation
   */
  prefetchResources(resources) {
    resources.forEach(resource => {
      this.createPrefetchLink(resource);
    });
  }

  createPrefetchLink(resource) {
    if (this.preloadedResources.has(`prefetch:${resource.href}`)) {
      return;
    }

    const link = document.createElement('link');
    link.rel = 'prefetch';
    link.href = resource.href;
    
    if (resource.as) link.as = resource.as;

    document.head.appendChild(link);
    this.preloadedResources.add(`prefetch:${resource.href}`);
  }

  // Private methods

  addToQueue(link, priority) {
    const priorityLevel = this.priorities[priority] || this.priorities.medium;
    
    this.preloadQueue.push({
      link,
      priority: priorityLevel,
      timestamp: Date.now()
    });

    // Sort queue by priority
    this.preloadQueue.sort((a, b) => a.priority - b.priority);

    this.processQueue();
  }

  async processQueue() {
    if (this.isPreloading || this.preloadQueue.length === 0) {
      return;
    }

    this.isPreloading = true;

    while (this.preloadQueue.length > 0) {
      const item = this.preloadQueue.shift();
      await this.executePreload(item.link);
      
      // Add small delay to prevent overwhelming the browser
      await new Promise(resolve => setTimeout(resolve, 10));
    }

    this.isPreloading = false;
  }

  executePreload(link) {
    return new Promise((resolve) => {
      link.onload = () => {
        this.preloadedResources.add(link.href);
        resolve();
      };
      
      link.onerror = () => {
        console.warn(`Failed to preload: ${link.href}`);
        resolve();
      };

      document.head.appendChild(link);
      
      // Timeout after 5 seconds
      setTimeout(resolve, 5000);
    });
  }

  mapPriorityToFetchPriority(priority) {
    const mapping = {
      critical: 'high',
      high: 'high',
      medium: 'auto',
      low: 'low'
    };
    
    return mapping[priority] || 'auto';
  }

  predictNextPages(navigationHistory) {
    // Simple prediction based on common patterns
    const currentPath = window.location.pathname;
    const predictions = [];

    // Common navigation patterns
    const patterns = {
      '/': [
        { url: '/transactions', priority: 'high' },
        { url: '/overview', priority: 'medium' },
        { url: '/accounts', priority: 'medium' }
      ],
      '/transactions': [
        { url: '/transactions/new', priority: 'high' },
        { url: '/accounts', priority: 'medium' },
        { url: '/categories', priority: 'low' }
      ],
      '/accounts': [
        { url: '/transactions', priority: 'high' },
        { url: '/accounts/new', priority: 'medium' }
      ],
      '/overview': [
        { url: '/transactions', priority: 'high' },
        { url: '/reports', priority: 'medium' }
      ]
    };

    return patterns[currentPath] || [];
  }

  getPageSpecificAssets(url) {
    // Return likely assets for specific pages
    const pageAssets = {
      '/transactions': [
        { href: '/assets/chart-library.js', as: 'script', priority: 'medium' }
      ],
      '/overview': [
        { href: '/assets/chart-library.js', as: 'script', priority: 'high' },
        { href: '/assets/dashboard.css', as: 'style', priority: 'medium' }
      ],
      '/reports': [
        { href: '/assets/chart-library.js', as: 'script', priority: 'high' }
      ]
    };

    return pageAssets[url] || [];
  }

  shouldPreloadImage(img) {
    // Check if image is above the fold or likely to be viewed soon
    const rect = img.getBoundingClientRect();
    const viewportHeight = window.innerHeight;
    
    // Preload if within 2 viewport heights
    return rect.top < viewportHeight * 2;
  }

  setupIntersectionObserver() {
    if (!('IntersectionObserver' in window)) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const element = entry.target;
            
            // Preload links that come into view
            if (element.tagName === 'A' && element.href) {
              this.preloadPage(element.href, 'low');
            }
            
            // Preload images
            if (element.tagName === 'IMG' && element.dataset.src) {
              this.preloadResource({
                href: element.dataset.src,
                as: 'image',
                priority: 'low'
              });
            }
          }
        });
      },
      {
        rootMargin: '50px' // Start preloading 50px before element comes into view
      }
    );

    // Observe links and lazy images
    document.querySelectorAll('a[href], img[data-src]').forEach(el => {
      observer.observe(el);
    });
  }

  setupIdlePreloading() {
    // Preload during browser idle time
    if ('requestIdleCallback' in window) {
      const idlePreload = (deadline) => {
        while (deadline.timeRemaining() > 0 && this.preloadQueue.length > 0) {
          const item = this.preloadQueue.shift();
          this.executePreload(item.link);
        }
        
        // Schedule next idle callback
        requestIdleCallback(idlePreload, { timeout: 2000 });
      };
      
      requestIdleCallback(idlePreload, { timeout: 2000 });
    }
  }

  // Public API

  /**
   * Initialize preloading for the current page
   */
  initializeForPage() {
    console.log('🚀 Initializing resource preloading...');
    
    // Preload critical resources first
    this.preloadCritical();
    
    // Preload fonts to prevent FOUT
    this.preloadFonts();
    
    // Preload based on page type
    this.preloadBasedOnBehavior();
    
    // Setup lazy image preloading
    this.preloadImages();
  }

  /**
   * Get preloading statistics
   */
  getStats() {
    return {
      preloadedCount: this.preloadedResources.size,
      queueLength: this.preloadQueue.length,
      isActive: this.isPreloading,
      preloadedResources: Array.from(this.preloadedResources)
    };
  }

  /**
   * Clear preload cache
   */
  clearCache() {
    this.preloadedResources.clear();
    this.preloadQueue = [];
    console.log('🧹 Preload cache cleared');
  }
}

// Create singleton instance
const resourcePreloader = new ResourcePreloader();

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  resourcePreloader.initializeForPage();
});

// Re-initialize on navigation
document.addEventListener('turbo:load', () => {
  resourcePreloader.initializeForPage();
});

export default resourcePreloader;
