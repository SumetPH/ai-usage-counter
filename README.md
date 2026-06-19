# AI Usage Counter

An elegant, lightweight macOS menu bar utility to monitor rate limits and quotas for Codex CLI and Google Antigravity (Google Cloud Code Assist).

Built with SwiftUI and Swift 6, this tool resides in your menu bar to keep you informed of your current API usage limits and remaining quota at a glance.

---

## Features

- **Menu Bar Monitor**: Displays the current status of your preferred provider directly in the menu bar. If a quota is low or stale, the indicator adapts automatically.
- **Detailed Popover View**: Click the menu bar icon to reveal:
  - **Enabled Providers**: Toggle individual providers on/off in the Settings menu.
  - **Quota Progress Bars**: Visual bars displaying remaining percentage with color indicators (Green for healthy, Orange for <= 20%, Red for <= 5%).
  - **Reset Countdowns**: Real-time countdowns showing exactly when rate limits will reset.
  - **Connection & Freshness Status**: Clear indicators showing whether data is live, stale, or offline.
  - **Manual Refresh Control**: Instantly refresh individual or all providers.
- **Provider Support**:
  - **Codex CLI**: Integrates with the local `codex app-server` to fetch Hourly and Weekly rate limits.
  - **Google Antigravity**: Uses Google's private Cloud Code Assist endpoint. Features browser-based OAuth with PKCE for single-account authentication, and Keychain storage for persistent credentials. Automatically detects and lets you choose between available models (e.g., Gemini, Claude).
- **Smart Refreshing**:
  - Automatically updates in the background (every 5 minutes, or every 1 minute when the popover is active).
  - Listens to system wake notifications (`didWakeNotification`) and network restoration events to refresh usage data instantly.
- **Launch at Login**: Easily toggle system startup launch settings from the application menu.

---

## Project Structure

The project is structured as a Swift Package with two primary targets:

### Core Logic Target: `AIUsageCounterCore`
- [**AntigravityProvider.swift**](Sources/AIUsageCounterCore/AntigravityProvider.swift): Manages Google OAuth PKCE authentication flow, access token refresh, and Google Cloud Code Assist endpoint queries.
- [**CodexAppServerProvider.swift**](Sources/AIUsageCounterCore/CodexAppServerProvider.swift): Connects to the local `codex app-server` over stdio channels to stream and poll Codex rate limit windows.
- [**UsageMonitor.swift**](Sources/AIUsageCounterCore/UsageMonitor.swift) / [**ProviderUsageMonitor.swift**](Sources/AIUsageCounterCore/ProviderUsageMonitor.swift): State controllers that govern refresh intervals, connection state machine, cache loading/saving, and countdown ticks.
- [**UsageModels.swift**](Sources/AIUsageCounterCore/UsageModels.swift): Data types representing quotas, snapshots, and connection states.

### Application Target: `AIUsageCounterApp`
- [**AIUsageCounterApp.swift**](Sources/AIUsageCounterApp/AIUsageCounterApp.swift): Declares the `@main` app entry point, configures the menu bar label image renderer, and sets up the SwiftUI popover view hierarchy.
- [**AppController.swift**](Sources/AIUsageCounterApp/AppController.swift): Bridges UI interactions with the core monitors, manages the OAuth local loopback server, and handles macOS startup settings.

---

## Requirements

- **macOS**: 14.0+ (Sonoma or later)
- **Swift**: 6.0+ (configured to run under Swift 5 language mode in [Package.swift](Package.swift))
- **Codex CLI** (optional): Install and configure Codex for Codex support.

---

## Building the Application

To compile the release build of the application and package it into an `.app` bundle, run the build script:

```bash
bash Scripts/build-app.sh
```

The compiled application bundle will be created at:
`dist/AI Usage Counter.app`

This bundle is ad-hoc signed for local use on your Mac.

---

## Running Tests

### Unit Tests
To run the automated suite of unit tests:

```bash
swift test
```

### Integration Tests
Live integration tests are opt-in and require appropriate setup/credentials:

- **Codex Live Integration**: Validates window responses:
  ```bash
  env AI_USAGE_COUNTER_LIVE_TEST=1 swift test --filter LiveCodexIntegrationTests
  ```

- **Antigravity Live Integration**: Verifies that Google returns model quotas using credentials stored in macOS Keychain:
  ```bash
  env AI_USAGE_COUNTER_ANTIGRAVITY_LIVE_TEST=1 swift test --filter LiveAntigravityIntegrationTests
  ```

---

## Privacy & Security

- **Codex**: Authentication is handled locally through the `codex app-server` binary.
- **Google Antigravity**: Authentication uses browser-based OAuth with PKCE. The long-lived refresh token and Google project ID are stored securely in the **macOS Keychain**. All access tokens are kept purely in memory and never written to disk.
- **No Data Collection**: The application does not collect, log, or transmit raw API responses, emails, or account identifiers. Cache files in `UserDefaults` store only provider identifiers, percentage numbers, reset timestamps, and update times.
- **Disconnection**: Choosing **Disconnect Antigravity** instantly wipes all associated credentials from your macOS Keychain.
