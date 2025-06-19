#!/bin/bash
# Ambiente de Pré-produção - Orzeny Finance Tracker
# Simula um ambiente Heroku-like

set -e  # Para em caso de erro

echo "🚀 Iniciando ambiente de pré-produção Orzeny Finance Tracker..."
echo "📦 Este ambiente simula uma configuração similar ao Heroku"
echo ""

# Verificar se docker-compose está disponível
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo "ℹ️  Usando 'docker compose' ao invés de 'docker-compose'"
        DOCKER_COMPOSE="docker compose"
    else
        echo "❌ Docker Compose não encontrado. Instale Docker e Docker Compose."
        exit 1
    fi
else
    DOCKER_COMPOSE="docker-compose"
fi

# Para containers se estiverem rodando
echo "🛑 Parando containers existentes..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml down --remove-orphans

# Build e start
echo "🔨 Construindo e iniciando containers..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml up --build -d

# Aguarda DB ficar pronto
echo "⏳ Aguardando banco de dados ficar pronto..."
sleep 15

# Setup do banco
echo "📊 Configurando banco de dados..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:create db:migrate

# Seeds realistas
echo "🌱 Carregando configurações basicas da app ..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:seed

# Compila assets
echo "🎨 Compilando assets..."
$DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails assets:precompile

echo ""
echo "✅ Ambiente de pré-produção pronto!"
echo ""
echo "🌐 Aplicação: http://localhost:3001"
echo "📊 PostgreSQL: localhost:5433 (postgres/postgres)"
echo "📦 Redis: localhost:6380"
echo "📧 MailCatcher: http://localhost:1080"
echo "⚙️  Sidekiq Web UI: http://localhost:3001/sidekiq"
echo ""
echo "🔍 Para ver logs:"
echo "   $DOCKER_COMPOSE -f docker-compose.preprod.yml logs -f app"
echo ""
echo "🛑 Para parar:"
echo "   $DOCKER_COMPOSE -f docker-compose.preprod.yml down"
echo ""

# Mostra status dos containers
echo "📋 Status dos containers:"
$DOCKER_COMPOSE -f docker-compose.preprod.yml ps

echo ""
echo "🎯 Ambiente pronto para testes de pré-produção!"