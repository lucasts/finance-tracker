#!/bin/bash
# Script de Health Check para ambiente de pré-produção
# Simula checks que seriam feitos em produção

set -e

HEALTH_CHECK_URL="http://localhost:3001"
SIDEKIQ_WEB_URL="http://localhost:3001/sidekiq"
MAILCATCHER_URL="http://localhost:1080"

echo "🏥 Health Check - Ambiente Pré-produção"
echo "========================================"

# Verificar se containers estão rodando
echo "📦 Verificando containers..."
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose não encontrado"
    exit 1
fi

CONTAINERS_STATUS=$($DOCKER_COMPOSE -f docker-compose.preprod.yml ps --format json 2>/dev/null || echo "[]")

if [ "$CONTAINERS_STATUS" = "[]" ]; then
    echo "❌ Nenhum container em execução"
    echo "💡 Execute: ./run-pre-prod.sh"
    exit 1
fi

echo "✅ Containers rodando"

# Verificar conectividade da aplicação
echo "🌐 Verificando aplicação web..."
if curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" | grep -q "200\|302"; then
    echo "✅ Aplicação web respondendo"
else
    echo "⚠️  Aplicação web não está respondendo"
fi

# Verificar banco de dados
echo "🗄️  Verificando banco de dados..."
DB_CHECK=$($DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T db psql -U postgres -d orzeny_preprod -c "SELECT 1;" 2>/dev/null || echo "FAIL")
if [[ "$DB_CHECK" == *"1"* ]]; then
    echo "✅ PostgreSQL conectando"
else
    echo "❌ PostgreSQL com problemas"
fi

# Verificar Redis
echo "📦 Verificando Redis..."
REDIS_CHECK=$($DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T redis redis-cli ping 2>/dev/null || echo "FAIL")
if [ "$REDIS_CHECK" = "PONG" ]; then
    echo "✅ Redis respondendo"
else
    echo "❌ Redis com problemas"
fi

# Verificar Sidekiq
echo "⚙️  Verificando Sidekiq..."
if curl -s -o /dev/null -w "%{http_code}" "$SIDEKIQ_WEB_URL" | grep -q "200"; then
    echo "✅ Sidekiq Web UI acessível"
else
    echo "⚠️  Sidekiq Web UI não acessível"
fi

# Verificar MailCatcher
echo "📧 Verificando MailCatcher..."
if curl -s -o /dev/null -w "%{http_code}" "$MAILCATCHER_URL" | grep -q "200"; then
    echo "✅ MailCatcher acessível"
else
    echo "⚠️  MailCatcher não acessível"
fi

# Estatísticas do sistema
echo ""
echo "📊 Estatísticas do Sistema:"
echo "============================"

# Uso de memória dos containers
echo "💾 Uso de memória por container:"
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T app ps aux --sort=-%mem | head -n 10

echo ""
echo "🎯 URLs importantes:"
echo "==================="
echo "🌐 Aplicação: $HEALTH_CHECK_URL"
echo "⚙️  Sidekiq: $SIDEKIQ_WEB_URL"
echo "📧 MailCatcher: $MAILCATCHER_URL"
echo "🗄️  PostgreSQL: localhost:5433"
echo "📦 Redis: localhost:6380"

echo ""
echo "✅ Health check concluído!"
