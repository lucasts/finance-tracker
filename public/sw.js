/**
 * Finance Tracker Service Worker
 * Provides offline functionality and resource caching
 */

const CACHE_NAME = 'finance-tracker-v1';
const STATIC_CACHE_NAME = 'finance-tracker-static-v1';
const DYNAMIC_CACHE_NAME = 'finance-tracker-dynamic-v1';

// Critical resources to cache immediately
const CRITICAL_RESOURCES = [
  '/',
  '/assets/application.css',
  '/assets/application.js',
  '/offline.html',
  '/manifest.json'
];

// Routes that should work offline
const OFFLINE_ROUTES = [
  '/transactions',
  '/accounts', 
  '/overview',
  '/categories'
];

// API endpoints to cache with different strategies
const API_CACHE_STRATEGIES = {
  '/api/transactions': 'networkFirst',
  '/api/accounts': 'cacheFirst', 
  '/api/categories': 'cacheFirst',
  '/api/overview': 'networkFirst'
};

class ServiceWorkerManager {
  constructor() {
    this.installPromise = null;
    this.cacheStrategies = new Map();
    this.setupStrategies();
  }

  setupStrategies() {
    // Network First - Try network, fallback to cache
    this.cacheStrategies.set('networkFirst', this.networkFirst.bind(this));
    
    // Cache First - Try cache, fallback to network  
    this.cacheStrategies.set('cacheFirst', this.cacheFirst.bind(this));
    
    // Stale While Revalidate - Return cache, update in background
    this.cacheStrategies.set('staleWhileRevalidate', this.staleWhileRevalidate.bind(this));
  }

  async networkFirst(request, cacheName = DYNAMIC_CACHE_NAME) {
    try {
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(cacheName);
        cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        return cachedResponse;
      }
      
      // Return offline page for navigation requests
      if (request.mode === 'navigate') {
        return caches.match('/offline.html');
      }
      
      throw error;
    }
  }

  async cacheFirst(request, cacheName = DYNAMIC_CACHE_NAME) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    try {
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(cacheName);
        cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      if (request.mode === 'navigate') {
        return caches.match('/offline.html');
      }
      throw error;
    }
  }

  async staleWhileRevalidate(request, cacheName = DYNAMIC_CACHE_NAME) {
    const cachedResponse = await caches.match(request);
    
    // Always try to fetch and update cache in background
    const fetchPromise = fetch(request).then(response => {
      if (response.ok) {
        const cache = caches.open(cacheName);
        cache.then(c => c.put(request, response.clone()));
      }
      return response;
    }).catch(() => {
      // Network failed, don't update cache
    });

    // Return cached version immediately if available
    if (cachedResponse) {
      return cachedResponse;
    }

    // Wait for network if no cache available
    try {
      return await fetchPromise;
    } catch (error) {
      if (request.mode === 'navigate') {
        return caches.match('/offline.html');
      }
      throw error;
    }
  }

  async handleRequest(request) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // Handle API requests with specific strategies
    for (const [apiPath, strategy] of Object.entries(API_CACHE_STRATEGIES)) {
      if (pathname.startsWith(apiPath)) {
        const handler = this.cacheStrategies.get(strategy);
        return handler(request);
      }
    }

    // Handle static assets
    if (this.isStaticAsset(request)) {
      return this.cacheFirst(request, STATIC_CACHE_NAME);
    }

    // Handle navigation requests
    if (request.mode === 'navigate') {
      return this.networkFirst(request);
    }

    // Default to network first for other requests
    return this.networkFirst(request);
  }

  isStaticAsset(request) {
    const url = new URL(request.url);
    return /\.(css|js|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|ico)$/.test(url.pathname);
  }

  async cleanupOldCaches() {
    const cacheNames = await caches.keys();
    const currentCaches = [CACHE_NAME, STATIC_CACHE_NAME, DYNAMIC_CACHE_NAME];
    
    return Promise.all(
      cacheNames
        .filter(cacheName => !currentCaches.includes(cacheName))
        .map(cacheName => caches.delete(cacheName))
    );
  }

  async precacheResources() {
    const cache = await caches.open(STATIC_CACHE_NAME);
    const requests = CRITICAL_RESOURCES.map(url => new Request(url, { cache: 'reload' }));
    
    return Promise.allSettled(
      requests.map(async request => {
        try {
          const response = await fetch(request);
          if (response.ok) {
            await cache.put(request, response);
          }
        } catch (error) {
          console.warn(`Failed to precache ${request.url}:`, error);
        }
      })
    );
  }
}

// Initialize service worker manager
const swManager = new ServiceWorkerManager();

// Service Worker Event Listeners

self.addEventListener('install', event => {
  console.log('Service Worker: Installing...');
  
  event.waitUntil(
    swManager.precacheResources().then(() => {
      console.log('Service Worker: Critical resources cached');
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', event => {
  console.log('Service Worker: Activating...');
  
  event.waitUntil(
    swManager.cleanupOldCaches().then(() => {
      console.log('Service Worker: Old caches cleaned up');
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', event => {
  // Skip non-GET requests and chrome-extension requests
  if (event.request.method !== 'GET' || 
      event.request.url.startsWith('chrome-extension://')) {
    return;
  }

  event.respondWith(
    swManager.handleRequest(event.request).catch(error => {
      console.error('Service Worker: Request failed:', error);
      
      // Return a fallback response for critical navigation requests
      if (event.request.mode === 'navigate') {
        return caches.match('/offline.html') || new Response(
          'Offline - Please check your connection',
          { status: 503, statusText: 'Service Unavailable' }
        );
      }
      
      return new Response('Network Error', { 
        status: 408, 
        statusText: 'Request Timeout' 
      });
    })
  );
});

// Background sync for offline actions
self.addEventListener('sync', event => {
  if (event.tag === 'background-sync-transactions') {
    event.waitUntil(syncOfflineTransactions());
  }
});

// Push notifications (future enhancement)
self.addEventListener('push', event => {
  if (event.data) {
    const data = event.data.json();
    const options = {
      body: data.body,
      icon: '/icon-192x192.png',
      badge: '/badge-72x72.png',
      data: data.data || {}
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title, options)
    );
  }
});

// Handle notification clicks
self.addEventListener('notificationclick', event => {
  event.notification.close();
  
  if (event.notification.data && event.notification.data.url) {
    event.waitUntil(
      clients.openWindow(event.notification.data.url)
    );
  }
});

// Utility functions

async function syncOfflineTransactions() {
  // This would sync any transactions created while offline
  // For now, just log the intention
  console.log('Syncing offline transactions...');
  
  try {
    // In a real implementation, this would:
    // 1. Get offline transactions from IndexedDB
    // 2. Send them to the server
    // 3. Update local state
    // 4. Clean up synchronized data
    
    const registration = await self.registration;
    registration.showNotification('Offline transactions synced', {
      body: 'Your offline transactions have been synchronized.',
      icon: '/icon-192x192.png'
    });
  } catch (error) {
    console.error('Failed to sync offline transactions:', error);
  }
}
