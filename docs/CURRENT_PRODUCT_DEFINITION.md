# Finance Tracker — Current Product Definition

## Vision

Finance Tracker is a comprehensive personal finance management system that provides clarity and control over your money. Built with Brazilian financial practices in mind, it offers both simple daily money tracking and sophisticated financial analysis capabilities.

## Core Product Capabilities

### 🏦 **Double-Entry Bookkeeping**
- Every transaction follows proper accounting principles with source and destination accounts
- Automatic balance reconciliation ensures financial accuracy
- Complete audit trail for all money movements
- Support for transfers between accounts without affecting net worth

### 💳 **Brazilian Credit Card Management**
- Native support for Brazilian credit card cycles (purchases today, statement next month)
- Monthly statement tracking with due dates and payment status
- Automatic organization of card purchases into statement periods
- Clear separation between card usage and actual cash flow impact

### 📊 **Comprehensive Transaction Management**
- Track income, expenses, and transfers with full categorization
- Dual-date system: event date (when it happened) vs payment date (cash impact)
- Transaction status tracking (pending, confirmed, cancelled)
- Rich categorization system for detailed expense analysis

### 🔄 **Automated Financial Patterns**
- **Installment Plans**: Automatic tracking of purchases paid in multiple installments
- **Recurring Commitments**: Monthly bills, salaries, and regular transactions
- **Smart Scheduling**: Future transaction generation for better cash flow planning
- **Flexible Editing**: Modify single occurrences or entire patterns

### 📈 **Financial Insights & Projections**
- Monthly dashboard with income, expenses, and net flow analysis
- End-of-month cash projection based on confirmed transactions, recurring commitments (3-month horizon), and installment plans (6-month horizon)
- Projected balance display with alerts for negative or low balance
- Per-category spending projection based on 3-month historical average
- Category-based spending analysis and trends
- Multi-account balance overview with account type grouping
- Projection horizon uses exact-date boundaries (not end-of-month rounding)

### 📁 **Bank Data Integration**
- OFX and CSV file import from Brazilian banks
- Intelligent transaction matching and reconciliation
- Duplicate detection and prevention
- Manual review process for ambiguous transactions

### 🎯 **Account Management**
- Support for all account types: Bank, Credit Card, Cash, Savings
- Revenue and Expense accounts for complete financial tracking
- Account grouping and categorization
- Balance tracking across multiple institutions

## Key Product Features

### **Dashboard & Overview**
- Monthly financial summary with key metrics
- Quick access to recent transactions and upcoming payments
- Credit card statement status and due dates
- Cash flow projection and alerts

### **Transaction Workflows**
- Fast transaction entry with smart defaults
- Bulk operations for recurring patterns
- Category-based organization and filtering
- Advanced search and filtering capabilities

### **Financial Planning**
- Cash flow projections based on historical and scheduled data
- Installment plan tracking with remaining payments
- Recurring commitment management
- Month-to-month financial comparison

### **Data Management**
- Bank statement import and reconciliation
- Transaction categorization and tagging
- Financial data export and reporting
- Complete transaction history maintenance

## Product Principles

### **Clarity First**
Every screen immediately answers "How am I doing financially?" and "What needs my attention?"

### **Brazilian Finance Reality**
Native support for Brazilian banking practices, credit card cycles, and payment methods.

### **Competence vs Cash**
Clear distinction between when transactions occur (competence) and when they impact cash flow.

### **Automated Intelligence**
Smart defaults, automatic categorization suggestions, and pattern recognition reduce manual work.

### **Financial Accuracy**
Double-entry principles ensure all accounts balance and provide trustworthy financial data.

## Target Use Cases

### **Daily Money Management**
- Quick expense tracking and categorization
- Balance checking across accounts
- Upcoming payment awareness
- Cash flow monitoring

### **Monthly Financial Review**
- Income vs expense analysis
- Category spending review
- Credit card statement reconciliation
- Budget variance analysis

### **Financial Planning**
- Cash flow projection and planning
- Recurring expense management
- Large purchase planning (installments)
- Emergency fund tracking

### **Tax and Reporting**
- Complete transaction history
- Category-based expense reports
- Income tracking and documentation
- Financial data export for accounting

## Product Boundaries

### **What Finance Tracker Does**
- Personal finance tracking and analysis
- Brazilian banking integration
- Cash flow management and projection
- Transaction categorization and reporting

### **What Finance Tracker Doesn't Do**
- Investment portfolio management
- Multi-currency foreign exchange
- Business accounting and payroll
- Automatic bank API connections
- Tax filing or preparation

## Technical Implementation Status

### **Backend (Ruby on Rails 8.0)**
- Complete double-entry accounting system
- 457+ RSpec tests with comprehensive coverage
- Background job processing with Sidekiq
- PostgreSQL database with optimized queries
- Complete API endpoints for all operations

### **Frontend (Hotwire + Tailwind)**
- Modern Stimulus controllers for interactivity
- 90+ Jest tests covering JavaScript functionality
- Responsive design with WCAG AA accessibility
- Brazilian Portuguese localization
- Optimized performance with lazy loading

### **Integration & Automation**
- OFX and CSV import processing
- Smart reconciliation algorithms
- Automated recurring transaction generation
- Credit card statement processing
- Email notifications and alerts

### **Quality Assurance**
- 547+ total tests (backend + frontend)
- Zero known critical bugs
- Production-ready deployment scripts
- Complete documentation and setup guides
- Pre-production environment for testing

---

**Finance Tracker** provides a complete solution for personal financial management tailored to Brazilian users, combining the precision of double-entry accounting with the simplicity needed for daily money management.
