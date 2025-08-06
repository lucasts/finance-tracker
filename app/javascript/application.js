// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import appInitializer from "initializers/app_initializer"
import ApexCharts from "apexcharts"

// Make ApexCharts available globally
window.ApexCharts = ApexCharts

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  appInitializer.initializeAll();
});

// Handle Turbo navigation
document.addEventListener('turbo:load', () => {
  // Re-initialize components that need it after navigation
  document.dispatchEvent(new CustomEvent('app:turbo-load'));
});

// Handle before cache for Turbo
document.addEventListener('turbo:before-cache', () => {
  // Clean up any temporary states before caching
  document.dispatchEvent(new CustomEvent('app:before-cache'));
});
