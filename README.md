# AI Usage Counter

A personal macOS 14+ menu bar monitor for the active Codex CLI account.

The menu bar shows `Hourly | Weekly` quota remaining. The popup shows Operational bars, reset countdowns, freshness, connection status, manual refresh, Launch at Login, and Quit.

## Build the app

```bash
rtk bash Scripts/build-app.sh
```

The app bundle is created at `dist/AI Usage Counter.app` and ad-hoc signed for local use.

## Run tests

```bash
rtk swift test
```

The live integration test is opt-in and only validates normalized window shape:

```bash
rtk env AI_USAGE_COUNTER_LIVE_TEST=1 swift test --filter LiveCodexIntegrationTests
```

## Privacy

The app delegates authentication to `codex app-server`. It does not read Codex credential files, request another API key, persist raw responses, or log account identifiers and personal quota values. The cache contains only normalized percentages, reset timestamps, durations, and fetch time.
