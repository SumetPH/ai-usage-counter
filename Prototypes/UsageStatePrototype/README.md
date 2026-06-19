# AI Usage Counter — Throwaway State Prototype

> **PROTOTYPE: delete or absorb after the question is answered.**

## Question

Can the Codex account rate-limit snapshot be normalized into Hourly and Weekly quota-remaining values, and does the agreed state model behave correctly across exhaustion, reset, stale, disconnected, and refresh-failure transitions?

The pure reducer is in `Sources/UsagePrototype/UsageModel.swift`. The terminal shell and live probe are disposable.

## Run

Requires macOS 14+, Swift 6, and Codex CLI for the optional live probe.

```bash
rtk swift run usage-prototype
```

Use fixture keys first. Press `l` only when you want to query the locally authenticated Codex account through `codex app-server`. The probe does not read credential files and prints only normalized quota values.

The first live request may take up to 30 seconds while Codex refreshes the account snapshot.

## Data contract being tested

Codex CLI 0.139.0 generates an app-server schema containing `account/rateLimits/read`. Each rate-limit window provides:

- `usedPercent`
- `resetsAt` (Unix timestamp)
- `windowDurationMins`

The prototype derives `remainingPercent = clamp(100 - usedPercent)` and orders the two windows by duration rather than assuming primary always means Hourly.

No raw app-server response, account identifier, or credential is persisted.
