# Recover from Codex connection and protocol failures

Status: ready-for-agent

## Parent

`.scratch/ai-usage-counter/PRD.md`

## User stories covered

20, 22, 35–40, 47–48

## What to build

Extend the live quota path so the application fails safely and explains what the user can do when Codex is unavailable, signed out, slow, incompatible, or interrupted. The provider should discover a usable Codex executable, own the app-server child-process lifecycle, decode version-specific payloads defensively, consume rolling rate-limit updates, and turn transport/protocol outcomes into stable user-visible connection states.

The popup should distinguish a missing Codex installation from a signed-out account, preserve the last valid normalized snapshot during later failures, and offer Retry without opening Terminal or automating login. A new valid snapshot should naturally follow the account currently active in Codex CLI.

## Acceptance criteria

- [ ] The application resolves a usable Codex executable from the application environment and common package-manager installations.
- [ ] A missing or unlaunchable executable produces a distinct actionable state rather than being reported as exhausted quota.
- [ ] A signed-out Codex session shows `Codex not connected`, instructs the user to sign in with Codex CLI, and provides Retry without launching a login flow.
- [ ] The first account snapshot allows at least 30 seconds before timing out.
- [ ] Unknown response fields are ignored, while malformed JSONL, missing required windows, invalid percentages, and unusable durations become categorized provider errors.
- [ ] A malformed or partial update never replaces the last valid normalized snapshot with guessed or zero values.
- [ ] The application consumes `account/rateLimits/updated` notifications and merges or refetches sparse updates without clearing previously valid nullable metadata incorrectly.
- [ ] Unexpected app-server exit, broken transport, request error, and timeout are surfaced safely and can recover through Retry.
- [ ] The owned app-server process is terminated cleanly when its provider session ends.
- [ ] A later valid snapshot replaces the previous account snapshot without retaining account-specific raw metadata.
- [ ] The popup and menu bar use disconnected or stale-safe presentation and never present provider errors as available quota.
- [ ] Sanitized fixture tests cover current schema, added unknown fields, null reset timestamps, reordered windows, alternate limit buckets, malformed data, unauthenticated response, and server error.
- [ ] A stub app-server process test verifies handshake ordering, request correlation, notifications, slow first response, process exit, timeout, Retry, and safe shutdown.
- [ ] The opt-in live integration test validates only the normalized two-window result and never prints or persists personal values or raw responses.

## Blocked by

- `01-live-codex-quota-happy-path.md`

## Comments

