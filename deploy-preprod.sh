#!/bin/bash
# Deploy Finance Tracker to Preprod Environment  
# Usage: ./deploy-preprod.sh

set -e

PREPROD_IP="192.168.88.15"
REMOTE_PATH="/mnt/user/appdata/finance-tracker"
SSH_KEY="~/.ssh/id_ed25519_unraid_deploy"

echo "🚀 Deploying Finance Tracker to Preprod Environment"
echo "📡 Target: root@$PREPROD_IP:8000"
echo ""

# Test SSH connection (skip ping as it might be blocked)
echo "🔍 Testing SSH connection to preprod environment..."
if ! ssh -i $SSH_KEY -o ConnectTimeout=5 root@$PREPROD_IP exit &> /dev/null; then
    echo "❌ Cannot SSH to preprod environment"
    echo "💡 Make sure SSH key is configured: ssh-copy-id -i $SSH_KEY root@$PREPROD_IP"
    exit 1
fi

echo "✅ Connection OK"

# Stop existing containers
echo "🛑 Stopping existing containers..."
ssh -i $SSH_KEY root@$PREPROD_IP "
    cd $REMOTE_PATH 2>/dev/null || true
    docker compose -f docker-compose.preprod.yml down --remove-orphans 2>/dev/null || true
"

# Sync files
echo "📦 Syncing code to preprod environment..."
ssh -i $SSH_KEY root@$PREPROD_IP "mkdir -p $REMOTE_PATH"
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='coverage' \
    --exclude='storage' \
    --exclude='.env.local' \
    --exclude='*.log' \
    -czf - . | ssh -i $SSH_KEY root@$PREPROD_IP "cd $REMOTE_PATH && tar -xzf -"

# Deploy
echo "🚀 Starting deployment..."
ssh -i $SSH_KEY root@$PREPROD_IP "
    cd $REMOTE_PATH
    
    # Make scripts executable
    chmod +x *.sh
    
    # Detect which docker compose version is available
    if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE='docker-compose'
        echo 'Using: docker-compose (standalone)'
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE='docker compose'
        echo 'Using: docker compose (plugin)'
    else
        echo 'Error: Neither docker-compose nor docker compose plugin found'
        echo 'Please install Docker Compose on Unraid'
        exit 1
    fi
    
    # Build and start
    \$DOCKER_COMPOSE -f docker-compose.preprod.yml up --build -d
    
    # Wait for database
    echo '⏳ Waiting for database...'
    sleep 20
    
    # Setup database
    echo '📊 Setting up database...'
    \$DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T app rails db:create db:migrate || true
    
    # Load demo data
    echo '🌱 Loading demo data...'
    \$DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T app rails db:seed || true
    
    # Precompile assets
    echo '🎨 Compiling assets...'
    \$DOCKER_COMPOSE -f docker-compose.preprod.yml exec -T app rails assets:precompile || true
    
    echo ''
    echo '✅ Deployment complete!'
    echo ''
    
    # Show status
    \$DOCKER_COMPOSE -f docker-compose.preprod.yml ps
"

echo ""
echo "🎉 Deploy completed successfully!"
echo ""
echo "🔗 Access your preprod environment:"
echo "   🌐 App: http://$PREPROD_IP:8000"
echo "   ⚙️  Sidekiq: http://$PREPROD_IP:8000/sidekiq" 
echo "   📧 Email: http://$PREPROD_IP:1081"
echo ""
echo "🛠️  Management commands:"
echo "   ./preprod-utils.sh status"
echo "   ./preprod-utils.sh logs"
echo ""
