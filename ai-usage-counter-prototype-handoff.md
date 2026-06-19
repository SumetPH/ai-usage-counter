# Handoff: AI Usage Counter Prototype

## Next-session objective

Build a throwaway prototype that answers the two highest-risk questions for a personal macOS menu bar app:

1. Can Hourly and Weekly Codex quota remaining plus reset timestamps be obtained reliably from the locally authenticated Codex CLI session?
2. Does the proposed compact menu bar and popup interaction work well on macOS 14+?

The prototype is for learning, not production implementation.

## Repository state

Repository: `/Users/sumetph/Documents/ai-usage-counter`

The repository currently contains only the engineering-skill setup. Read these instead of recreating their contents:

- `/Users/sumetph/Documents/ai-usage-counter/AGENTS.md`
- `/Users/sumetph/Documents/ai-usage-counter/docs/agents/issue-tracker.md`
- `/Users/sumetph/Documents/ai-usage-counter/docs/agents/triage-labels.md`
- `/Users/sumetph/Documents/ai-usage-counter/docs/agents/domain.md`

There are no commits and no Git remote. Issues are configured as local markdown under `.scratch/`. Domain docs use a single-context layout.

## Agreed product scope

- Personal-use native macOS menu bar app, targeting macOS 14 Sonoma or later.
- SwiftUI with `MenuBarExtra`; menu bar only, with no Dock icon or main window.
- MVP supports one active Codex CLI account only.
- Read the existing Codex authentication/session read-only. Do not ask for another API key, duplicate credentials, log tokens, or persist raw responses.
- Codex-only UI for MVP, while the eventual production design may use a provider adapter internally.
- English UI.

## Agreed menu bar behavior

- Use the monochrome SF Symbol `gauge.with.dots.needle.50percent`.
- Normal display: icon followed by `50% | 80%`.
- First value is Hourly quota remaining; second is Weekly quota remaining.
- Percentages always mean quota remaining.
- If one quota reaches 0%, replace that value with its reset countdown independently, e.g. `1h 24m | 80%` or `1h 24m | 2d 5h`.
- When a reset countdown reaches zero, refresh immediately. Show `…` while checking and `—` if the refresh fails; never assume the quota reset to 100%.
- Tooltip should clarify the order and meaning of the values.

## Agreed popup behavior

- Header: Codex connection state and last-updated time.
- Separate Hourly and Weekly progress rows showing percent remaining and `Resets in …`.
- Actions: Refresh, Settings, and Quit.
- Settings contains only `Launch at Login` in MVP, off by default.
- Progress colors: green above 20%, orange from 6–20%, red from 0–5%, gray when stale or disconnected.
- If unauthenticated, show `Codex not connected`, instruct the user to sign in through Codex CLI, and offer Retry. Do not launch or automate the login flow.

## Refresh and failure policy

- Refresh immediately when the popup opens.
- Refresh every 60 seconds while the popup is open and every 5 minutes in the background.
- Refresh after wake from sleep, network restoration, and at a quota reset boundary.
- Retry backoff: 1, 2, 5, 10, then 15 minutes.
- Popup countdown updates every second. A closed popup updates an exhausted menu-bar countdown only when the minute changes.
- Preserve the last successful values on failure. Mark data stale after 10 minutes and dim the menu-bar state.
- Cache only normalized percentages, reset times, and last-refresh time in `UserDefaults`.

## Data-source investigation order

1. Officially supported Codex API or local data.
2. Codex CLI local usage state.
3. The authenticated endpoint used by Codex CLI.

Do not scrape UI. Treat any undocumented endpoint as unstable and isolate it behind a replaceable adapter. Do not expose credentials or raw authentication files in command output, fixtures, logs, or this handoff.

## Prototype deliverables

- Record which data source was tested and whether it provides Hourly/Weekly remaining percentages and reset timestamps.
- Build a runnable menu bar prototype with selectable fixture states at minimum: connected, disconnected, stale, Hourly exhausted, Weekly exhausted, both exhausted, and reset-refresh failure.
- Prefer fixtures until a safe live integration is established.
- Capture conclusions, limitations, and the recommended production interface in the handoff back to the product-design thread.
- Tests should cover response normalization, percentage semantics, countdown formatting, reset transitions, and backoff. Live integration tests must be opt-in.

## Explicit MVP non-goals

- Other AI providers or multiple simultaneous accounts.
- Usage history or charts.
- Token counts or monetary cost.
- Notifications.
- User-configurable refresh intervals.
- Signing, notarization, App Store distribution, and auto-update.

## Suggested skills

1. Invoke `/prototype` first. This work needs runnable answers for both data access and menu bar UI.
2. When the prototype has answered the open questions, invoke `/handoff` again to carry the findings back into a fresh planning session.
3. After returning to the product-design flow, use `/to-prd` and `/to-issues` if the implementation will span multiple sessions.

## Definition of done for the next session

The session is done when it can state, with evidence, whether live Codex quota data is obtainable safely and what adapter contract production code should use, while also providing a runnable fixture-driven menu bar UI that validates the agreed display and reset states.
