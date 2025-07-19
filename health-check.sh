#!/bin/bash
# Health Check script for pre-production environment
# Simulates checks that would be performed in production

set -e

HEALTH_CHECK_URL="http://localhost:3001"
SIDEKIQ_WEB_URL="http://localhost:3001/sidekiq"
MAILCATCHER_URL="http://localhost:1080"

echo "🏥 Health Check - Pre-production Environment"
echo "============================================="

# Check if containers are running
echo "📦 Checking containers..."
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

CONTAINERS_STATUS=$($DOCKER_COMPOSE -f docker-compose.preprod.yml ps --format json 2>/dev/null || echo "[]")

if [ "$CONTAINERS_STATUS" = "[]" ]; then
    echo "❌ No containers running"
    echo "💡 Run: ./run-pre-prod.sh"
    exit 1
fi

echo "✅ Containers running"

# Check application connectivity
echo "🌐 Checking web application..."
if curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" | grep -q "200\|302"; then
    echo "✅ Web application responding"
else
    echo "⚠️  Web application not responding"
fi

# Check database
echo "🗄️  Checking database..."
DB_CHECK=$($DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T db psql -U postgres -d orzeny_preprod -c "SELECT 1;" 2>/dev/null || echo "FAIL")
if [[ "$DB_CHECK" == *"1"* ]]; then
    echo "✅ PostgreSQL connecting"
else
    echo "❌ PostgreSQL has issues"
fi

# Check Redis
echo "📦 Checking Redis..."
REDIS_CHECK=$($DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T redis redis-cli ping 2>/dev/null || echo "FAIL")
if [ "$REDIS_CHECK" = "PONG" ]; then
    echo "✅ Redis responding"
else
    echo "❌ Redis has issues"
fi

# Check Sidekiq
echo "⚙️  Checking Sidekiq..."
if curl -s -o /dev/null -w "%{http_code}" "$SIDEKIQ_WEB_URL" | grep -q "200"; then
    echo "✅ Sidekiq Web UI accessible"
else
    echo "⚠️  Sidekiq Web UI not accessible"
fi

# Check MailCatcher
echo "📧 Checking MailCatcher..."
if curl -s -o /dev/null -w "%{http_code}" "$MAILCATCHER_URL" | grep -q "200"; then
    echo "✅ MailCatcher accessible"
else
    echo "⚠️  MailCatcher not accessible"
fi

# System statistics
echo ""
echo "📊 System Statistics:"
echo "===================="

# Container memory usage
echo "💾 Memory usage per container:"
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T app ps aux --sort=-%mem | head -n 10

echo ""
echo "🎯 Important URLs:"
echo "================="
echo "🌐 Application: $HEALTH_CHECK_URL"
echo "⚙️  Sidekiq: $SIDEKIQ_WEB_URL"
echo "📧 MailCatcher: $MAILCATCHER_URL"
echo "🗄️  PostgreSQL: localhost:5433"
echo "📦 Redis: localhost:6380"

echo ""
echo "✅ Health check completed!"
