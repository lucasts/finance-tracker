# 🎯 Finance Tracker (Orzeny) — Roadmap

## ✅ Current Status

Core features are **complete and functional**: transactions with double-entry bookkeeping,
credit card management, installment plans, recurring commitments, OFX/CSV import with
dedup heuristics, reports/projections, and Sidekiq background automation.

This is a **personal finance tool** — built for personal use, with plans to open source.


## 🐛 Known Issues

### Projected balance double-counts this month's future transactions
- [ ] `OverviewController#projected_balance` adds `future_transactions` (tomorrow through end of month, pending/confirmed) on top of `@balance`, which already sums every transaction of the month by `event_date` with no date or status filter. A pending expense later this month is subtracted twice. Fix: build the base from realized transactions (`event_date <= today`) or drop the second sum, and add a request spec with one pending future transaction. Context: `docs/PROJECTION_SERVICES.md`, "What follows".

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

### March 2026 — Dedup & idempotency improvements

**Items that were already implemented (confirmed/documented):**
- Cross-file dedup: `ImportDedupService` preloads all `ImportedTransactions` for the account across sessions — duplicates from any prior import are detected automatically.
- Visual flag: `possible_duplicate` badge (⚠️ "Suspeita de duplicata") with tooltip shown on import session show view.
- Auto-suggest match: `ImportMatchingService` returns up to 3 suggestion types (candidates, installment_plan, recurring_commitment) displayed as radio buttons in the reconciliation edit view.
- CSV idempotency: `file_digest` (SHA-256) is computed before parsing; re-uploading any file (OFX or CSV) redirects to the summary of the existing session.

**Items implemented in this commit:**
- Added `config/dedup.yml` — app-level configurable tolerances for all dedup, matching, and transfer detection parameters (8 keys).
- Added `config/initializers/dedup_config.rb` — loads YAML and exposes via `Rails.application.config.dedup`.
- Refactored `ImportDedupService` to read tolerances from config; added `EXACT_DATE_TOLERANCE_DAYS` and `SIMILAR_AMOUNT_TOLERANCE` to `FinancialConstants` (previously hardcoded inline).
- Refactored `ImportMatchingService` and `TransferDetectionService` to use config tolerances.
- Fixed self-match bug in `ImportDedupService#similar_by_amount_date?` — newly-created record was being compared against itself after `create_and_index` added it to `@desc_bucket`, causing false `possible_duplicate` flags for records with no real near-match.
- Added `GET /import_sessions/:id/reimport_summary` — shows original filename, session stats (total, conciliated, pending, duplicates, transfers) and action links instead of a plain flash redirect.
- Added 11 new dedup unit tests: mixed batch (1 new + 1 dup), missing `external_id`, rounded amounts (<= tolerance treated as dup), cross-file explicit verification, boundary date and amount window edges.
- Updated `spec/requests/import_sessions_idempotency_spec.rb` to expect `reimport_summary` redirect.
- 618 examples, 0 failures.

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
