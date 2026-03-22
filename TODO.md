# 🎯 Finance Tracker (Orzeny) — Roadmap

## ✅ Current Status

Core features are **complete and functional**: transactions with double-entry bookkeeping,
credit card management, installment plans, recurring commitments, OFX/CSV import with
dedup heuristics, reports/projections, and Sidekiq background automation.

Last active development: **January 2026**. Resumed: **March 2026**.

---

## 🚨 Immediate — Fix & Stabilize (before any new work)

### 1. Get test suite green again
- [ ] Fix all failing RSpec tests (regressions accumulated while project was idle)
- [ ] Ensure Docker environment builds cleanly (`docker compose -f docker-compose.local.yml up --build`)
- [ ] Verify `bin/verify` passes inside container

### 2. Enable code quality tooling
- [ ] Enable RuboCop in `bin/verify` and fix violations (currently commented out)
- [ ] Enable Brakeman security scanning in `bin/verify` (currently commented out)
- [ ] Configure SimpleCov with a minimum coverage threshold (currently unconfigured)

### 3. Strengthen test integrity
- [ ] Add explicit double-entry balance assertion spec (`sum(debits) == sum(credits)` for every transaction)
- [ ] Standardize spec language to English (some specs use Portuguese `it` descriptions)
- [ ] Expand request/integration specs (14 request specs for 10 controllers — gaps in automation, reconciliation)

### 4. Update dependencies
- [ ] Run `bundle update --conservative` for security patches (2 months stale)
- [ ] Review gem changelogs for breaking changes (Rails 8.0.2, Devise 4.9.4, Sidekiq 8.0.4)

---

## 🔧 Technical Debt — Code Quality

### Money concern consolidation
- [ ] Consolidate 5 separate money concerns (MoneyConcern, MoneyParsing, MoneyNormalization, MoneyValidation, MoneyFormatting) into a cohesive module
- [ ] Remove any legacy/duplicate money parsing paths

### Projection horizon semantics
Unificação aplicada (2025-08-09):
- `months_ahead > 0` cuts at exact date, not end of target month.
- `months_ahead == 0` focuses on current month (until end_of_month).
- `MonthlyBalanceProjectionService`: when `as_of == end_of_month` no future projections added.

Pending:
- [ ] Confirm if UX needs alternative `month_end` horizon mode — if yes, expose `horizon_mode` flag
- [ ] Update in-app help/docs mentioning horizon behavior
- [ ] Review screens showing projection counts to reflect the change

### Other code quality
- [ ] Reduce service pattern variations (standardize constructor/call convention)
- [ ] Standardize error handling patterns across services
- [ ] Modernize deprecated concern usage

---

## 🔧 Technical Debt — Performance (follow-ups)

Dashboard optimization completed 2025-08-09 (queries reduced from ~220 to <40).

Remaining optional items:
- [ ] Add index on `transactions(payment_date)` if payment-centric queries grow
- [ ] Selective fragment caching for credit statement cards
- [ ] Background warm-up job for chart cache (daily)
- [ ] Instrument cache hits/misses via `ActiveSupport::Notifications`
- [ ] Monitor `build_chart_data` generation time (p95)

---

## 🔧 Technical Debt — Import Pipeline

### Dedup & idempotency improvements
- [ ] Cross-file dedup heuristic (fingerprint cruzado por external_id/amount/date + tolerance window)
- [ ] Visually flag suspected duplicate `ImportedTransactions` before reconciliation
- [ ] Auto-suggest match when similarity > threshold (description + amount + ±2 days)
- [ ] Reimport UI: show diff/summary when file already imported instead of direct redirect
- [ ] Exportable report of ignored duplicates (date, amount, reason)
- [ ] Periodic job to recalculate fingerprints if algorithm evolves (version the algorithm)
- [ ] Make tolerances configurable per user (absolute value, %, day window)
- [ ] CSV idempotency support (same digest + line fingerprint)
- [ ] Tests: partial scenario (1 new + 1 duplicate in same file), missing external_id, rounded amounts
- [ ] Metric: duplicates prevented counter per period for internal dashboard

---

## 🚀 Future Enhancements (Optional)

### Security
- [ ] Rate limiting (rack-attack)
- [ ] Change auditing (paper_trail)
- [ ] Two-factor authentication (2FA)

### User Experience
- [ ] Dark mode
- [ ] PWA support with offline mode
- [ ] Push notifications for due dates and budget alerts
- [ ] Customizable dashboard widgets

### Analytics & Monitoring
- [ ] Application monitoring (Sentry/Bugsnag)
- [ ] Data export in multiple formats (Excel, PDF)
- [ ] Advanced reporting templates

### Integration
- [ ] Open Banking API integration (Brazilian banks)
- [ ] Email report automation
- [ ] REST API for third-party applications

### Infrastructure
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Container security scanning
- [ ] Automated security vulnerability scanning

---

## ✅ Completed Milestones

### Performance optimization (2025-08-09)
- Reduced overview dashboard queries from ~220 to <40 (spec enforced)
- Batched month aggregates & category ranking (in-memory from preloaded dataset)
- Added caching layer for 12-month chart data (Rails.cache + in-request memoization)
- Memoized RecurringProjectionService results per request
- Added DB indexes: `transactions(user_id, status, event_date)` and `entries(account_id, entry_type)`
- Cache invalidation strategy (touch on transaction create/update)
- Performance spec threshold tightened to <=30 queries

### DiRams design system (Nov–Dec 2025)
- Created custom DiRams design system replacing Tailwind/DaisyUI
- Redesigned all pages: transactions, accounts, categories, overview, installment plans
- Standardized all listing pages with table layout

### Core features (through Aug 2025)
- Complete double-entry bookkeeping system
- Credit card statement management with Brazilian cycles
- Recurring commitments (9 frequency types)
- Installment plans (up to 120 installments)
- OFX/CSV import with fingerprint-based dedup and transfer detection
- Financial projections (monthly balance, recurring, installment horizon)
- Dockerized local development environment