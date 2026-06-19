# Show exhausted quotas and reset transitions

Status: ready-for-agent

## Parent

`.scratch/ai-usage-counter/PRD.md`

## User stories covered

7–12, 16–19, 33–34

## What to build

Complete the quota state model and presentation for low, exhausted, and resetting windows. Hourly and Weekly must transition independently from a remaining percentage to a countdown at zero, trigger a refresh at the reset boundary, and avoid claiming capacity has returned until Codex confirms it.

Apply the agreed threshold colors to Operational bars and use energy-aware countdown cadence: per-second while the popup is visible and minute-level updates in the closed menu bar. Preserve the other quota's valid presentation when only one window is exhausted or fails to refresh.

## Acceptance criteria

- [ ] A positive quota shows its remaining percentage in the menu bar and popup.
- [ ] A zero-percent Hourly quota shows its reset countdown while Weekly continues to show its own valid value.
- [ ] A zero-percent Weekly quota shows its reset countdown while Hourly continues to show its own valid value.
- [ ] When both quotas are exhausted, both countdowns appear independently.
- [ ] Reaching a known reset timestamp triggers one immediate refresh through the usage monitor.
- [ ] The value whose reset boundary has passed shows an ellipsis while its confirming refresh is in flight.
- [ ] If the confirming refresh succeeds, the newly reported remaining percentage replaces the countdown.
- [ ] If the confirming refresh fails, the expired value becomes an em dash while the unaffected quota remains visible.
- [ ] A zero-percent window with no usable reset timestamp displays an unavailable value rather than inventing a countdown.
- [ ] Countdown formatting handles minutes, hours, and days without displaying negative values.
- [ ] Popup countdowns update every second only while the popup is visible.
- [ ] Closed-popup exhausted countdowns update when the displayed minute changes, without a per-second background wakeup.
- [ ] Operational bars use green above 20%, orange from 6% through 20%, red from 0% through 5%, and gray for stale or disconnected states.
- [ ] Progress-bar fill represents quota remaining rather than quota used.
- [ ] Deterministic monitor tests cover independent exhaustion, both exhausted, reset success, reset failure, missing reset time, stale interaction, formatting boundaries, and timer cadence.
- [ ] Fixture-backed SwiftUI smoke tests cover every exhausted/reset presentation with accessible labels that state quota remaining and reset meaning.

## Blocked by

- `03-refresh-scheduling-and-backoff.md`

## Comments

