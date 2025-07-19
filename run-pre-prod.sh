#!/bin/bash
# Pre-production Environment - Orzeny Finance Tracker
# Simulates a Heroku-like environment

set -e  # Stop on error

echo "🚀 Starting Orzeny Finance Tracker pre-production environment..."
echo "📦 This environment simulates a Heroku-like configuration"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo "ℹ️  Using 'docker compose' instead of 'docker-compose'"
        DOCKER_COMPOSE="docker compose"
    else
        echo "❌ Docker Compose not found. Install Docker and Docker Compose."
        exit 1
    fi
else
    DOCKER_COMPOSE="docker-compose"
fi

# Stop containers if running
echo "🛑 Stopping existing containers..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml down --remove-orphans

# Build and start
echo "🔨 Building and starting containers..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml up --build -d

# Wait for DB to be ready
echo "⏳ Waiting for database to be ready..."
sleep 15

# Database setup
echo "📊 Setting up database..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:create db:migrate

# Basic app setup
echo "🌱 Loading basic app configurations..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:seed

# Compile assets
echo "🎨 Compiling assets..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails assets:precompile

echo ""
echo "✅ Pre-production environment ready!"
echo ""
echo "🌐 Application: http://localhost:3001"
echo "📊 PostgreSQL: localhost:5433 (postgres/postgres)"
echo "📦 Redis: localhost:6380"
echo "📧 MailCatcher: http://localhost:1080"
echo "⚙️  Sidekiq Web UI: http://localhost:3001/sidekiq"
echo ""
echo "🔍 To view logs:"
echo "   $DOCKER_COMPOSE -f docker-compose.preprod.yml logs -f app"
echo ""
echo "🛑 To stop:"
echo "   $DOCKER_COMPOSE -f docker-compose.preprod.yml down"
echo ""

# Show container status
echo "📋 Container status:"
$DOCKER_COMPOSE -f docker-compose.preprod.yml ps

echo ""
echo "🎯 Environment ready for pre-production testing!"