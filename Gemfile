source "https://rubygems.org"

ruby "4.0.1"

# Core Rails
gem "rails", "~> 8.1.2"

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
gem "pg", "~> 1.1" # PostgreSQL for all environments
gem "stimulus-rails" # Stimulus JS
gem "turbo-rails" # Hotwire Turbo

gem "csv" # CSV parsing (required in Rails 8)
gem "ostruct" # OpenStruct (removed from stdlib in Ruby 4.0)

# sqlite3 kept as optional dependency (no longer used for dev/test)
# gem "sqlite3", ">= 1.4"

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
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "web-console"
end

group :test do
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
end
