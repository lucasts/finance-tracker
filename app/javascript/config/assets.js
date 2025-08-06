// Assets Configuration
// Centralized configuration for frontend assets management

export const ASSET_CONFIG = {
  // Feature flags for progressive enhancement
  features: {
    animations: true,
    chartLibrary: 'apexcharts',
    currencyFormatting: 'unified',
    darkMode: false, // Future enhancement
    offlineSupport: false // Future enhancement
  },

  // Performance settings
  performance: {
    lazyLoadImages: true,
    preloadCriticalAssets: true,
    enableServiceWorker: false // Future enhancement
  },

  // Chart configuration
  charts: {
    defaultTheme: 'light',
    colors: {
      primary: 'hsl(var(--p))',
      secondary: 'hsl(var(--s))', 
      success: 'hsl(var(--su))',
      warning: 'hsl(var(--wa))',
      error: 'hsl(var(--er))',
      info: 'hsl(var(--in))'
    },
    animations: {
      enabled: true,
      speed: 'normal'
    }
  },

  // Form settings
  forms: {
    autoSave: false, // Future enhancement
    realTimeValidation: true,
    currencyMasking: true
  },

  // API endpoints for dynamic content
  endpoints: {
    charts: '/api/charts',
    transactions: '/api/transactions',
    accounts: '/api/accounts'
  }
};

// Environment-specific overrides
// Detect development environment by checking if we're on localhost
const isDevelopment = window.location.hostname === 'localhost' || 
                     window.location.hostname === '127.0.0.1' ||
                     window.location.hostname.includes('gitpod') ||
                     window.location.hostname.includes('codespace');

if (isDevelopment) {
  ASSET_CONFIG.performance.preloadCriticalAssets = false;
  ASSET_CONFIG.charts.animations.enabled = false; // Faster development
}

export default ASSET_CONFIG;
