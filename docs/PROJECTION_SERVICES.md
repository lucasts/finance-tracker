# Projection Services

Design decisions behind future balance forecasting. Extracted from `TECHNICAL_SPECIFICATION.md` in September 2026.

## The question

Someone opens the dashboard on March 15 and asks: "How much will I have in June?" The answer depends on things that have not happened yet: the rent on the 5th, the salary on the 1st, installment 7 of 12 on the refrigerator. They are commitments, and the ledger only records transactions. Projections turn commitments into dated amounts the user can read as if they were already booked.

## Why it is not obvious

Two ambiguities hide in that question. What does "three months ahead" mean? From March 15, does the window end on June 15 or June 30? Both are defensible and give different totals whenever a bill lands late in June.

And what is "my balance"? Brazilian personal finance runs on two calendars. A card purchase on March 28 is a March expense, but the cash leaves the checking account when the statement is paid in April. The app calls these competence (`event_date`) and cash (`payment_date`). A projection has to pick a calendar, or answer for both.

## Decision 1: a horizon is an exact date

The first version (June 2025) rounded the horizon up: three months from March 15 meant "through June 30". It felt natural because the rest of the app thinks in months.

August 2025 replaced it with exact dates: `months_ahead: 3` from March 15 ends on June 15, inclusive. Rounding had a hidden defect. Three months from the 1st covered about 120 days, from the 28th about 94, so the projected total moved on the first of each month for no financial reason. A fixed-length window makes the number comparable from one day to the next.

One exception is deliberate. `months_ahead: 0` means "the rest of this month" and ends at `end_of_month`. This is not rounding sneaking back in: zero months has no exact-date reading (the window would be empty), and its only caller, the monthly balance service, asks a month-shaped question, so the month is the right unit.

A `horizon_mode` flag to opt back into rounding was dropped in March 2026 after seven months without a single request for it.

## Decision 2: recurring looks 3 months out, installments 6

The two sources carry different uncertainty.

An installment plan is fully determined at creation: count, amount, and every date. Projecting installment 9 of 12 is arithmetic and does not degrade with distance. A long window is cheap, correct, and where the user wants the answer: the question about a plan is "when does this end?".

A recurring commitment is open-ended and its amount is a default, not a promise. Electricity varies, subscriptions change price, memberships get cancelled. Each month further out compounds the drift. Three months covers the next statement cycle and a quarter while the estimate is still worth showing.

One shared horizon would have forced a bad choice: truncate installments the user already knows about, or show recurring guesses past their useful life.

## Decision 3: both calendars, one date

`MonthlyBalanceProjectionService` computes two answers for the same month: a competence view bucketed by `event_date` and a cash view bucketed by `payment_date`. Both add the same projected recurring and installment amounts.

For readers outside Brazil, this is accrual versus cash accounting. Accrual (competência) books an expense when the obligation arises; cash (caixa) when money moves. Most apps pick one. This one keeps both because credit cards push them apart by a month for a large share of spending.

Projections land identically in both views because a projected item carries one date. The installment service emits `payment_date` too but sets it equal, since a projected installment does not yet know its statement. The field exists so cash-side shifting can be added later without changing callers.

## Decision 4: computed, never stored

Every projection is an array of hashes built on request.

The alternative was to materialize future occurrences as pending transaction rows. Reads would be trivial, but it moves the difficulty to correctness. Rows go stale the moment a commitment is edited, paused, or closed, and the reconciliation step that rewrites future rows without touching real ones is where a bug corrupts the ledger. Computing on read means an edit shows on the next page load with no synchronization code, as the specs assert. CPU cost is bounded by per-request memoization.

Materialization still happens elsewhere: the daily generation jobs create a real transaction when an occurrence becomes due, and projections cover the stretch until then.

## What follows

- The boundary is inclusive. An occurrence on June 15 belongs to a horizon ending June 15. Both services have specs for this.
- On the last day of the month the monthly balance service adds zero projected expense. The 31st to the 31st has no future days, and today is never future: the filter is `date > as_of`.
- The overview's projected balance is the balance after every commitment in the horizon, not at month end: the month's transactions plus three months of recurring and six of installments. Hence the alert text "after all commitments".

## Limitations

- User isolation is missing, and the previous version of this document claimed otherwise. Both forward services query every active commitment and plan, and no controller filters by user. It works because the app is single-user today. Pass `user:` into the services before any multi-user deployment.
- Horizons are fixed per call site. There is no "show me 12 months".
- Projected amounts are the commitment's default. No trend, no seasonality.
- The recurring generation job handles only monthly and weekly frequencies; projection handles nine. A quarterly commitment is projected but never auto-created.

## How I would know I was wrong

- Exact date. Users asking why June "is missing" a bill on the 20th, or repeated requests for a closed-month view. The fix would be a month report, not a rounding flag.
- 3 versus 6. Installment projections truncating 12x and 24x plans the user cares about, or recurring projections at month three wrong more often than right.
- One date. A user asking why a projected card installment shows in the purchase month instead of the statement month. Then `payment_date` stops being a placeholder.
- Computed. Overview response time growing with commitment count. The fix is a per-user cache invalidated on change, not materialization.

## Reference

| Service | Default horizon | User-scoped | Used by |
|---|---|---|---|
| `RecurringProjectionService` | 3 months, exact date | No | Overview, reports, commitment show |
| `InstallmentProjectionService` | 6 months, exact date | No | Overview, `MonthlyBalanceProjectionService` |
| `MonthlyBalanceProjectionService` | Rest of current month | Transactions only | Not wired to a screen |
| `CategoryProjectionCalculator` | 3 months backward average | Yes | Overview |
