# PRD: AI Usage Counter for Codex

Status: ready-for-agent

## Problem Statement

A Codex user working on macOS cannot see their current Hourly and Weekly quota at a glance without interrupting their work and opening Codex. It is easy to discover that a quota is exhausted only when attempting more work, and difficult to know when access will return. The user needs a quiet, trustworthy menu bar utility that exposes the remaining quota and reset timing without repeatedly polling, duplicating credentials, or demanding a separate API key.

## Solution

Build a personal-use, native macOS 14+ menu bar application that reads the active local Codex account's rate-limit snapshot through Codex app-server. The menu bar shows an icon followed by Hourly and Weekly quota remaining. Its popup uses the validated Operational bars layout to show both quotas, reset countdowns, connection state, data freshness, manual refresh, launch-at-login settings, and quit.

The application owns refresh scheduling, exponential backoff, stale-data handling, reset-boundary behavior, and a small normalized cache. It delegates authentication entirely to Codex app-server, never reads or copies Codex credential files, and never persists raw protocol responses.

## User Stories

1. As a Codex user, I want to see Hourly quota remaining in the menu bar, so that I can judge whether to start another coding task.
2. As a Codex user, I want to see Weekly quota remaining beside Hourly quota, so that I understand both constraints without opening a popup.
3. As a Codex user, I want percentages to mean quota remaining consistently, so that a larger number always means more capacity is available.
4. As a Codex user, I want the Hourly value to appear before the Weekly value, so that the compact display has a stable meaning.
5. As a Codex user, I want a recognizable monochrome gauge icon, so that I can locate the utility quickly in the menu bar.
6. As a Codex user, I want a tooltip to explain the value order, so that the compact percentages are not ambiguous.
7. As a Codex user, I want an exhausted Hourly quota to become a reset countdown, so that I know when I can use Codex again.
8. As a Codex user, I want an exhausted Weekly quota to become its own reset countdown, so that both quota windows behave consistently.
9. As a Codex user, I want both countdowns to appear independently when both quotas are exhausted, so that neither reset is hidden.
10. As a Codex user, I want the application to check usage at a reset boundary, so that the display returns to a percentage as soon as fresh data confirms the reset.
11. As a Codex user, I want to see a checking indicator after a countdown reaches zero, so that the application does not falsely claim quota is available.
12. As a Codex user, I want an unavailable indicator when the reset check fails, so that stale assumptions are not presented as facts.
13. As a Codex user, I want to open a compact popup from the menu bar, so that I can inspect details without switching applications.
14. As a Codex user, I want separate Hourly and Weekly operational rows, so that each quota is easy to scan.
15. As a Codex user, I want each quota row to show a remaining value, progress bar, and reset countdown, so that magnitude and timing are visible together.
16. As a Codex user, I want healthy quota levels shown in green, so that normal status is recognizable quickly.
17. As a Codex user, I want low quota levels shown in orange, so that I receive a quiet visual warning before exhaustion.
18. As a Codex user, I want nearly exhausted quota levels shown in red, so that critical capacity is obvious.
19. As a Codex user, I want stale or disconnected information shown in gray, so that it cannot be confused with current data.
20. As a Codex user, I want to see whether Codex is connected, so that I can distinguish account problems from exhausted quota.
21. As a Codex user, I want to see when data was last updated, so that I can judge its freshness.
22. As a Codex user, I want the last successful values preserved during temporary failures, so that a network hiccup does not erase useful context.
23. As a Codex user, I want preserved values marked stale after ten minutes, so that old data is never presented as current.
24. As a Codex user, I want a manual Refresh action, so that I can request a new snapshot when needed.
25. As a Codex user, I want overlapping refresh requests coalesced, so that repeated actions do not start duplicate Codex app-server calls.
26. As a Codex user, I want the application to refresh when I open the popup, so that detailed information becomes current when I inspect it.
27. As a Codex user, I want faster refreshes while the popup is open, so that actively viewed data remains current.
28. As a Codex user, I want restrained background refreshes, so that the utility does not waste battery or constantly poll Codex.
29. As a Codex user, I want refresh after the Mac wakes from sleep, so that suspended data is corrected promptly.
30. As a Codex user, I want refresh after network connectivity returns, so that transient offline periods recover automatically.
31. As a Codex user, I want failed refreshes to back off progressively, so that an outage does not create aggressive retry traffic.
32. As a Codex user, I want a successful refresh to clear the retry backoff, so that normal behavior resumes immediately.
33. As a Codex user, I want popup countdowns to update every second, so that an imminent reset feels accurate while I am watching it.
34. As a Codex user, I want closed-popup countdowns to update only when the minute changes, so that the utility remains energy efficient.
35. As a Codex CLI user, I want the application to reuse my active Codex sign-in, so that I do not manage another API key.
36. As a privacy-conscious user, I want the application never to read or copy Codex credential files, so that credentials remain owned by Codex.
37. As a privacy-conscious user, I want raw account responses excluded from persistence and logs, so that unnecessary account data is not retained.
38. As a Codex user, I want an actionable disconnected message when I am signed out, so that I know to sign in through Codex CLI and retry.
39. As a Codex user, I want an actionable message when the Codex executable is unavailable, so that I can repair the local installation.
40. As a Codex user, I want account switching in Codex CLI to be detected through a fresh snapshot, so that the utility follows the active account.
41. As a Mac user, I want the application to live only in the menu bar, so that it does not occupy Dock or window-switcher space.
42. As a Mac user, I want the interface to follow Light and Dark Mode automatically, so that it remains legible with my system appearance.
43. As a Mac user, I want an optional Launch at Login setting, so that the monitor can start automatically when desired.
44. As a Mac user, I want Launch at Login disabled by default, so that the application does not change startup behavior without my choice.
45. As a Mac user, I want a Quit action in the popup, so that I can stop the utility explicitly.
46. As a personal-use user, I want the application to run locally without signing, notarization, or an updater, so that the first version remains simple.
47. As a user encountering a Codex protocol change, I want the application to fail safely while retaining the last valid snapshot, so that a schema change does not show fabricated values.
48. As a user starting the application, I want the first snapshot to tolerate normal Codex startup latency, so that a slower initial response is not reported prematurely as failure.

## Implementation Decisions

- Build a native Swift application targeting macOS 14 or later, using SwiftUI and `MenuBarExtra` with window-style popup behavior.
- Run as a menu-bar-only application with no main window and no Dock presence.
- Use English interface copy and system locale-aware date/time formatting.
- Support one active Codex CLI account and the Codex provider only in the MVP.
- Introduce a `CodexUsageProvider` boundary that owns Codex executable discovery, app-server process lifecycle, JSONL transport, initialization, snapshot requests, and rolling rate-limit updates.
- Prefer an owned Codex app-server stdio child process for the application session. Shut it down with the application and restart it through bounded backoff when it exits unexpectedly.
- Resolve the Codex executable from the application environment and common package-manager installations. Report a distinct unavailable state when no executable can be launched.
- Perform the documented app-server initialization handshake before requesting `account/rateLimits/read` and consume `account/rateLimits/updated` while the connection remains active.
- Do not read Codex authentication files, request a separate API key, automate login, or call an upstream private HTTP endpoint directly.
- Decode app-server payloads defensively because generated schemas are tied to the installed Codex CLI version. Ignore unknown fields and convert missing or malformed required quota data into a provider error rather than guessed values.
- Normalize each provider snapshot into Hourly and Weekly windows containing remaining percentage, optional reset timestamp, optional duration, and fetch timestamp.
- Derive remaining percentage as `clamp(100 - usedPercent, 0...100)`.
- Identify Hourly and Weekly windows by duration, choosing the shorter supported rate-limit window as Hourly and the longer window as Weekly instead of assuming primary/secondary field names are permanent. The validated current durations are five hours and seven days.
- Require both normalized windows for a fully connected display. Preserve the last valid snapshot when a later payload is incomplete.
- Allow at least 30 seconds for the first account snapshot because the validated live prototype observed a slow initial response. Later requests may use a shorter operational timeout chosen during implementation.
- Place scheduling and user-visible state in a single `UsageMonitor` boundary. It owns connection state, refresh state, the latest valid snapshot, stale calculation, retry state, countdown presentation, and coalescing of concurrent refresh triggers.
- Inject the provider and a clock/scheduler into `UsageMonitor` so all timing and failure transitions can be exercised deterministically.
- Refresh immediately at startup, whenever the popup opens, every 60 seconds while the popup remains open, every five minutes in the background, after wake, after network restoration, and at each known reset boundary.
- Coalesce simultaneous refresh triggers into one in-flight provider request.
- Retry failures after 1, 2, 5, 10, and then 15 minutes; cap subsequent retries at 15 minutes until success. Reset backoff after a successful snapshot.
- Preserve the last successful snapshot across refresh failures. Mark it stale when its fetch time is more than ten minutes old.
- Compute countdowns locally from reset timestamps without network polling. Update visible popup countdowns every second and exhausted menu-bar countdowns once per minute while the popup is closed.
- In the menu bar, display the monochrome gauge SF Symbol followed by `Hourly | Weekly`. Show remaining percentages while positive. At zero, show the corresponding reset countdown. After the reset timestamp, show an ellipsis while checking and an em dash when checking fails or reset data is unavailable.
- Provide a tooltip identifying the value order and explaining that both values are quota remaining.
- Implement the selected Operational bars popup: compact Codex status header, last-updated text, Hourly row, Weekly row, then Refresh, Settings, and Quit actions.
- Each quota row shows a right-aligned remaining value, a progress bar whose filled amount represents quota remaining, and a reset countdown.
- Use green above 20% remaining, orange from 6% through 20%, and red from 0% through 5%. Use gray treatment for stale and disconnected presentation.
- Show `Codex not connected` with instructions to sign in using Codex CLI and a Retry action when app-server reports no authenticated account. Do not open Terminal or start login automatically.
- Disable or show progress on the manual Refresh action while a request is already in flight.
- Keep the Settings surface limited to Launch at Login for the MVP. Implement it with the macOS service-management API and default it to off.
- Persist only the Launch at Login preference and the latest normalized percentages, reset timestamps, and fetch timestamp. Do not persist raw responses, tokens, account identifiers, or credentials.
- Restore a cached normalized snapshot on launch as stale until a live refresh succeeds.
- Avoid logging raw app-server messages. Diagnostic logs may contain lifecycle state, categorized errors, durations, and Codex CLI version but no credentials, account identifiers, or personal usage values.
- Rewrite production code from the validated decisions. Do not promote the throwaway TUI or UI variant implementations directly.

## Testing Decisions

- Tests should assert externally observable state and behavior rather than private methods, view hierarchy details, timer implementation, or transport internals.
- The primary automated seam is `UsageMonitor`. Drive it with a fake `CodexUsageProvider` and controllable clock, then assert the state consumed by the menu bar and popup.
- At the primary seam, cover successful startup, slow first response, manual refresh, popup/background cadence, coalesced triggers, wake and network restoration, all backoff intervals, backoff reset, stale transition, cached startup state, disconnected account, missing executable, provider crash, malformed snapshot, account change, and recovery.
- At the primary seam, cover percentage display, independent Hourly/Weekly exhaustion, both exhausted, reset countdown progression, checking at reset, success after reset, failure after reset, missing reset timestamp, tooltip semantics, and minute-versus-second countdown cadence.
- The protocol-boundary seam is `CodexUsageProvider`. Decode sanitized fixtures representing the current successful schema, unknown added fields, missing windows, null reset timestamps, reordered primary/secondary windows, alternate limit buckets, server errors, unauthenticated state, and malformed JSONL.
- Add a process-level provider test with a stub app-server executable to verify initialization ordering, request correlation, notifications, process exit, timeout, restart, and safe shutdown without using a real account.
- Keep one opt-in live integration test that calls the locally authenticated Codex app-server and validates only that two usable normalized windows are returned. It must not print or persist raw responses or personal quota values.
- Add focused SwiftUI smoke tests using a fixture-backed `UsageMonitor` for connected, stale, disconnected, Hourly exhausted, Weekly exhausted, both exhausted, and reset-refresh-failed states.
- UI tests should verify accessible labels, actions, status meaning, and menu-bar/popup presentation state. They should not compare pixels or depend on the private SwiftUI view tree.
- Manually verify menu-bar-only behavior, Dock absence, Light/Dark Mode, popup sizing, minute updates while closed, per-second updates while open, sleep/wake recovery, network recovery, Launch at Login, and Quit on a real macOS 14+ system.
- The codebase has no production-test prior art. The two throwaway prototypes are evidence for expected state transitions and visual hierarchy, not production test code.

## Out of Scope

- Providers other than Codex.
- Multiple simultaneous accounts or manual account selection.
- Provider visibility selectors or menu-bar source selectors before another provider exists.
- Usage history, charts, analytics, or long-term storage.
- Token counts, request counts, credits, billing, or monetary cost.
- Notifications or threshold alerts.
- User-configurable refresh intervals, retry schedules, stale thresholds, or color thresholds.
- A main application window, Dock icon, widgets, or iOS companion.
- Automated Codex installation, authentication, logout, or account switching.
- Reading Codex credential files or calling private upstream HTTP endpoints directly.
- App Sandbox support.
- Mac App Store distribution, code signing, notarization, packaging, auto-update, or public release infrastructure.
- Localization beyond English.
- Production reuse of throwaway prototype source code.

## Further Notes

- The logic prototype validated live Codex app-server access, the normalized quota contract, and exhaustion/reset transitions. Its durable verdict is recorded in the prototype notes.
- The native UI prototype compared three popup hierarchies. The user selected Variant A, Operational bars; its durable verdict is recorded in the UI prototype notes.
- The application is for personal use, but privacy boundaries remain strict: credentials and raw account responses are never copied into application persistence, fixtures, PRD artifacts, or logs.
- Codex app-server is the chosen integration surface. Compatibility with future Codex CLI versions should be treated as a boundary concern and surfaced as a recoverable provider error.

## Comments

