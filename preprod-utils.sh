#!/bin/bash
# Utilities for pre-production environment

set -e

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        echo "❌ Docker Compose not found."
        exit 1
    fi
else
    DOCKER_COMPOSE="docker-compose"
fi

show_help() {
    echo "🔧 Pre-production Utilities - Orzeny Finance Tracker"
    echo ""
    echo "Available commands:"
    echo "  start     - Start pre-production environment"
    echo "  stop      - Stop all containers"
    echo "  restart   - Restart environment"
    echo "  logs      - Show application logs"
    echo "  console   - Open Rails console in preprod environment"
    echo "  shell     - Open shell in application container"
    echo "  db        - Connect to PostgreSQL"
    echo "  redis     - Connect to Redis"
    echo "  jobs      - Force execution of recurring jobs"
    echo "  reset     - Reset database and reload seeds"
    echo "  test      - Run tests in preprod environment"
    echo "  status    - Show container status"
    echo ""
}

case "${1:-help}" in
    "start")
        echo "🚀 Starting pre-production environment..."
        ./run-pre-prod.sh
        ;;
    "stop")
        echo "🛑 Stopping pre-production environment..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml down
        ;;
    "restart")
        echo "🔄 Restarting environment..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml restart
        ;;
    "logs")
        echo "📋 Application logs:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml logs -f app
        ;;
    "console")
        echo "💬 Opening Rails console (preprod)..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails console
        ;;
    "shell")
        echo "🐚 Opening shell in container..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app bash
        ;;
    "db")
        echo "🗄️  Connecting to PostgreSQL..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec db psql -U postgres orzeny_preprod
        ;;
    "redis")
        echo "📦 Connecting to Redis..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec redis redis-cli
        ;;
    "jobs")
        echo "⚙️  Executing recurring jobs..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails runner "
            puts '🔄 Executing GenerateRecurringTransactionsJob...'
            GenerateRecurringTransactionsJob.perform_now
            puts '✅ Recurring transactions job executed!'
            
            puts '🔄 Executing GenerateInstallmentTransactionsJob...'
            GenerateInstallmentTransactionsJob.perform_now
            puts '✅ Installments job executed!'
        "
        ;;
    "reset")
        echo "🗑️  Resetting database..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:drop db:create db:migrate
        echo "🌱 Reloading realistic seeds..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails runner "load 'db/seeds/demo_realistic.rb'"
        ;;
    "test")
        echo "🧪 Running tests in preprod environment..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app bundle exec rspec
        ;;
    "status")
        echo "📊 Container status:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml ps
        echo ""
        echo "📋 Resource usage:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app ps aux
        ;;
    "help"|*)
        show_help
        ;;
esac
