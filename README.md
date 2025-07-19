# 💰 Orzeny Finance Tracker

Complete family financial management system with separation between credit card competence and real cash flow, future projections, and recurring transaction automation.

## 🎯 Main Features

### ✨ Advanced Transaction Management
- **Temporal Separation**: Clear distinction between event date and payment date
- **Credit Cards**: Complete invoice control with closing and due dates
- **Smart Installments**: Installment plans with automatic generation
- **Recurring Transactions**: Complete automation of fixed income and expenses

### 📊 Analysis and Reports
- **Real Cash Flow**: Accurate view of available money
- **Competence vs Cash**: Separate reports for distinct analyses
- **Future Projections**: Forecasts based on recurring commitments
- **Interactive Dashboards**: Multiple data visualizations

### 🤖 Smart Automation
- **Background Jobs**: Automatic processing via Sidekiq
- **Recurring Jobs**: Automatic generation of monthly/annual transactions
- **Installment Processing**: Automatic creation of future installments
- **Invoice Updates**: Automatic calculation of card values

## 🚀 Environments

### 🔨 Local Development
```bash
# Initial setup
./bin/setup

# Development server
./bin/dev

# Tests
bundle exec rspec
```

### 📊 Demo Data
The default setup loads only essential data. For demonstrations or development with rich data:

```bash
# Load demo data (recommended for demos)
rails db:seed:demo

# Complete reset with demo data
rails db:seed:demo_full
```

**📋 [View complete data documentation](DEMO_DATA_MANAGEMENT.md)**

### 🎯 Pre-production (Heroku-like)
Complete environment that simulates production:

```bash
# Start complete environment
./run-pre-prod.sh

# Utilities
./preprod-utils.sh help
./preprod-utils.sh start
./preprod-utils.sh console
./preprod-utils.sh jobs

# Health check
./health-check.sh
```

**Included services:**
- PostgreSQL (port 5433)
- Redis (port 6380)
- Sidekiq + Web UI
- MailCatcher (port 1080)
- Rails App (port 3001)

[📖 **Complete environment documentation**](PREPROD.md)

## 🤖 Automation

### Background Jobs
```ruby
# Recurring transactions (salaries, rent, etc)
GenerateRecurringTransactionsJob.perform_later

# Installment parcels
GenerateInstallmentTransactionsJob.perform_later
```

## 🚀 Ready to Deploy

### Heroku
```bash
# Create app
heroku create my-finance-tracker

# Configure addons
heroku addons:create heroku-postgresql
heroku addons:create heroku-redis

# Deploy
git push heroku main
heroku run rails db:migrate
```

---

**✅ Complete MVP | ✅ Pre-production Environment | ✅ Operational Automation**