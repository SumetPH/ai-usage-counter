# Keep usage fresh with scheduling and backoff

Status: ready-for-agent

## Parent

`.scratch/ai-usage-counter/PRD.md`

## User stories covered

21–32

## What to build

Make the connected quota display remain current without aggressive polling. The usage monitor should coordinate all refresh triggers, preserve a single in-flight request, schedule different foreground and background cadences, recover after sleep and network restoration, and apply the agreed bounded retry backoff.

The user-visible display should preserve the last successful snapshot during failures, show when it was updated, and become visibly stale after ten minutes. This slice establishes the production clock/scheduler seam that the reset-transition slice will use.

## Acceptance criteria

- [ ] The application refreshes immediately at startup and whenever the popup opens.
- [ ] While the popup remains open, the application refreshes every 60 seconds.
- [ ] While the popup is closed, the application refreshes every five minutes.
- [ ] The application requests a refresh after the Mac wakes from sleep and after network connectivity returns.
- [ ] Concurrent startup, popup, timer, wake, network, notification, and manual triggers coalesce into one in-flight provider request.
- [ ] Failures retry after 1, 2, 5, 10, and 15 minutes, then remain capped at 15 minutes.
- [ ] Any successful snapshot resets the retry sequence and resumes the normal refresh cadence.
- [ ] The last successful normalized snapshot remains visible during refresh failures.
- [ ] A snapshot older than ten minutes is marked stale, the popup shows the last-updated age, and menu-bar/popup presentation changes to the agreed gray stale treatment.
- [ ] A fresh successful snapshot clears stale and error presentation immediately.
- [ ] Scheduling is suspended or consolidated appropriately while the Mac sleeps and does not burst multiple requests on wake.
- [ ] The monitor exposes externally observable refresh, connection, snapshot, freshness, and retry state without leaking transport implementation into SwiftUI.
- [ ] Deterministic tests use a fake provider and controllable clock to cover every trigger, cadence, coalescing, backoff interval, stale boundary, successful recovery, sleep/wake, and network recovery.
- [ ] A manual energy smoke test confirms no per-second background timer runs while the popup is closed and quota is not exhausted.

## Blocked by

- `01-live-codex-quota-happy-path.md`

## Comments

