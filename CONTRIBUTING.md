# Contributing Guidelines

This project follows a lightweight set of engineering conventions captured here so they are explicit and repeatable.

## 1. Commit Message Convention

Format (Conventional Commits inspired):

<type>(optional scope): <short imperative description>

Body (optional, wrapped at 100 cols) explains the why (not the what). Reference issues with `Refs: #123`.

Allowed types (keep focused & consistent):
- feat: user-facing feature
- fix: bug fix (tests should fail without it)
- refactor: code restructure without behavior change
- perf: performance improvement
- test: adding or improving tests only
- chore: tooling / build / CI / housekeeping
- docs: documentation changes only
- style: formatting / lint (no logic change)
- revert: explicit revert commit

Examples:
```
feat(recurring): add semiannual and biennial frequencies
fix(import): correct OFX negative amount normalization edge case
refactor(transaction): extract TransactionBuilder service
```

Rules:
- English only.
- Present tense imperative ("add", "fix", "refactor").
- One logical change per commit (atomic). If you can summarise with "and", probably split.
- Include migration changes and related model updates in the same commit.

## 2. Branching

- main: always green (CI + tests pass). No direct pushes—use PRs.
- feature/<slug>, fix/<slug>, chore/<slug> for work branches.

## 3. Pull Requests
- Small, focused, < ~400 LOC diff when feasible.
- Must include: summary (what/why), test evidence (paste rspec summary), rollback strategy if risky.
- Request review early (draft) for design feedback.

## 4. Testing

Run the full test suite:
```
bundle exec rspec
# or (aggregated check)
bin/verify
```
Focused test examples:
```
bundle exec rspec spec/models/transaction_spec.rb:42
```
Coverage goals (not enforced yet):
- Critical domain models & services (>90%).
- Import pipeline & financial calculations keep parity with spec.

Before committing:
- Ensure suite green locally.
- For migrations: run `bin/rails db:migrate RAILS_ENV=test` and re-run tests.

## 5. Code Style & Lint

- Ruby: follow Rubocop defaults where practical (introduce `.rubocop.yml` if needed later).
- Prefer service objects for multi-step domain logic.
- Avoid fat controllers; keep them as orchestration layers.
- Keep models focused: validations, associations, small query scopes, light domain helpers.

## 6. Architectural Principles

- Double-entry invariant ALWAYS guarded at creation and mutation.
- Separation of accrual (competência) vs cash (caixa) — do not mix silently.
- Projection logic must respect frequency semantics; add tests with boundary dates.
- Idempotency: import & reconciliation operations should be safe on re-run.

## 7. Adding Frequencies / Financial Logic

When extending recurrence or projections:
1. Add enum / validation support.
2. Update projection service.
3. Add model spec + service spec covering realistic horizon windows.
4. Document edge cases in PR description.

## 8. Commit Checklist (Pre-push)
- [ ] Tests green
- [ ] `bin/verify` passes (or equivalent rspec run)
- [ ] No TODO left behind for changed area (or converted to issue)
- [ ] Commit message follows convention
- [ ] Docs updated if user-facing change
- [ ] Projection / financial calculations have at least one assertion in tests

## 9. Secrets & Security
- Never commit credentials; use Rails encrypted credentials or environment variables.
- Scrub PII in logs if added.

## 10. Tooling Shortcuts (Optional)
Add a `bin/quality` later to chain: lint + tests + security scan.

---
These guidelines can evolve; propose edits via PR with `docs:` commit type.

For AI assistant operational guardrails & workflow expectations see: `.github/copilot-instructions.md` (keep both documents consistent when updating process).
