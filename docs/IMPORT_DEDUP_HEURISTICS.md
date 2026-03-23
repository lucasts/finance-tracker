# Import Dedup Heuristics

This document describes the advanced duplicate filtering applied when importing transactions (CSV / OFX).

## Goals
* Prevent creation of duplicate imported lines arising from re‑exported files or bank adjustments.
* Be tolerant to minor date slips and rounding (R$0.01) so near duplicates are suppressed automatically.
* Surface likely duplicates (similar) to the user for manual review without blocking import.

## Normalization
1. Description is lowercased, multiple spaces collapsed, punctuation removed, accents removed (I18n.transliterate), then trimmed.
2. Amounts are parsed to BigDecimal; negative CSV values are converted to positive expenses by the parser.
3. Dates are parsed to Date objects.

## Heuristic Rules (applied per parsed line in order)
| Rule | Condition | Action |
| ---- | --------- | ------ |
| Exact Duplicate | same normalized description AND same date AND amount diff <= 0.01 | Skip (not created) |
| Tolerance Duplicate | same normalized description AND date diff <= 1 day AND amount diff <= 0.01 | Skip |
| Similar (Flag Only) | (a) same (or 1-edit) normalized description AND date diff <= 3 days (DATE_TOLERANCE_DAYS) AND amount diff <= 2.00 OR (b) any prior txn (even different description >1 edit) within those date & amount windows | Create & mark `possible_duplicate = true` |
| Approximate Description | If no bucket match, approximate matches within 1 edit (insertion/substitution) are merged into the same candidate set for evaluation of the above rules | Treated as if same normalized description |

If none of the duplicate rules apply, the record is created normally.

## Rationale
* 1‑day slip & 0.01 difference covers timezone posting delays and rounding adjustments.
* 3‑day similarity window aligns with broader posting delays; R$2 difference filters noise while still surfacing manual review candidates.
* One‑edit distance catches accent / encoding losses (e.g., `ALMOÇO` vs `ALMOO`).

## Configurable Tolerances

All tolerance values are configurable app-wide via **`config/dedup.yml`** without code changes.
The file is environment-aware (`default`, `development`, `test`, `production` sections with YAML anchors).

| YAML key | Default | Description |
|---|---|---|
| `exact_amount_tolerance` | 0.01 | Max amount diff (R$) for exact/tolerance dedup (rules 1–2) |
| `exact_date_tolerance_days` | 1 | Max date diff (days) for tolerance dedup (rule 2) |
| `similar_amount_tolerance` | 2.00 | Max amount diff (R$) for `possible_duplicate` flag (rule 3) |
| `similar_date_tolerance_days` | 3 | Max date diff (days) for `possible_duplicate` flag (rule 3) |
| `matching_amount_percentage` | 0.05 | Percentage of imported amount used as matching tolerance in `ImportMatchingService` |
| `recurring_amount_tolerance` | 0.10 | Percentage tolerance for recurring commitment match |
| `transfer_date_tolerance_days` | 2 | Max date diff (days) between transfer pair (`TransferDetectionService`) |
| `transfer_amount_tolerance` | 0.01 | Max amount diff (R$) between transfer pair |

`FinancialConstants` exposes the same values as Ruby constants (e.g., `EXACT_DATE_TOLERANCE_DAYS`, `SIMILAR_AMOUNT_TOLERANCE`) for use in service defaults and legacy code paths.

## Future Enhancements
* Metrics (count of duplicates skipped, flagged) for admin dashboards.
* Adapt heuristics using historical user confirmation patterns.

## Testing
Unit specs (`spec/services/import_dedup_service_spec.rb`) cover:
* Exact duplicate suppression.
* Tolerance duplicate suppression.
* Approximate description duplicate.
* Similar flag behavior.
* Non‑duplicate when description distance > 1 (still flagged similar via fallback rule if within similarity window for date & amount).
* **Mixed batch**: 1 new + 1 duplicate in the same import call.
* **Missing external_id**: dedup functions normally without an `external_id`.
* **Rounded amounts**: amounts within `exact_amount_tolerance` (e.g., 50.004 vs 50.00) are treated as duplicates.
* **Cross-file explicit**: duplicates detected across different import sessions for the same account.
* **Boundary dates**: exactly `similar_date_tolerance_days` triggers flag; one day beyond does not.
* **Amount boundary**: amount diff > `similar_amount_tolerance` suppresses the `possible_duplicate` flag.

Request specs ensure end‑to‑end dedup and idempotency (same file re-upload → redirects to reimport summary, no new session created).
