#!/bin/bash
# Utilitários para o ambiente de pré-produção

set -e

# Verificar se docker-compose está disponível
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        echo "❌ Docker Compose não encontrado."
        exit 1
    fi
else
    DOCKER_COMPOSE="docker-compose"
fi

show_help() {
    echo "🔧 Utilitários Pré-produção - Orzeny Finance Tracker"
    echo ""
    echo "Comandos disponíveis:"
    echo "  start     - Inicia o ambiente de pré-produção"
    echo "  stop      - Para todos os containers"
    echo "  restart   - Reinicia o ambiente"
    echo "  logs      - Mostra logs da aplicação"
    echo "  console   - Abre console Rails no ambiente preprod"
    echo "  shell     - Abre shell no container da aplicação"
    echo "  db        - Conecta ao PostgreSQL"
    echo "  redis     - Conecta ao Redis"
    echo "  jobs      - Força execução dos jobs recorrentes"
    echo "  reset     - Reseta o banco e recarrega seeds"
    echo "  test      - Executa testes no ambiente preprod"
    echo "  status    - Mostra status dos containers"
    echo ""
}

case "${1:-help}" in
    "start")
        echo "🚀 Iniciando ambiente de pré-produção..."
        ./run-pre-prod.sh
        ;;
    "stop")
        echo "🛑 Parando ambiente de pré-produção..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml down
        ;;
    "restart")
        echo "🔄 Reiniciando ambiente..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml restart
        ;;
    "logs")
        echo "📋 Logs da aplicação:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml logs -f app
        ;;
    "console")
        echo "💬 Abrindo console Rails (preprod)..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails console
        ;;
    "shell")
        echo "🐚 Abrindo shell no container..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app bash
        ;;
    "db")
        echo "🗄️  Conectando ao PostgreSQL..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec db psql -U postgres zeno_preprod
        ;;
    "redis")
        echo "📦 Conectando ao Redis..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec redis redis-cli
        ;;
    "jobs")
        echo "⚙️  Executando jobs recorrentes..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails runner "
            puts '🔄 Executando GenerateRecurringTransactionsJob...'
            GenerateRecurringTransactionsJob.perform_now
            puts '✅ Job de transações recorrentes executado!'
            
            puts '🔄 Executando GenerateInstallmentTransactionsJob...'
            GenerateInstallmentTransactionsJob.perform_now
            puts '✅ Job de parcelamentos executado!'
        "
        ;;
    "reset")
        echo "🗑️  Resetando banco de dados..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails db:drop db:create db:migrate
        echo "🌱 Recarregando seeds realistas..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app rails runner "load 'db/seeds/demo_realistic.rb'"
        ;;
    "test")
        echo "🧪 Executando testes no ambiente preprod..."
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app bundle exec rspec
        ;;
    "status")
        echo "📊 Status dos containers:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml ps
        echo ""
        echo "📋 Uso de recursos:"
        $DOCKER_COMPOSE -f docker-compose.preprod.yml exec app ps aux
        ;;
    "help"|*)
        show_help
        ;;
esac
