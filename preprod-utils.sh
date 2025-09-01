#!/bin/bash
# Preprod Environment Management Utilities for Finance Tracker

PREPROD_IP="192.168.88.15"
PREPROD_USER="root"
REMOTE_PATH="/mnt/user/appdata/finance-tracker"
SSH_KEY="~/.ssh/id_ed25519_unraid_deploy"

show_help() {
    echo "🚀 Preprod Finance Tracker Management"
    echo ""
    echo "Available commands:"
    echo "  deploy    - Full deployment to preprod environment"
    echo "  start     - Start all containers"
    echo "  stop      - Stop all containers"
    echo "  restart   - Restart all containers"
    echo "  logs      - Show application logs"
    echo "  console   - Open Rails console"
    echo "  shell     - Open shell in app container"
    echo "  status    - Show containers status"
    echo "  sync      - Sync code only (no rebuild)"
    echo "  rebuild   - Force rebuild containers"
    echo "  reset     - Reset database with fresh data"
    echo "  cleanup   - Remove stopped containers and unused images"
    echo ""
}

run_remote() {
    ssh -i $SSH_KEY $PREPROD_USER@$PREPROD_IP "cd $REMOTE_PATH && $1"
}

case "${1:-help}" in
    "deploy")
        echo "🚀 Running full deployment..."
        ./deploy-preprod.sh
        ;;
    "start")
        echo "▶️  Starting containers on preprod environment..."
        run_remote "docker-compose -f docker-compose.preprod.yml up -d"
        ;;
    "stop")
        echo "⏹️  Stopping containers on preprod environment..."
        run_remote "docker-compose -f docker-compose.preprod.yml down"
        ;;
    "restart")
        echo "🔄 Restarting containers on preprod environment..."
        run_remote "docker-compose -f docker-compose.preprod.yml restart"
        ;;
    "logs")
        echo "📋 Showing application logs..."
        if [[ "$2" == "app" ]]; then
            run_remote "docker-compose -f docker-compose.preprod.yml logs ${3:-} ${4:-} app"
        else
            run_remote "docker-compose -f docker-compose.preprod.yml logs -f app"
        fi
        ;;
    "console")
        echo "💬 Opening Rails console..."
        ssh -t -i $SSH_KEY $PREPROD_USER@$PREPROD_IP "cd $REMOTE_PATH && docker-compose -f docker-compose.preprod.yml exec app rails console"
        ;;
    "shell")
        echo "🐚 Opening shell in app container..."
        ssh -t -i $SSH_KEY $PREPROD_USER@$PREPROD_IP "cd $REMOTE_PATH && docker-compose -f docker-compose.preprod.yml exec app bash"
        ;;
    "status")
        echo "📊 Container status on preprod environment:"
        run_remote "docker-compose -f docker-compose.preprod.yml ps"
        echo ""
        echo "🌐 URLs:"
        echo "   App: http://$PREPROD_IP:8000"
        echo "   Sidekiq: http://$PREPROD_IP:8000/sidekiq"
        echo "   MailCatcher: http://$PREPROD_IP:1081"
        ;;
    "sync")
        echo "📦 Syncing code to preprod environment (no rebuild)..."
        rsync -avz --delete \
            --exclude='.git/' \
            --exclude='node_modules/' \
            --exclude='tmp/' \
            --exclude='log/' \
            --exclude='coverage/' \
            --exclude='storage/' \
            --exclude='.env.local' \
            --exclude='*.log' \
            ./ $PREPROD_USER@$PREPROD_IP:$REMOTE_PATH/
        echo "✅ Code synced. Run 'restart' if needed."
        ;;
    "rebuild")
        echo "🔨 Force rebuilding containers..."
        run_remote "docker-compose -f docker-compose.preprod.yml down"
        run_remote "docker-compose -f docker-compose.preprod.yml build --no-cache"
        run_remote "docker-compose -f docker-compose.preprod.yml up -d"
        ;;
    "reset")
        echo "🗑️  Resetting database with fresh data..."
        run_remote "docker-compose -f docker-compose.preprod.yml exec app rails db:drop db:create db:migrate db:seed"
        ;;
    "cleanup")
        echo "🧹 Cleaning up Docker resources..."
        run_remote "docker system prune -f"
        run_remote "docker volume prune -f"
        ;;
    "help"|*)
        show_help
        ;;
esac
