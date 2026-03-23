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
- **CSV Variants** — Supports standard headers, headerless semicolon bank exports (`DD/MM/YYYY;descricao;valor`) and credit-card bill CSV (`data,lançamento,valor`) with fallback handling for BOM and stripped cedilla headers (`lancamento`/`lanamento`)
- **Reconciliation Engine** — Fuzzy matching algorithms for transaction identification
- **Duplicate Detection** — Advanced heuristic engine (description normalization + temporal & monetary tolerances + similarity flagging)

#### Duplicate Detection Heuristics
The import pipeline applies layered rules (implemented in `ImportDedupService`) to suppress true duplicates while surfacing likely repeats for manual review:

| Order | Rule | Condition (after normalization) | Result |
|-------|------|----------------------------------|--------|
| 1 | Exact Duplicate | Same normalized description AND same date AND amount diff ≤ 0.01 | Skip (not created) |
| 2 | Tolerance Duplicate | Same normalized description AND date diff ≤ 1 day AND amount diff ≤ 0.01 | Skip |
| 3 | Similar (Flag) | (a) Same (or 1‑edit) normalized description AND date diff ≤ 3 days AND amount diff ≤ 2.00 OR (b) any prior txn (even >1 edit away) within those date & amount windows | Create + `possible_duplicate = true` |
| 4 | Approximate Description | 1 edit (insert/substitute) difference is treated as same description for rules above | Included in same description bucket |

Key implementation details:
- Normalization collapses whitespace, lowercases, strips accents (`I18n.transliterate`).
- One‑edit distance check avoids full Levenshtein cost for short strings.
- Fallback similarity (3a/3b) broadens coverage when banks radically change wording.
- Amount tolerance constant: `FinancialConstants::AMOUNT_ABSOLUTE_TOLERANCE` (currently 0.01).
- Date similarity horizon: `FinancialConstants::DATE_TOLERANCE_DAYS` (currently 3).

Why this matters: prevents silent duplication in re‑imports while preserving user control over ambiguous near‑matches (flag instead of suppress). Future enhancements: configurable tolerances, metrics, bulk resolution UI, adaptive heuristics.

#### Transfer Detection System
The import pipeline automatically identifies potential transfers between user accounts using heuristic matching (implemented in `TransferDetectionService`):

| Criteria | Tolerance | Purpose |
|----------|-----------|---------|
| Same User | Exact | Only detects transfers within user's accounts |
| Different Accounts | Exact | Prevents same-account false positives |
| Amount Match | ±R$ 0.01 | Compensates for rounding/small fees |
| Date Proximity | ±2 days | Handles processing delays between institutions |
| Sign Preference | Opposite preferred | One debit (-) paired with one credit (+) |

**Database Schema**:
```sql
-- Added to imported_transactions
transfer_candidate BOOLEAN NOT NULL DEFAULT FALSE
potential_transfer_with_id BIGINT NULL
```

**Processing Flow**:
1. Import creates transactions via `ImportDedupService`
2. `TransferDetectionService` automatically runs post-import
3. Identified pairs marked with `transfer_candidate = true`
4. UI displays visual indicators (badges, background highlighting)

**Limitations**: One-to-one pairing only, same user restriction, small tolerance may miss larger fees. Future: configurable tolerances, semantic description matching, bulk confirmation interface.

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

## � Projection Services Architecture

### Overview

The projection system generates non-persisted future transaction data to help users forecast their financial position. All projection services follow a unified **horizon semantics** established in August 2025.

### Horizon Semantics (exact-date mode)

The system uses a single, consistent horizon mode: **exact-date**.

- **`months_ahead > 0`**: The horizon end date is calculated as `as_of.advance(months: months_ahead)`. This produces an exact-day boundary — e.g., if `as_of = March 15` and `months_ahead = 3`, the horizon is **June 15**, not June 30.
- **`months_ahead == 0`**: The horizon end date is `as_of.end_of_month`. This provides a "current month focus" — projecting only within the remaining days of the current month.

**Design decision**: A `month_end` alternative mode (rounding up to end of target month) was evaluated and rejected. Exact-date is more predictable for financial forecasting and avoids the inconsistency where "3 months" would mean variable durations depending on the current day of month.

### Services

| Service | Default Horizon | Purpose | Used By |
|---------|----------------|---------|---------|
| `RecurringProjectionService` | 3 months | Projects future transactions from active recurring commitments | OverviewController, ReportsController, recurring show view |
| `InstallmentProjectionService` | 6 months | Projects unpaid installments from active plans | OverviewController (via `projected_balance`), MonthlyBalanceProjectionService |
| `MonthlyBalanceProjectionService` | Current month | Dual-perspective (competence vs cash) balance projection | Available for future use |
| `CategoryProjectionCalculator` | 3 months (backward) | Computes per-category average spending over historical window | OverviewController |

### Key Behaviors

1. **`MonthlyBalanceProjectionService`**: When `as_of == end_of_month`, both `projected_recurring_expenses` and `projected_installment_expenses` return 0 (no future days remaining in the month).

2. **Competence vs Cash separation**: `MonthlyBalanceProjectionService` maintains dual scopes — `event_date` for competence perspective, `payment_date` for cash perspective — with projections summed into both.

3. **Memoization**: `RecurringProjectionService` results are cached per-request in `OverviewController` to avoid redundant computation across `@projected_transactions` and `projected_balance`.

4. **User isolation**: `RecurringProjectionService` and `InstallmentProjectionService` query all active commitments/plans (not user-scoped). User isolation happens at the controller level via `current_user_scope`.

## �📊 What's Special Here

1. **Smart Import Engine** — Automatically categorizes and deduplicates imported transactions
2. **Credit Card Intelligence** — Understands Brazilian credit card cycles and statements
3. **Recurring Transaction Engine** — Automatically generates future payments/income
4. **Cash Flow Projections** — Calculates future balances based on confirmed + scheduled transactions
5. **Brazilian UX** — Designed for local financial habits and terminology
6. **Double-Entry Accuracy** — Complete financial integrity with audit trails
7. **Modern Performance** — Optimized for fast loading and smooth interactions

---

**TLDR**: Modern Rails 8 app using Hotwire for a finance management platform tailored to Brazilian users. Double-entry bookkeeping meets contemporary web development with enterprise-grade quality and testing.
