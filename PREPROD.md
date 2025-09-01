# Pre-production Environment - Orzeny Finance Tracker

## 🎯 Objective

This pre-production environment was designed to simulate a production environment similar to Heroku, allowing complete testing before real deployment.

## 🏗️ Architecture

### Docker Services
- **PostgreSQL 15**: Main database
- **Redis 7**: Cache and queue for background jobs
- **Rails App**: Main application (port 3001)
- **Sidekiq**: Background job processing
- **MailCatcher**: Email server for testing (port 1080)

### Exposed Ports
- `8000`: Rails application
- `5434`: PostgreSQL
- `6381`: Redis
- `1081`: MailCatcher Web UI
- `1026`: MailCatcher SMTP

## 🚀 How to Use

### Complete Initialization
```bash
# First time or complete reset
./run-pre-prod.sh
```

### Utility Commands
```bash
# View help
./preprod-utils.sh help

# Most used commands
./preprod-utils.sh start     # Start environment
./preprod-utils.sh stop      # Stop environment
./preprod-utils.sh logs      # View logs
./preprod-utils.sh console   # Rails console
./preprod-utils.sh jobs      # Execute jobs manually
./preprod-utils.sh reset     # Complete database reset
```

### Remote Deployment
```bash
# Deploy to remote preprod environment (192.168.88.15)
./deploy-preprod.sh

# Manage remote environment
./preprod-utils.sh deploy    # Full deployment
./preprod-utils.sh sync      # Sync code only
./preprod-utils.sh status    # Check status
```

### Health Check
```bash
./health-check.sh
```

## 🔧 Configuration

### Environment Variables
The environment uses `.env.preprod` which simulates Heroku-like configurations:
- Database URL in Heroku format
- Redis URL
- Feature flags
- Performance configurations

### Background Jobs
- **Sidekiq** configured with Redis
- Automatic jobs via `config/schedule.rb`
- Web UI available at `/sidekiq`

### Email Testing
- MailCatcher captures all emails
- Web interface at `http://localhost:1081`
- Simulated SMTP on port 1026

## 📊 Monitoring

### Important URLs
- **App**: http://localhost:8000
- **Sidekiq**: http://localhost:8000/sidekiq
- **MailCatcher**: http://localhost:1081

### Test Data
The environment automatically loads realistic data via `db/seeds/demo_realistic.rb`:
- Bank accounts and credit cards
- 12 months of transactions
- Active installment plans
- Recurring commitments

## 🔄 Automation

### Configured Jobs
1. **GenerateRecurringTransactionsJob**
   - Production: Daily at 6:00 AM
   - Preprod: Every 30 minutes (for testing)

2. **GenerateInstallmentTransactionsJob**
   - Production: Daily at 6:30 AM
   - Preprod: Every hour

### Manual Commands
```bash
# Execute specific jobs
./preprod-utils.sh jobs

# Via Rails console
./preprod-utils.sh console
> GenerateRecurringTransactionsJob.perform_now
> GenerateInstallmentTransactionsJob.perform_now
```

## 🛠️ Troubleshooting

### Container won't start
```bash
# Check logs
./preprod-utils.sh logs

# Complete rebuild
./preprod-utils.sh stop
./run-pre-prod.sh
```

### Database issues
```bash
# Connect directly
./preprod-utils.sh db

# Complete reset
./preprod-utils.sh reset
```

### Performance
```bash
# View detailed status
./preprod-utils.sh status

# Complete health check
./health-check.sh
```

## 🎯 Differences from Real Heroku

### Similarities
✅ PostgreSQL as database  
✅ Redis for background jobs  
✅ Sidekiq for processing  
✅ Environment variables  
✅ Procfile to define processes  
✅ Automatic asset compilation  
✅ Structured logs  

### Differences (local limitations)
❌ SSL/TLS (disabled for development)  
❌ CDN for assets  
❌ Automatic dyno scaling  
❌ External add-ons (SendGrid, etc)  
❌ Heroku Scheduler (simulated with whenever)  

## 🔒 Security

For local development:
- SSL disabled
- Default database passwords
- Fixed secret keys
- Permissive CORS

**⚠️ DO NOT use in real production!**

## 📝 Logs

All containers log to STDOUT/STDERR, allowing:
```bash
# Specific logs
docker-compose -f docker-compose.preprod.yml logs app
docker-compose -f docker-compose.preprod.yml logs sidekiq

# Real-time logs
./preprod-utils.sh logs
```

## 🎉 Ready for Production

This environment prepares the application for deployment on:
- Heroku
- Railway
- Render
- DigitalOcean App Platform
- Any Rails-compatible PaaS

All critical aspects are tested:
- Database connections
- Background jobs
- Asset pipeline
- Email delivery
- Environment variables
- Basic performance
