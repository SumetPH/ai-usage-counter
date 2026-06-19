# Ship live Codex quota happy path

Status: ready-for-agent

## Parent

`.scratch/ai-usage-counter/PRD.md`

## User stories covered

1–6, 13–15, 24, 35–37, 41–42

## What to build

Build the first production-quality vertical path from a locally authenticated Codex app-server session to the native macOS menu bar. On launch, the application should initialize app-server, request the current rate-limit snapshot, normalize the shorter and longer windows into Hourly and Weekly quota remaining, and present them in the selected Operational bars popup.

The menu bar should use the agreed gauge icon and `Hourly | Weekly` remaining-percent format. The popup should show a compact Codex status header, two quota rows with progress bars and reset timing, a working manual Refresh action, Settings entry point, and Quit action. This slice covers the connected happy path only; failure recovery, background scheduling, exhausted-state transitions, and persistent settings are delivered by later slices.

Production code must be newly implemented from the validated decisions rather than copied from the throwaway prototypes.

## Acceptance criteria

- [ ] A native SwiftUI `MenuBarExtra` application builds and runs on macOS 14 or later without a main window.
- [ ] With Codex CLI available and signed in, the application completes the app-server initialization handshake and requests `account/rateLimits/read`.
- [ ] The response is normalized into Hourly and Weekly windows using window duration rather than relying on primary/secondary ordering.
- [ ] Remaining quota is derived as `clamp(100 - usedPercent, 0...100)` and displayed consistently as quota remaining.
- [ ] The menu bar shows the monochrome gauge icon followed by `Hourly | Weekly` percentages and exposes an explanatory tooltip.
- [ ] The popup implements the selected Operational bars hierarchy with Hourly first, Weekly second, remaining values, progress bars, reset timing, connection header, and last-updated text.
- [ ] Manual Refresh obtains a new snapshot and prevents overlapping refresh requests.
- [ ] The interface follows system Light and Dark Mode and uses English copy with locale-aware time formatting.
- [ ] The provider never reads Codex credential files, requests another API key, or calls a private upstream HTTP endpoint directly.
- [ ] Raw app-server responses, credentials, account identifiers, and personal quota values are not persisted or written to diagnostic logs.
- [ ] Automated tests cover successful protocol decoding, duration-based window mapping, percentage normalization, monitor happy-path state, refresh coalescing, and accessible connected UI state.
- [ ] A manual smoke test confirms that a real locally authenticated Codex account produces usable Hourly and Weekly values in the menu bar and popup without exposing the raw response.

## Blocked by

None - can start immediately

## Comments

