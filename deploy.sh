#!/bin/bash

# Production deployment script
# This script helps deploy the application to production

set -e

echo "🚀 Starting production deployment..."

# Check if required environment variables are set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "❌ SECRET_KEY_BASE environment variable is required"
    exit 1
fi

if [ -z "$RAILS_MASTER_KEY" ]; then
    echo "❌ RAILS_MASTER_KEY environment variable is required"
    exit 1
fi

if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL environment variable is required"
    exit 1
fi

echo "✅ Environment variables validated"

# Build the Docker image
echo "🏗️  Building Docker image..."
docker build -t finance-tracker:latest .

echo "🔄 Starting services..."
docker-compose up -d

echo "⏳ Waiting for database to be ready..."
sleep 10

echo "🗄️  Running database migrations..."
docker-compose exec app bundle exec rails db:create db:migrate

echo "🌱 Running database seeds (if needed)..."
docker-compose exec app bundle exec rails db:seed

echo "✅ Deployment completed successfully!"
echo "🌐 Application is running at http://localhost:3000"
echo "📊 Health check available at http://localhost:3000/up"
