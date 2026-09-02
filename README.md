# 💰 Finance Tracker

**Complete family financial management system** with competence vs cash flow separation, advanced credit card control, automated recurring transactions, and intelligent financial projections.

## 🎯 Key Features

### ✨ Advanced Transaction Management
- **Temporal Separation**: Clear distinction between event date and payment date
- **Credit Cards**: Complete invoice control with automatic closing and due dates
- **Smart Installments**: Installment plans with automatic generation of all payments
- **Recurring Transactions**: Complete automation of fixed income and expenses (salary, rent, etc.)
- **Transfers**: Complete system between accounts with validations

### 📊 Analytics and Reports
- **Real Cash Flow**: Accurate view of available money
- **Competence vs Cash**: Separate reports for different analyses
- **Future Projections**: End-of-month forecasts based on recurring commitments
- **Interactive Dashboards**: Multiple data visualizations with charts
- **Rankings**: Analysis by category, account, and period

### 🤖 Intelligent Automation
- **Background Jobs**: Automatic processing via Sidekiq
- **Recurring Generation**: Automatic creation of monthly/annual transactions
- **Installment Processing**: Automatic activation of future installments
- **Automatic Invoices**: Calculation and automatic association of card values
- **Smart Status**: Automatic updates based on dates (pending/confirmed)

### 📥 Import and Reconciliation
- **Multiple Formats**: Support for OFX and CSV (including headerless bank CSV and credit card bills with `data,lançamento,valor`)
- **Smart Reconciliation**: Heuristics based on amount + description + date (±3 days)
- **Batch Processing**: Import sessions with state control
- **Duplicate Detection**: Anti-duplication system with memory
- **Complete Audit**: Detailed history of all reconciliations

## 🏗️ Technical Architecture

### Robust Backend
- **Ruby on Rails 8.0** with modern patterns
- **PostgreSQL** with double-entry system
- **Sidekiq** for background jobs
- **618+ RSpec tests** passing
- **Devise** for authentication

### Modernized Frontend
- **Stimulus + Turbo** (Hotwire stack)
- **Tailwind CSS + DaisyUI** for design system
- **90 Jest tests** passing
- **WCAG AA** compliance
- **Optimized performance** (lazy loading, smart cache)

## 🚀 Running Locally

The development stack runs **Ruby/Rails directly on the host**. Only PostgreSQL and Redis run via Docker.

### Prerequisites
- Ruby (version in `.ruby-version`)
- Node.js / Yarn
- Docker (only for pg + redis)

### 1. Start the Infrastructure Services

```bash
# Starts only PostgreSQL and Redis in the background
docker compose -f docker-compose.local.yml up db redis -d
```

Ports mapped on the host:
- PostgreSQL: `5432`
- Redis: `6379`

### 2. Initial Setup (First Time)

```bash
# Installs gems, prepares the database, and starts the server
./bin/setup
```

### 3. Day-to-Day Development

```bash
# Starts Rails + Sidekiq + asset watcher
./bin/dev

# Access at http://localhost:3000
```

### Tests

```bash
bundle exec rspec        # full suite
bundle exec rspec spec/models/transaction_spec.rb  # specific file
bundle exec rspec spec/models/transaction_spec.rb:42  # specific example
bin/verify               # rspec + rubocop + brakeman (pre-commit check)
```

### Environment Variables

Copy `.env.example` and adjust as needed:
```bash
cp .env.example .env.local
```

Default values expected with local Docker:
```
DATABASE_URL=postgres://postgres:postgres@localhost:5432/orzeny_development
REDIS_URL=redis://localhost:6379/1
```

### Database Reset

```bash
bin/rails db:drop db:create db:migrate db:seed
```

### Stop the Docker Services

```bash
docker compose -f docker-compose.local.yml down          # stops (data persists)
docker compose -f docker-compose.local.yml down -v       # stops and removes volumes
```

### Demo Data
The default setup loads only essential data. For demonstrations with realistic data:

```bash
# Load demo data (recommended for demonstrations)
rails db:seed:demo

# Complete reset with demo data
rails db:seed:demo_full
```

### Pre-production Environment
Complete environment that simulates production with all services:

```bash
# Start complete environment
./run-pre-prod.sh

# Management utilities
./preprod-utils.sh help
./preprod-utils.sh start
./preprod-utils.sh console
./preprod-utils.sh jobs

# Health check
./health-check.sh
```

**Services included:**
- PostgreSQL (port 5433)
- Redis (port 6380) 
- Sidekiq + Web UI
- MailCatcher (port 1080)
- Rails App (port 3001)

## 🧪 Quality and Testing

### Test Coverage
- ✅ **Backend**: 618+ RSpec tests covering models, controllers, services, and jobs
- ✅ **Frontend**: 90 Jest tests covering services and Stimulus controllers
- ✅ **Integration**: Complete end-to-end flows
- ✅ **Performance**: Optimized Web Vitals metrics

### Quality Standards
- ✅ **WCAG AA** compliance (accessibility)
- ✅ **Double-entry** correct accounting
- ✅ **Zero** known data inconsistencies
- ✅ **Security**: Robust validations and authorizations

## 🤖 Operational Automation

### Background Jobs
```ruby
# Recurring transactions (salaries, rent, etc.)
GenerateRecurringTransactionsJob.perform_later

# Installment payments
GenerateInstallmentTransactionsJob.perform_later

# Combined execution
AutomationJob.perform_later
```

### Automatic Scheduling
- **Recurrences**: Executed monthly via cron
- **Installments**: Automatically activated on correct dates
- **Invoices**: Automatically created for credit cards
- **Status**: Automatically updated based on dates

## 🚀 Production Deployment

### Heroku (Recommended)
```bash
# Create application
heroku create my-finance-tracker

# Configure addons
heroku addons:create heroku-postgresql
heroku addons:create heroku-redis

# Deploy
git push heroku main
heroku run rails db:migrate
heroku run rails db:seed
```

### Docker Deployment
```bash
# Build and run
docker build -t finance-tracker .
docker run -p 3000:3000 finance-tracker

# Or use docker-compose
docker-compose up -d
```

### Environment Variables
Required for production:
```bash
DATABASE_URL=postgresql://...
SECRET_KEY_BASE=your_secret_key_here
RAILS_MASTER_KEY=your_master_key_here
```

## 📖 Documentation

- **[Product Definition](docs/CURRENT_PRODUCT_DEFINITION.md)** - Complete functional specification
- **[Technical Specification](docs/TECHNICAL_SPECIFICATION.md)** - Technical architecture overview
- **[Production Guide](PRODUCTION.md)** - Deployment instructions
- **[Pre-production Setup](PREPROD.md)** - Development environment
- **[TODO/Roadmap](TODO.md)** - Future improvements

## 📊 Project Status

### ✅ Completely Implemented
- **Financial Core**: All features implemented and tested
- **Modern Frontend**: Responsive and accessible interface
- **Automation**: Background jobs and processing functional
- **Quality**: Robust tests with high coverage
- **Deploy**: Production-ready with complete documentation

### 📈 Success Metrics
- ✅ **618+** backend tests passing
- ✅ **90** frontend tests passing
- ✅ **100%** features implemented
- ✅ **A+** accessibility grade
- ✅ **0** known critical bugs

---

**✅ Complete MVP** | **✅ Pre-production Environment** | **✅ Operational Automation** | **✅ Modernized Frontend** | **✅ Enterprise Quality**

The **Finance Tracker** is a complete family financial management system **ready for production**.