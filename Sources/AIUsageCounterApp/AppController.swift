import AIUsageCounterCore
import AppKit
import Combine
import Foundation
import Network
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    let monitor: UsageMonitor
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginError: String?

    private let connectivity = ConnectivityObserver()
    private var wakeObserver: NSObjectProtocol?

    init() {
        monitor = UsageMonitor(provider: CodexAppServerProvider())
        launchAtLogin = SMAppService.mainApp.status == .enabled

        connectivity.onRestored = { [weak monitor] in
            Task { @MainActor in monitor?.handleNetworkRestored() }
        }
        connectivity.start()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak monitor] _ in
            Task { @MainActor in monitor?.handleWake() }
        }
        monitor.start()
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        connectivity.stop()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }

    func quit() {
        connectivity.stop()
        Task {
            await monitor.stop()
            NSApplication.shared.terminate(nil)
        }
    }
}

private final class ConnectivityObserver: @unchecked Sendable {
    var onRestored: (@Sendable () -> Void)?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ai-usage-counter.network")
    private let lock = NSLock()
    private var wasSatisfied: Bool?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            lock.lock()
            let previous = wasSatisfied
            wasSatisfied = satisfied
            lock.unlock()
            if previous == false && satisfied { onRestored?() }
        }
        monitor.start(queue: queue)
    }

    func stop() { monitor.cancel() }
}
