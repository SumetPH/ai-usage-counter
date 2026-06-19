# AI Usage Counter — Throwaway Menu Bar UI Prototype

> **PROTOTYPE: choose a direction, record the verdict, then delete or rewrite it.**

## Question

Which native popup hierarchy makes Hourly and Weekly quota remaining, reset timing, stale data, and disconnected states easiest to understand at menu-bar scale?

Three structurally different variants live in the same native `MenuBarExtra`:

- **A — Operational bars:** conventional progress rows optimized for scanning.
- **B — Dual gauges:** symmetrical visual comparison with large circular meters.
- **C — Reset timeline:** time-first hierarchy emphasizing when access returns.

Use the black bottom switcher or the left/right arrow keys to move between variants. Use **Preview state** to inspect every fixture.

## Run

```bash
rtk swift run --package-path /Users/sumetph/Development/llm/ai-usage-counter/MenuBarUIPrototype menubar-ui-prototype
```

Look for the gauge icon and quota text in the macOS menu bar. The prototype is fixture-only and performs no network calls or persistence.
