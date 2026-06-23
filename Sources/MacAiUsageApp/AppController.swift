import MacAiUsageCore
import AppKit
import Combine
import Foundation
import Network
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    let settings: ProviderSettings
    let codexMonitor: ProviderUsageMonitor
    let antigravityMonitor: ProviderUsageMonitor

    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var antigravityConnected: Bool
    @Published private(set) var authenticationInProgress = false
    @Published private(set) var authenticationError: String?

    private let antigravityProvider: AntigravityProvider
    private let connectivity = ConnectivityObserver()
    private var wakeObserver: NSObjectProtocol?
    private var cancellables: Set<AnyCancellable> = []

    init(defaults: UserDefaults = .standard) {
        let settings = ProviderSettings(defaults: defaults)
        let antigravityProvider = AntigravityProvider()
        self.settings = settings
        self.antigravityProvider = antigravityProvider
        self.antigravityConnected = settings.enabledProviders.contains(.antigravity) ? antigravityProvider.isConnected() : false
        self.codexMonitor = ProviderUsageMonitor(
            provider: CodexProviderAdapter(),
            cache: UserDefaultsProviderUsageCache(providerID: .codex, defaults: defaults)
        )
        self.antigravityMonitor = ProviderUsageMonitor(
            provider: antigravityProvider,
            cache: UserDefaultsProviderUsageCache(providerID: .antigravity, defaults: defaults)
        )
        launchAtLogin = SMAppService.mainApp.status == .enabled

        for provider in UsageProviderID.allCases {
            monitor(for: provider).setEnabled(settings.enabledProviders.contains(provider))
        }

        antigravityMonitor.$snapshot
            .compactMap { $0 }
            .sink { [weak self] snapshot in self?.chooseDefaultAntigravityModel(from: snapshot) }
            .store(in: &cancellables)

        connectivity.onRestored = { [weak self] in
            Task { @MainActor in self?.refreshAll() }
        }
        connectivity.start()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refreshAll() } }
    }

    deinit {
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        connectivity.stop()
    }

    var enabledProviders: [UsageProviderID] {
        UsageProviderID.allCases.filter(settings.enabledProviders.contains)
    }

    var menuBarText: String {
        let provider = settings.menuBarProvider
        return monitor(for: provider).menuBarText(
            preferredQuotaID: provider == .antigravity ? settings.antigravityModelID : nil
        )
    }

    var menuBarTooltip: String {
        if settings.menuBarProvider == .antigravity,
           let quota = settings.antigravityModelID.flatMap({ antigravityMonitor.quota($0) }) {
            return "Antigravity — \(quota.name) \(quota.remainingPercent)% remaining"
        }
        return "\(settings.menuBarProvider.displayName) — \(menuBarText)"
    }

    var menuBarIconName: String {
        switch settings.menuBarProvider {
        case .codex: "sparkles"
        case .antigravity where settings.antigravityModelID == "claude": "brain.head.profile"
        case .antigravity: "bolt.fill"
        }
    }

    var menuBarIsStale: Bool { monitor(for: settings.menuBarProvider).isStale }

    func monitor(for provider: UsageProviderID) -> ProviderUsageMonitor {
        provider == .codex ? codexMonitor : antigravityMonitor
    }

    func setProviderEnabled(_ enabled: Bool, provider: UsageProviderID) {
        guard settings.setEnabled(enabled, for: provider) else { return }
        monitor(for: provider).setEnabled(enabled)
        if provider == .antigravity {
            antigravityConnected = enabled ? antigravityProvider.isConnected() : false
        }
    }

    func setPopupOpen(_ open: Bool) {
        enabledProviders.forEach { monitor(for: $0).setPopupOpen(open) }
    }

    func refreshAll() {
        enabledProviders.forEach { monitor(for: $0).triggerRefresh(.manual) }
    }

    func connectAntigravity() {
        guard !authenticationInProgress else { return }
        authenticationInProgress = true
        authenticationError = nil
        Task {
            defer { authenticationInProgress = false }
            do {
                let redirectURI = "http://localhost:51121/oauth-callback"
                let state = UUID().uuidString
                let verifier = AntigravityOAuth.makeVerifier()
                let url = AntigravityOAuth.authorizationURL(redirectURI: redirectURI, state: state, verifier: verifier)
                let code = try await OAuthLoopbackServer.authorize(url: url, expectedState: state)
                try await antigravityProvider.authenticate(code: code, verifier: verifier, redirectURI: redirectURI)
                antigravityConnected = true
                _ = settings.setEnabled(true, for: .antigravity)
                antigravityMonitor.setEnabled(true)
                await antigravityMonitor.refreshAndWait(.manual)
            } catch {
                authenticationError = error.localizedDescription
            }
        }
    }

    func disconnectAntigravity() {
        authenticationError = nil
        Task {
            do {
                try await antigravityProvider.disconnect()
                antigravityConnected = false
                if settings.enabledProviders.contains(.antigravity) {
                    if settings.enabledProviders == [.antigravity] {
                        setProviderEnabled(true, provider: .codex)
                    }
                    setProviderEnabled(false, provider: .antigravity)
                }
            } catch {
                authenticationError = error.localizedDescription
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }

    func quit() {
        connectivity.stop()
        Task {
            await codexMonitor.shutdown()
            await antigravityMonitor.shutdown()
            NSApplication.shared.terminate(nil)
        }
    }

    private func chooseDefaultAntigravityModel(from snapshot: ProviderSnapshot) {
        if let current = settings.antigravityModelID,
           snapshot.quotas.contains(where: { $0.id == current }) { return }
        let preferred = snapshot.quotas.first { $0.id == "gemini" } ?? snapshot.quotas.first
        settings.setAntigravityModelID(preferred?.id)
    }
}

private final class OAuthLoopbackServer: @unchecked Sendable {
    static func authorize(url: URL, expectedState: String) async throws -> String {
        let server = OAuthLoopbackServer(expectedState: expectedState)
        return try await server.run(opening: url)
    }

    private let expectedState: String
    private let queue = DispatchQueue(label: "dev.sumetph.MacAiUsage.oauth")
    private var listener: NWListener?

    private init(expectedState: String) { self.expectedState = expectedState }

    private func run(opening url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let listener = try NWListener(using: .tcp, on: 51121)
                self.listener = listener
                let completion = OAuthCompletion(listener: listener, continuation: continuation)
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        DispatchQueue.main.async { NSWorkspace.shared.open(url) }
                    case .failed(let error): completion.finish(.failure(error))
                    default: break
                    }
                }
                listener.newConnectionHandler = { connection in
                    connection.start(queue: self.queue)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, error in
                        if let error { completion.finish(.failure(error)); return }
                        guard let data, let request = String(data: data, encoding: .utf8),
                              let firstLine = request.split(separator: "\n").first,
                              let target = firstLine.split(separator: " ").dropFirst().first,
                              let components = URLComponents(string: "http://localhost\(target)") else {
                            completion.finish(.failure(UsageProviderError.notAuthenticated)); return
                        }
                        let parameters = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } })
                        let ok = parameters["state"] == self.expectedState && parameters["code"] != nil
                        let message = ok ? "Authentication complete. You can close this window." : "Authentication failed. Return to Mac Ai Usage."
                        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(message.utf8.count)\r\nConnection: close\r\n\r\n\(message)"
                        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                        if let code = parameters["code"], parameters["state"] == self.expectedState {
                            completion.finish(.success(code))
                        } else {
                            completion.finish(.failure(UsageProviderError.notAuthenticated))
                        }
                    }
                }
                listener.start(queue: queue)
                queue.asyncAfter(deadline: .now() + 180) { completion.finish(.failure(UsageProviderError.timedOut)) }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class OAuthCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let listener: NWListener
    private let continuation: CheckedContinuation<String, Error>

    init(listener: NWListener, continuation: CheckedContinuation<String, Error>) {
        self.listener = listener
        self.continuation = continuation
    }

    func finish(_ result: Result<String, Error>) {
        let shouldFinish = lock.withLock {
            guard !completed else { return false }
            completed = true
            return true
        }
        guard shouldFinish else { return }
        listener.cancel()
        continuation.resume(with: result)
    }
}

private final class ConnectivityObserver: @unchecked Sendable {
    var onRestored: (@Sendable () -> Void)?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.sumetph.MacAiUsage.network")
    private let lock = NSLock()
    private var wasSatisfied: Bool?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            let previous = lock.withLock { let old = self.wasSatisfied; self.wasSatisfied = satisfied; return old }
            if previous == false && satisfied { self.onRestored?() }
        }
        monitor.start(queue: queue)
    }
    func stop() { monitor.cancel() }
}
