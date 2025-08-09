# Copilot / AI Agent Instructions

These directives define how the AI assistant should behave for this repository.

## Goals
- Maintain strict double-entry accounting integrity.
- Keep financial projections accurate, traceable, and tested.
- Sustain a small, coherent, refactor-friendly Rails codebase.

## Always Do
- Use English for commit messages, code comments, and PR titles; keep UI text in pt-BR.
- Make commits atomic: one cohesive change (code + tests + docs together).
- Run the full test suite before suggesting a commit (or at least affected subset if speeding up, then full before merge).
- Add or update tests for any domain logic touched (models, services, projections, import heuristics).
- Preserve existing public APIs unless refactor commit states otherwise.
- Validate double-entry: sum(debit amounts) == sum(credit amounts) for every created transaction.
- Respect competence (event_date) vs cash (payment_date) separation in calculations.
- Add projection logic only with horizon tests covering boundary cases.
- Reference issue or rationale in commit body when non-trivial.

## Never Do
- Introduce schema changes without a migration in same commit.
- Silence or remove validations to “make tests pass”.
- Mix unrelated refactors and features.
- Commit failing tests (unless using a deliberate `test:` commit to reproduce a bug and immediately following with a `fix:` commit—prefer squashing later).
- Hardcode secrets, API keys, or personal data.

## Commit Message Convention
Format:
```
<type>(optional-scope): <imperative short summary>

Optional body explaining WHY (not a restatement of the diff). Wrap at 100 columns.
Refs: #<issue-id>
```
Types: feat | fix | refactor | perf | test | chore | docs | style | revert.

Examples:
```
feat(recurring): support fortnightly and semiannual frequencies
fix(import): correct negative amount normalization in OFX edge case
refactor(transaction): extract TransactionBuilder to unify entry generation
```

## Test Commands
- Full suite:
  `bundle exec rspec`
- Single file:
  `bundle exec rspec spec/models/transaction_spec.rb`
- Specific example:
  `bundle exec rspec spec/models/transaction_spec.rb:42`

## Pre-Commit Checklist
- [ ] All tests green (`bin/verify` or `bundle exec rspec`)
- [ ] Added/updated tests for new or changed logic
- [ ] Commit message follows convention
- [ ] No accidental puts/debugger/
- [ ] Docs / comments updated if behavior changed
- [ ] Projection / financial math has an assertion

## Architectural Principles
- Controllers orchestrate; heavy logic lives in service objects or POROs.
- Projection services must be deterministic given inputs (no time.now scatter—pass reference date).
- Import pipeline idempotent: re-processing same file should not duplicate committed data.
- Keep model concerns small and purpose-driven (normalization, formatting, etc.).

## Patterns
- When adding new frequency or financial rule: update enums/validations -> service logic -> specs (positive + boundary + edge) -> documentation.
- When adding a new accounting transformation: create a service, not a fat callback chain.
- Prefer query scopes to raw SQL strings; ensure indices for new high-selectivity queries.

## Performance Considerations
- Avoid N+1 in dashboard & projection queries (preload associations as needed).
- Use database sums instead of loading collections into Ruby when feasible.

## Safety Nets to Implement (if missing)
- bin/verify script (tests + optional lint + security checks).
- Optional RuboCop / Brakeman integration (future).

## Interaction Guidance
When the AI is asked to perform multi-step code changes:
1. Read relevant files.
2. Update tests first (if TDD feasible for bug fix) or in same commit for feature.
3. Run tests, iterate until green.
4. Summarize changes referencing this file for consistency.

If ambiguity: ask for clarification succinctly before large changes.

---
Update this file via `docs:` commit type when process evolves.
