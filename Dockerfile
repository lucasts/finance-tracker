# Multi-stage build for optimized production image
FROM ruby:3.4.2 as builder

# Install dependencies for building
RUN apt-get update -qq && apt-get install -y \
  postgresql-client \
  nodejs \
  npm \
  build-essential \
  libpq-dev \
  curl

# Install modern Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
  apt-get install -y nodejs

WORKDIR /app

# Bundle dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Install Node dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy app
COPY . .

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_key_for_asset_compilation
RUN bundle exec rails assets:precompile

# Production stage
FROM ruby:3.4.2-slim as production

# Install runtime dependencies
RUN apt-get update -qq && apt-get install -y \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gems from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app and precompiled assets
COPY --from=builder /app .

# Create storage directories
RUN mkdir -p storage tmp/pids log

# Set environment variables
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true

# Create user for security
RUN groupadd -r rails && useradd -r -g rails rails
RUN chown -R rails:rails /app
USER rails

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]