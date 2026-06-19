# Prototype Verdict

## Question

Can Codex rate-limit windows safely drive the Hourly/Weekly remaining-percentage and reset state model?

## Evidence collected

- Official [Codex app-server documentation](https://developers.openai.com/codex/app-server) describes app-server as the integration interface for rich clients and documents its JSONL initialization flow.
- The schema generated locally by Codex CLI 0.139.0 exposes `account/rateLimits/read` and `account/rateLimits/updated`.
- The generated response schema supplies `usedPercent`, `resetsAt`, and `windowDurationMins` for primary and secondary windows.
- A live opt-in probe succeeded against the locally authenticated Codex session. It returned two normalized windows with durations of 300 and 10,080 minutes and valid reset timestamps.
- Fixture runs confirmed the agreed transitions: remaining percentage → countdown at 0% → `…` at the reset boundary → `—` when the reset refresh fails.

## Verdict

Validated. Codex app-server can provide the exact Hourly and Weekly inputs needed by the menu bar app without the app reading or copying authentication credentials.

## Production decision to carry forward

Use a replaceable `CodexUsageProvider` that launches or connects to Codex app-server, performs the documented initialization handshake, requests `account/rateLimits/read`, and listens for `account/rateLimits/updated` while connected.

Normalize each window to `{ remainingPercent, resetsAt, durationMinutes }`. Derive remaining as `clamp(100 - usedPercent)` and identify Hourly/Weekly by duration rather than the primary/secondary field names. Allow at least 30 seconds for the first snapshot; subsequent refresh scheduling belongs to production code.

Do not read `~/.codex` auth files or call the upstream HTTP endpoint directly. The generated app-server schema is version-specific, so decode defensively and preserve fixtures for shape changes.
