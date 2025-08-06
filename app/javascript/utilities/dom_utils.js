// DOM Utilities
// Modern DOM manipulation utilities with performance optimizations

export class DOMUtils {
  // Efficient element selection with caching
  static cache = new Map();

  static $(selector, context = document) {
    const key = `${selector}-${context === document ? 'doc' : context.tagName}`;
    
    if (!this.cache.has(key)) {
      const element = context.querySelector(selector);
      this.cache.set(key, element);
    }
    
    return this.cache.get(key);
  }

  static $$(selector, context = document) {
    return Array.from(context.querySelectorAll(selector));
  }

  // Clear cache when DOM changes significantly
  static clearCache() {
    this.cache.clear();
  }

  // Create element with attributes and content
  static createElement(tag, attributes = {}, content = '') {
    const element = document.createElement(tag);
    
    Object.entries(attributes).forEach(([key, value]) => {
      if (key === 'className') {
        element.className = value;
      } else if (key === 'dataset') {
        Object.entries(value).forEach(([dataKey, dataValue]) => {
          element.dataset[dataKey] = dataValue;
        });
      } else {
        element.setAttribute(key, value);
      }
    });
    
    if (content) {
      if (typeof content === 'string') {
        element.innerHTML = content;
      } else {
        element.appendChild(content);
      }
    }
    
    return element;
  }

  // Show/hide elements with accessibility
  static show(element, options = {}) {
    const { focusFirst = false, announce = false } = options;
    
    element.hidden = false;
    element.style.display = '';
    element.setAttribute('aria-hidden', 'false');
    
    if (focusFirst) {
      const focusable = element.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
      if (focusable) {
        focusable.focus();
      }
    }
    
    if (announce) {
      this.announceToScreenReader(announce);
    }
  }

  static hide(element, options = {}) {
    const { announce = false } = options;
    
    element.hidden = true;
    element.setAttribute('aria-hidden', 'true');
    
    if (announce) {
      this.announceToScreenReader(announce);
    }
  }

  // Screen reader announcements
  static announceToScreenReader(message) {
    const announcement = this.createElement('div', {
      'aria-live': 'polite',
      'aria-atomic': 'true',
      className: 'sr-only'
    }, message);
    
    document.body.appendChild(announcement);
    
    setTimeout(() => {
      document.body.removeChild(announcement);
    }, 1000);
  }

  // Debounced event handling
  static debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // Throttled event handling
  static throttle(func, limit) {
    let inThrottle;
    return function(...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }

  // Check if element is in viewport
  static isInViewport(element, threshold = 0) {
    const rect = element.getBoundingClientRect();
    const windowHeight = window.innerHeight || document.documentElement.clientHeight;
    const windowWidth = window.innerWidth || document.documentElement.clientWidth;
    
    return (
      rect.top >= -threshold &&
      rect.left >= -threshold &&
      rect.bottom <= windowHeight + threshold &&
      rect.right <= windowWidth + threshold
    );
  }

  // Modern intersection observer wrapper
  static observeVisibility(elements, callback, options = {}) {
    if (!('IntersectionObserver' in window)) {
      // Fallback for older browsers
      return null;
    }

    const observer = new IntersectionObserver(callback, {
      threshold: 0.1,
      rootMargin: '0px',
      ...options
    });

    elements.forEach(element => observer.observe(element));
    
    return observer;
  }

  // Smooth scroll with fallback
  static smoothScrollTo(target, options = {}) {
    const element = typeof target === 'string' ? this.$(target) : target;
    
    if (!element) return;

    if ('scrollBehavior' in document.documentElement.style) {
      element.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
        ...options
      });
    } else {
      // Fallback for older browsers
      element.scrollIntoView();
    }
  }

  // Copy text to clipboard with fallback
  static async copyToClipboard(text) {
    if (navigator.clipboard && window.isSecureContext) {
      try {
        await navigator.clipboard.writeText(text);
        return true;
      } catch (err) {
        console.warn('Clipboard API failed, using fallback');
      }
    }
    
    // Fallback method
    const textArea = this.createElement('textarea', {
      value: text,
      style: 'position: fixed; left: -999999px; top: -999999px;'
    });
    
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    
    try {
      const successful = document.execCommand('copy');
      document.body.removeChild(textArea);
      return successful;
    } catch (err) {
      document.body.removeChild(textArea);
      return false;
    }
  }
}

// Clear DOM cache on Turbo navigation
document.addEventListener('turbo:load', () => {
  DOMUtils.clearCache();
});

export default DOMUtils;
