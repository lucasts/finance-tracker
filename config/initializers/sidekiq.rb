require "sidekiq/web"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/1" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/1" }
end

# Configure Sidekiq web dashboard (optional, for monitoring)
if Rails.env.development? || Rails.env.preprod?
  Rails.application.routes.prepend do
    mount Sidekiq::Web => "/sidekiq"
  end
end
