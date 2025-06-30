// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "./helpers/currency_helper"  // ✅ REFACTOR: Import centralized currency helper
