import { Application } from "@hotwired/stimulus"
import ASSET_CONFIG from "config/assets"

const application = Application.start()

// Detect development environment
const isDevelopment = window.location.hostname === 'localhost' || 
                     window.location.hostname === '127.0.0.1' ||
                     window.location.hostname.includes('gitpod') ||
                     window.location.hostname.includes('codespace');

// Configure Stimulus with modern settings
application.debug = ASSET_CONFIG.performance.preloadCriticalAssets ? false : true
application.warnings = isDevelopment

// Add global utilities to window for controller access
window.Stimulus = application

// Performance monitoring
if (ASSET_CONFIG.performance.preloadCriticalAssets) {
  application.logDebugActivity = (identifier, functionName, detail = {}) => {
    if (application.debug) {
      console.log(`[Stimulus] ${identifier}#${functionName}`, detail)
    }
  }
}

// Global error handling for controllers
application.handleError = (error, message, detail) => {
  console.error(`[Stimulus Error] ${message}`, error, detail)
  
  // In production, send to error tracking service
  if (!isDevelopment) {
    // Future: Send to error tracking service
    console.warn('Error would be sent to tracking service:', { error, message, detail })
  }
}

export { application }
