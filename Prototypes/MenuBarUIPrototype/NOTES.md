# UI Prototype Verdict

## Question

Which popup variant should become the production design?

## Variants

- A — Operational bars
- B — Dual gauges
- C — Reset timeline

## Verdict

**A — Operational bars** was selected by the user.

## Production direction

- Use two stacked quota rows: Hourly first, Weekly second.
- Each row pairs a right-aligned remaining value with a horizontal progress bar and reset countdown.
- Preserve the compact Codex connection header, last-updated status, fixture-validated failure states, and bottom actions.
- Remove the prototype variant switcher and preview-state picker from production.
- Rewrite Variant A against the real `CodexUsageProvider`; do not promote the throwaway view code directly.

The prototype can be deleted after this decision is carried into the PRD or implementation plan.
