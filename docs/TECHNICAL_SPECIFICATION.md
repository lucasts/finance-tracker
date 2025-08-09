# Finance Tracker — Enhanced Technical Specification

## 🚀 What is this?

A personal finance management application built for Brazilian financial practices. Think "Notion for your money" — with double-entry bookkeeping, credit card cycle management, and automated transaction categorization.

## ⚡ Core Tech Stack

### **Backend**
- **Rails 8.0** + **Ruby 3.4** — Modern Rails with all the latest features
- **PostgreSQL** (production) / **SQLite** (development) — Standard Rails DB setup
- **Hotwire** (Turbo + Stimulus) — SPA-like experience without complex JS frameworks
- **Sidekiq** — Background job processing
- **Devise** — User authentication

### **Frontend**
- **Tailwind CSS 4** + **DaisyUI** — Utility-first styling with pre-built components
- **Stimulus Controllers** — Lightweight JS for interactive behaviors (15+ controllers)
- **Brazilian Localization** — All Portuguese, Brazilian currency formatting
- **Accessibility** — WCAG AA compliance with keyboard navigation and screen reader support

### **Testing & Quality**
- **RSpec** (457+ tests) — Backend testing with comprehensive coverage
- **Jest** (90+ tests) — Frontend JavaScript testing
- **ESLint + Prettier** — Code quality and formatting consistency
- **Comprehensive test coverage** — Controllers, models, services, and JS components

## 🏗️ Architecture Decisions

### **Financial Data Model**

```
                    ┌─────────────┐
                    │    User     │
                    │ (Devise)    │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
   │  Account    │  │  Category   │  │Transaction  │◄─┐
   │ (Checking,  │  │ (Income/    │  │ (Double-    │  │
   │  Credit,    │  │  Expense)   │  │  Entry)     │  │
   │  Savings)   │  └─────────────┘  └──────┬──────┘  │
   └──────┬──────┘                         │         │
          │              ┌──────────────────┼─────────┘
          │              │                  │
          ▼              ▼                  ▼
   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
   │AccountType  │  │    Entry    │  │   Import    │
   │ (Asset,     │  │ (Debit/     │  │  System     │
   │  Liability, │  │  Credit)    │  └─────────────┘
   │  Expense)   │  └─────────────┘          │
   └─────────────┘                           │
                                             ▼
      ┌──────────────────────────────────────────────────┐
      │              Import System                       │
      ├─────────────┬─────────────┬─────────────────────┤
      │ImportSession│ImportedTrans│ ReconciliationEntry │
      │             │action       │                     │
      └─────────────┴─────────────┴─────────────────────┘

      ┌──────────────────────────────────────────────────┐
      │           Automation System                      │
      ├─────────────┬─────────────┬─────────────────────┤
      │Recurring    │Installment  │    Credit           │
      │Commitment   │Plan         │    Statement        │
      │(Bills,      │(Split       │    (Monthly         │
      │ Salary)     │ Purchases)  │     Cycles)         │
      └─────────────┴─────────────┴─────────────────────┘
```

### **Core Relationships**

- **User** `has_many` → Accounts, Categories, Transactions, RecurringCommitments, InstallmentPlans
- **Transaction** `belongs_to` → User, Category (optional), CreditStatement (optional)
- **Transaction** `has_many` → Entries (debit/credit pairs for double-entry)
- **Account** `belongs_to` → AccountType, User
- **Entry** `belongs_to` → Transaction, Account
- **RecurringCommitment/InstallmentPlan** → Auto-generates future Transactions

### **Key Design Choices**

**Why Hotwire instead of React/Vue?**
- Simpler mental model for financial data
- Server-side rendering with selective reactivity
- Less frontend complexity, more Rails conventions

**Why double-entry accounting?**
- Ensures financial data integrity
- Supports complex scenarios (transfers, credit cards, installments)
- Industry standard for financial applications

**Why Brazilian-specific features?**
- Credit card cycle management (fechamento/vencimento)
- Brazilian currency formatting (R$)
- OFX import support for local banks

## 📁 Code Organization

```
app/
├── controllers/     # Standard Rails controllers
├── models/         # Core domain: Transaction, Account, Category
├── services/       # Business logic (CreateTransaction, ImportOFX)
├── jobs/          # Background processing (recurring transactions)
├── javascript/    # Stimulus controllers for interactivity
└── views/         # ERB templates with Tailwind/DaisyUI
```

### **Key Services**
- **`CreateTransactionService`** — Handles complex transaction creation logic
- **`ImportOFXService`** — Processes bank file imports  
- **`ReconciliationEngine`** — Matches imported vs existing transactions

### **Stimulus Controllers**
- **Modal Management** — Accessible dialog handling with focus management
- **Form Validation** — Real-time validation with user feedback
- **Currency Input** — Brazilian currency formatting and validation
- **Chart Rendering** — Interactive financial charts with ApexCharts
- **Table Filtering** — Advanced search and filter capabilities

## 🔧 Integration Capabilities

### **File Import System**
- **OFX Parser** — Custom Ruby implementation (`lib/ofx_simple_parser.rb`)
- **CSV Processing** — Flexible header detection and data mapping
- **Reconciliation Engine** — Fuzzy matching algorithms for transaction identification
- **Duplicate Detection** — Hash-based deduplication with tolerance parameters

### **Automated Processing**
- **Background Jobs** — Sidekiq integration for recurring tasks
- **Recurring Generation** — Automatic future transaction creation
- **Statement Automation** — Credit card cycle processing
- **Validation Pipeline** — Multi-layer data validation and sanitization

## 🔐 Security & Data Protection

### **Application Security**
- **Authentication** — Devise-based user session management
- **Authorization** — User-scoped data access control
- **Input Validation** — Comprehensive server-side validation
- **SQL Injection Prevention** — Parameterized queries and ORM protection
- **CSRF Protection** — Built-in Rails security features

### **Data Privacy**
- **User Scoping** — All financial data belongs to authenticated users
- **Basic Audit Trail** — Limited audit logging for reconciliation entries
- **Standard Rails Security** — CSRF protection, parameter filtering
- **No Sensitive Logging** — Financial amounts excluded from logs

## 🚀 Deployment & Operations

### **Infrastructure Compatibility**
- **Container Ready** — Docker configuration for consistent deployment
- **Cloud Native** — Ready for Heroku, Railway, and major cloud providers
- **Environment Management** — Separate configurations for development, staging, production
- **Health Monitoring** — Application health checks and monitoring endpoints

### **Performance Characteristics**
- **Database Optimization** — Query optimization and connection pooling
- **Asset Pipeline** — Optimized static asset delivery with Tailwind
- **Memory Management** — Efficient Ruby memory usage patterns
- **Response Times** — Optimized for sub-200ms average response times

## 🎨 Frontend Implementation

### **User Experience Technology**
- **Responsive Design** — Mobile-first approach with progressive enhancement
- **Performance** — Minimal JavaScript footprint with Turbo acceleration
- **Internationalization** — Full Brazilian Portuguese localization
- **Color System** — WCAG AA compliant color contrast ratios

### **Accessibility Features**
- **Keyboard Navigation** — Full keyboard accessibility for all interactions
- **Screen Reader Support** — Semantic HTML and ARIA labels
- **Color Contrast** — Minimum 4.5:1 ratio for normal text, 3:1 for large text
- **Focus Management** — Clear focus indicators and logical tab order

## 📊 What's Special Here

1. **Smart Import Engine** — Automatically categorizes and deduplicates imported transactions
2. **Credit Card Intelligence** — Understands Brazilian credit card cycles and statements
3. **Recurring Transaction Engine** — Automatically generates future payments/income
4. **Cash Flow Projections** — Calculates future balances based on confirmed + scheduled transactions
5. **Brazilian UX** — Designed for local financial habits and terminology
6. **Double-Entry Accuracy** — Complete financial integrity with audit trails
7. **Modern Performance** — Optimized for fast loading and smooth interactions

---

**TLDR**: Modern Rails 8 app using Hotwire for a finance management platform tailored to Brazilian users. Double-entry bookkeeping meets contemporary web development with enterprise-grade quality and testing.
