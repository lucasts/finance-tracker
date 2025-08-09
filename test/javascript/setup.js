/**
 * Jest Test Setup
 * Global configuration and utilities for JavaScript tests
 */

// Mock global objects that might not be available in Jest environment
global.performance = {
  now: () => Date.now(),
  mark: () => {},
  measure: () => {},
  getEntriesByName: () => [],
  getEntriesByType: () => []
};

global.navigator = {
  ...global.navigator,
  onLine: true,
  serviceWorker: {
    register: jest.fn(() => Promise.resolve()),
    ready: Promise.resolve()
  }
};

global.window = {
  ...global.window,
  location: {
    hostname: 'localhost',
    pathname: '/',
    href: 'http://localhost:3000'
  },
  localStorage: {
    getItem: jest.fn(),
    setItem: jest.fn(),
    removeItem: jest.fn(),
    clear: jest.fn()
  },
  sessionStorage: {
    getItem: jest.fn(),
    setItem: jest.fn(),
    removeItem: jest.fn(),
    clear: jest.fn()
  }
};

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
};

// Mock modules that might cause issues in tests
jest.mock('services/intelligent_cache', () => ({
  __esModule: true,
  default: {
    get: jest.fn(() => undefined),
    set: jest.fn(),
    delete: jest.fn(),
    clear: jest.fn(),
    getStats: jest.fn(() => ({ hits: 0, misses: 0, hitRate: 0 }))
  }
}));

jest.mock('utilities/performance_utils', () => ({
  __esModule: true,
  default: {
    measureAndCache: jest.fn((name, operation) => operation()),
    recordMetric: jest.fn(),
    getPerformanceInsights: jest.fn(() => ({}))
  }
}));

// Helper to reset all mocks between tests
beforeEach(() => {
  jest.clearAllMocks();
});

// Helper functions for tests
global.testHelpers = {
  // Create a mock DOM element
  createElement: (tag, attributes = {}) => {
    const element = document.createElement(tag);
    Object.assign(element, attributes);
    return element;
  },

  // Create a mock event
  createEvent: (type, data = {}) => {
    const event = new Event(type);
    Object.assign(event, data);
    return event;
  },

  // Wait for async operations
  waitFor: (ms = 0) => new Promise(resolve => setTimeout(resolve, ms)),

  // Mock fetch responses
  mockFetch: (response) => {
    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(response),
        text: () => Promise.resolve(JSON.stringify(response))
      })
    );
  }
};
