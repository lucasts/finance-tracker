/**
 * Service Worker Registration and Management
 * Handles SW lifecycle and provides offline capabilities
 */

class ServiceWorkerRegistration {
  constructor() {
    this.registration = null;
    this.isSupported = 'serviceWorker' in navigator;
    this.isOnline = navigator.onLine;
    this.setupConnectionListeners();
  }

  async register() {
    if (!this.isSupported) {
      console.warn('Service Worker not supported in this browser');
      return false;
    }

    try {
      this.registration = await navigator.serviceWorker.register('/sw.js', {
        scope: '/'
      });

      console.log('Service Worker registered successfully:', this.registration);

      // Handle updates
      this.registration.addEventListener('updatefound', () => {
        this.handleUpdate();
      });

      // Listen for messages from SW
      navigator.serviceWorker.addEventListener('message', (event) => {
        this.handleServiceWorkerMessage(event);
      });

      return true;
    } catch (error) {
      console.error('Service Worker registration failed:', error);
      return false;
    }
  }

  handleUpdate() {
    const installingWorker = this.registration.installing;
    
    if (installingWorker) {
      installingWorker.addEventListener('statechange', () => {
        if (installingWorker.state === 'installed') {
          if (navigator.serviceWorker.controller) {
            // New content available
            this.showUpdateNotification();
          } else {
            // Content cached for first time
            this.showCacheReadyNotification();
          }
        }
      });
    }
  }

  showUpdateNotification() {
    // Show user-friendly update notification
    const notification = document.createElement('div');
    notification.className = 'alert alert-info fixed top-4 right-4 z-50 shadow-lg';
    notification.innerHTML = `
      <div>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <div>
          <h3 class="font-bold">Nova versão disponível!</h3>
          <div class="text-xs">Atualize para obter as últimas melhorias.</div>
        </div>
      </div>
      <div class="flex-none">
        <button class="btn btn-sm btn-primary" onclick="this.parentElement.parentElement.updateApp()">
          Atualizar
        </button>
        <button class="btn btn-sm btn-ghost" onclick="this.parentElement.parentElement.remove()">
          Depois
        </button>
      </div>
    `;
    
    notification.updateApp = () => {
      if (this.registration && this.registration.waiting) {
        this.registration.waiting.postMessage({ action: 'skipWaiting' });
        window.location.reload();
      }
    };

    document.body.appendChild(notification);

    // Auto-remove after 30 seconds if not interacted with
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove();
      }
    }, 30000);
  }

  showCacheReadyNotification() {
    console.log('App cached for offline use');
    
    // Show a subtle notification that app is ready for offline use
    const notification = document.createElement('div');
    notification.className = 'toast toast-end';
    notification.innerHTML = `
      <div class="alert alert-success">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span>App ready for offline use!</span>
      </div>
    `;

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.remove();
    }, 5000);
  }

  setupConnectionListeners() {
    window.addEventListener('online', () => {
      this.isOnline = true;
      this.handleOnline();
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
      this.handleOffline();
    });
  }

  handleOnline() {
    console.log('Back online');
    
    // Trigger background sync if supported
    if (this.registration && 'sync' in this.registration) {
      this.registration.sync.register('background-sync-transactions');
    }

    // Update UI to show online status
    document.dispatchEvent(new CustomEvent('app:online'));
  }

  handleOffline() {
    console.log('Gone offline');
    
    // Update UI to show offline status
    document.dispatchEvent(new CustomEvent('app:offline'));
  }

  handleServiceWorkerMessage(event) {
    const { data } = event;
    
    switch (data.type) {
      case 'CACHE_UPDATED':
        console.log('Cache updated for:', data.url);
        break;
      case 'OFFLINE_READY':
        console.log('App ready for offline use');
        break;
      case 'SYNC_COMPLETE':
        console.log('Background sync completed');
        this.showSyncNotification();
        break;
    }
  }

  showSyncNotification() {
    const notification = document.createElement('div');
    notification.className = 'toast toast-end';
    notification.innerHTML = `
      <div class="alert alert-success">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
        <span>Dados sincronizados!</span>
      </div>
    `;

    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 3000);
  }

  // Send message to service worker
  sendMessage(message) {
    if (this.registration && this.registration.active) {
      this.registration.active.postMessage(message);
    }
  }

  // Check if we're running in offline mode
  isOfflineCapable() {
    return this.isSupported && this.registration;
  }

  // Get cache status
  async getCacheStatus() {
    if (!('caches' in window)) return null;

    try {
      const cacheNames = await caches.keys();
      const cachePromises = cacheNames.map(async name => {
        const cache = await caches.open(name);
        const keys = await cache.keys();
        return { name, count: keys.length };
      });

      const cacheStatus = await Promise.all(cachePromises);
      return {
        supported: true,
        caches: cacheStatus,
        totalItems: cacheStatus.reduce((sum, cache) => sum + cache.count, 0)
      };
    } catch (error) {
      console.error('Error getting cache status:', error);
      return null;
    }
  }
}

// Create global instance
const serviceWorkerManager = new ServiceWorkerRegistration();

// Auto-register when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  serviceWorkerManager.register();
});

// Export for use in other modules
export default serviceWorkerManager;
