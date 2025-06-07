source "https://rubygems.org"

ruby "3.4.2"

# Core Rails
# Use edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.0"

gem "apexcharts" # Charting

# Performance
gem "bootsnap", require: false

gem "devise" # Authentication

gem "groupdate" # Date grouping for analytics
gem "importmap-rails" # ESM import maps for JS
gem "jbuilder" # JSON APIs
gem "puma", ">= 5.0" # Web server
gem "redis", ">= 4.0.1" # Redis client
gem "sidekiq" # Background jobs
gem "sprockets-rails" # Asset pipeline
gem "sqlite3", ">= 1.4" # Default DB for dev/test
gem "stimulus-rails" # Stimulus JS
gem "tailwindcss-rails" # Tailwind CSS
gem "turbo-rails" # Hotwire Turbo

gem "csv" # CSV parsing (required in Rails 8)

# PostgreSQL for preprod/production
gem "pg", "~> 1.1", group: [:preprod, :production]

# Windows/JRuby: timezone support
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Development & Test

group :development, :test do
  gem "factory_bot_rails"
  gem "faker"
  gem "rails-controller-testing"
  gem "rspec-rails"
  gem "shoulda-matchers"
end

group :development do
  gem "web-console"
end

group :test do
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
end
