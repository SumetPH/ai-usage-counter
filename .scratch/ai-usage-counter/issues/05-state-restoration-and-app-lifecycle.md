# Restore state and manage app lifecycle

Status: ready-for-agent

## Parent

`.scratch/ai-usage-counter/PRD.md`

## User stories covered

22, 41–46

## What to build

Finish the personal-use application lifecycle around the live monitor. Restore the latest normalized snapshot as stale during startup, replace it after live confirmation, expose an in-memory Settings surface with a real Launch at Login toggle, and ensure the utility behaves like a proper menu-bar-only macOS application.

Persistence must remain deliberately narrow: normalized quota values, reset timestamps, fetch time, and the launch preference only. The application should start and stop cleanly, preserve privacy boundaries, and provide a reliable Quit action.

## Acceptance criteria

- [ ] The latest successful normalized Hourly/Weekly snapshot and fetch timestamp are cached without raw responses, credentials, account identifiers, or transport metadata.
- [ ] On launch, a cached snapshot appears immediately with stale treatment until a live snapshot succeeds.
- [ ] A corrupt, incomplete, or unsupported cache is ignored safely and does not block live refresh.
- [ ] A successful live snapshot replaces the startup cache and clears stale presentation.
- [ ] Settings contains only Launch at Login for the MVP.
- [ ] Launch at Login is disabled by default and uses the macOS service-management API when toggled.
- [ ] The displayed Launch at Login state reflects the system registration result and reports a recoverable error if registration fails.
- [ ] The application has no main window or Dock icon during normal operation.
- [ ] Quit stops refresh scheduling, closes the provider session, terminates the owned app-server process, and exits cleanly.
- [ ] Application startup and shutdown do not leave orphaned app-server processes.
- [ ] Cache and settings tests verify allowed fields, privacy exclusions, corrupt-data recovery, startup stale state, and replacement by live data.
- [ ] Fixture-backed UI tests verify Settings, Launch at Login state, stale startup presentation, and Quit accessibility.
- [ ] Manual macOS smoke testing verifies menu-bar-only behavior, Dock absence, Light/Dark Mode, Launch at Login, sleep/wake continuity, and clean Quit.

## Blocked by

- `03-refresh-scheduling-and-backoff.md`

## Comments

