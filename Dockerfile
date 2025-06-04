FROM ruby:3.2.7

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  postgresql-client \
  nodejs \
  npm \
  build-essential \
  libpq-dev

# Install modern Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
  apt-get install -y nodejs

WORKDIR /app

# Bundle dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install Node dependencies
COPY package*.json ./
RUN npm install

# Copy app
COPY . .

# Precompile assets for production-like environment
RUN RAILS_ENV=preprod rails assets:precompile || true

# Create storage directories
RUN mkdir -p storage tmp/pids

EXPOSE 3001

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]