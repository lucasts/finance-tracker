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

## Future Enhancements
* Per‑user configurable tolerances.
* Metrics (count of duplicates skipped, flagged) for admin dashboards.
* UI highlight & bulk resolution actions for flagged items.
* Adapt heuristics using historical user confirmation patterns.

## Testing
Unit specs (`spec/services/import_dedup_service_spec.rb`) cover:
* Exact duplicate suppression.
* Tolerance duplicate suppression.
* Approximate description duplicate.
* Similar flag behavior.
* Non‑duplicate when description distance > 1 (still flagged similar via fallback rule if within similarity window for date & amount).

Request specs ensure end‑to‑end behavior remains intact.
