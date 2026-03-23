# 🎯 Finance Tracker (Orzeny) — Roadmap

## ✅ Current Status

Core features are **complete and functional**: transactions with double-entry bookkeeping,
credit card management, installment plans, recurring commitments, OFX/CSV import with
dedup heuristics, reports/projections, and Sidekiq background automation.

This is a **personal finance tool** — built for personal use, with plans to open source.


---

## 🔧 Technical Debt — Performance (follow-ups)

Dashboard optimization completed 2025-08-09 (queries reduced from ~220 to <40).

---

## 🔧 Technical Debt — Import Pipeline

### Dedup & idempotency improvements
- [ ] Cross-file dedup heuristic (fingerprint cruzado por external_id/amount/date + tolerance window)
- [ ] Visually flag suspected duplicate `ImportedTransactions` before reconciliation
- [ ] Auto-suggest match when similarity > threshold (description + amount + ±2 days)
- [ ] Reimport UI: show diff/summary when file already imported instead of direct redirect
- [ ] Make dedup tolerances configurable (app-level config: absolute value, %, day window)
- [ ] CSV idempotency support (same digest + line fingerprint)
- [ ] Tests: partial scenario (1 new + 1 duplicate in same file), missing external_id, rounded amounts

---

## 🚀 Future Enhancements (Optional)

### User Experience
- [ ] Dark mode
- [ ] PWA support with offline mode
- [ ] Push notifications for due dates and budget alerts

### Analytics & Reporting
- [ ] Data export in multiple formats (Excel, PDF)

### Integration
- [ ] Open Banking API integration (Brazilian banks)

### Infrastructure
- [ ] CI/CD pipeline (GitHub Actions)

---

## 📦 Release Log

### March 2026 — Add `transactions(payment_date)` index

- Added composite index `(user_id, payment_date)` on `transactions` to support payment-centric queries without full-table scans.
- Migration: `20260322000000_add_payment_date_index_to_transactions.rb`.
- 602 examples, 0 failures.

### March 2026 — Service layer standardization & concern cleanup

- Introduced `BaseService` with uniform `.call` class-method convention; all services inherit it.
- Standardized error handling: services now raise `ServiceError` (wraps originating exception) and return structured `Result` value objects — callers check `result.success?` / `result.error`.
- Removed dead `CategoryConfiguration` concern (unused since category seeding moved to `DefaultCategoriesService`).
- Converted `DefaultCategoriesService` and `ImportMatchingService` to `.call` convention; updated all callers.
- `AmountNormalization` concern made self-contained (no implicit `MoneyConcern` dependency).
- Added `# frozen_string_literal: true` to all service files missing it.
- 602 examples, 0 failures after changes.

### March 2026 — Projection horizon semantics & dashboard display

**Projection horizon decision:**
- Confirmed exact-date mode as the only horizon mode; `month_end` rounding rejected for consistency.
  `months_ahead > 0` → `as_of + N months` (exact day). `months_ahead == 0` → `end_of_month`.
  Documented in `docs/TECHNICAL_SPECIFICATION.md` § Projection Services Architecture and inline service comments.

**Dashboard improvements:**
- `@projected_balance` and `@balance_alert` now displayed on the overview dashboard (were computed but hidden).
- `@category_projections` section added to the dashboard with per-category spend-vs-projection bar.
- Projection tooltips added on overview, reports, and recurring commitment show views explaining the 3-month exact-date horizon.

**Docs:**
- `docs/CURRENT_PRODUCT_DEFINITION.md` — Projections section expanded with horizon and alert details.
- `docs/TECHNICAL_SPECIFICATION.md` — New § Projection Services Architecture with service table and design rationale.

### March 2026 — Fix & stabilize, code quality tooling, test integrity

- Fixed all failing RSpec tests — 566 → 0 failures.
- Updated Dockerfile.local to Ruby 4.0.1 (was 3.4.2); `bin/verify` green locally.
- Enabled RuboCop in `bin/verify` — 0 violations across 155 files.
- Enabled Brakeman in `bin/verify` — 0 warnings; fixed 3 IDOR vulnerabilities.
- Configured SimpleCov with 90% minimum coverage threshold (guarded by `COVERAGE`/`CI` env vars).
- Added explicit double-entry balance assertion spec (10 tests in `double_entry_integrity_spec.rb`).
- Standardized all spec descriptions to English.
- Added 8 new request/integration spec files (71 tests) for previously uncovered controllers.
- `bundle update --conservative` — no lock changes; Rails 8.1.2, Devise 5.0.3, Sidekiq 8.1.1.
- Consolidated 5 separate money concerns into a cohesive module; removed duplicate parsing paths.

### August 2025 — Performance optimization

- Reduced overview dashboard queries from ~220 to <40 (spec enforced at ≤30).
- Batched month aggregates & category ranking (in-memory from preloaded dataset).
- Added caching layer for 12-month chart data (`Rails.cache` + in-request memoization).
- Memoized `RecurringProjectionService` results per request.
- Added DB indexes: `transactions(user_id, status, event_date)` and `entries(account_id, entry_type)`.
- Cache invalidation via `touch` on transaction create/update.
- Unified projection horizon semantics across all projection services.

### Nov–Dec 2025 — DiRams design system

- Created custom DiRams design system replacing Tailwind/DaisyUI.
- Redesigned all pages: transactions, accounts, categories, overview, installment plans.
- Standardized all listing pages with table layout.

### Through Aug 2025 — Core features

- Complete double-entry bookkeeping system.
- Credit card statement management with Brazilian cycles.
- Recurring commitments (9 frequency types).
- Installment plans (up to 120 installments).
- OFX/CSV import with fingerprint-based dedup and transfer detection.
- Financial projections (monthly balance, recurring, installment horizon).
- Dockerized local development environment.
