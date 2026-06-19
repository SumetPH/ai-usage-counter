import AIUsageCounterCore
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApplication.shared.setActivationPolicy(.accessory) }
}

@main
struct AIUsageCounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(controller: controller)
        } label: {
            MenuBarUsageLabel(controller: controller, codex: controller.codexMonitor, antigravity: controller.antigravityMonitor, settings: controller.settings)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarUsageLabel: View {
    @ObservedObject var controller: AppController
    @ObservedObject var codex: ProviderUsageMonitor
    @ObservedObject var antigravity: ProviderUsageMonitor
    @ObservedObject var settings: ProviderSettings
    @Environment(\.displayScale) var displayScale

    var body: some View { renderedImage.opacity(controller.menuBarIsStale ? 0.58 : 1).help(controller.menuBarTooltip) }

    private var renderedImage: Image {
        let content = HStack(spacing: 4) {
            Image(systemName: controller.menuBarIconName)
                .font(.system(size: 14, weight: .semibold))
            Text(controller.menuBarText).font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
        }.foregroundColor(.black)
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        guard let image = renderer.nsImage else { return Image(systemName: "sparkles") }
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

private struct UsagePopover: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: ProviderSettings

    init(controller: AppController) {
        self.controller = controller
        self.settings = controller.settings
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                if controller.enabledProviders.isEmpty {
                    ContentUnavailableView(
                        "No Providers Enabled",
                        systemImage: "gauge.with.dots.needle.0percent",
                        description: Text("Enable a provider in Settings."),

                    )
                    .frame(minHeight: 160)
                } else {
                    ForEach(controller.enabledProviders) { provider in
                        ProviderSection(monitor: controller.monitor(for: provider), isMenuBarProvider: settings.menuBarProvider == provider)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.setMenuBarProvider(provider)
                            }
                            .help("Click to show \(provider.displayName) in Menu Bar")
                        if provider != controller.enabledProviders.last { Divider() }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if let error = controller.authenticationError ?? controller.launchAtLoginError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .onAppear { controller.setPopupOpen(true) }
        .onDisappear { controller.setPopupOpen(false) }
    }

    private var footer: some View {
        HStack {
            Button { controller.refreshAll() } label: { Label("Refresh All", systemImage: "arrow.clockwise") }
            settingsMenu
            Spacer()
            Button("Quit") { controller.quit() }
        }.controlSize(.small)
    }

    private var settingsMenu: some View {
        Menu("Settings") {
            Section("Providers") {
                ForEach(UsageProviderID.allCases) { provider in
                    Toggle(provider.displayName, isOn: Binding(
                        get: { settings.enabledProviders.contains(provider) },
                        set: { controller.setProviderEnabled($0, provider: provider) }
                    ))
                }
            }
            Section("Menu Bar Provider") {
                Picker("Menu Bar Provider", selection: Binding(
                    get: { settings.menuBarProvider },
                    set: { settings.setMenuBarProvider($0) }
                )) {
                    ForEach(controller.enabledProviders) { Text($0.displayName).tag($0) }
                }.labelsHidden()
            }
            if settings.enabledProviders.contains(.antigravity), let quotas = controller.antigravityMonitor.snapshot?.quotas, !quotas.isEmpty {
                Section("Antigravity Model") {
                    Picker("Antigravity Model", selection: Binding(
                        get: { settings.antigravityModelID ?? "" },
                        set: { settings.setAntigravityModelID($0) }
                    )) {
                        ForEach(quotas) { Text($0.name).tag($0.id) }
                    }.labelsHidden()
                }
            }
            Section("Google") {
                if controller.antigravityConnected {
                    Button("Disconnect Antigravity", role: .destructive) { controller.disconnectAntigravity() }
                } else {
                    Button(controller.authenticationInProgress ? "Connecting…" : "Connect Google") { controller.connectAntigravity() }
                        .disabled(controller.authenticationInProgress)
                }
                Text("Experimental private API").foregroundStyle(.secondary)
            }
            Toggle("Launch at Login", isOn: Binding(get: { controller.launchAtLogin }, set: { controller.setLaunchAtLogin($0) }))
        }
    }
}

private struct ProviderSection: View {
    @ObservedObject var monitor: ProviderUsageMonitor
    var isMenuBarProvider: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(monitor.id.displayName).font(.headline)
                        if isMenuBarProvider {
                            Image(systemName: "menubar.rectangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .help("Currently shown in Menu Bar")
                        }
                    }
                    Text(monitor.lastUpdatedText).font(.caption2).foregroundStyle(monitor.isStale ? .orange : .secondary)
                }
                Spacer()
                Label(monitor.statusTitle, systemImage: statusIcon).font(.caption2.weight(.medium)).foregroundStyle(statusColor)
                Button { monitor.triggerRefresh(.manual) } label: {
                    Image(systemName: monitor.refreshState == .refreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(monitor.refreshState == .refreshing)
                .help("Refresh \(monitor.id.displayName)")
            }

            if let snapshot = monitor.snapshot {
                ForEach(snapshot.quotas) { quota in
                    QuotaRow(quota: quota, monitor: monitor)
                }
            } else {
                VStack(spacing: 5) {
                    Image(systemName: monitor.id == .codex ? "terminal" : "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 24)).foregroundStyle(.secondary)
                    Text(monitor.errorMessage ?? (monitor.id == .antigravity ? "Connect Google in Settings" : "Usage unavailable"))
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, minHeight: 58)
            }
        }
    }

    private var statusIcon: String {
        switch monitor.connectionState {
        case .connected: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath.circle.fill"
        default: "exclamationmark.circle.fill"
        }
    }
    private var statusColor: Color {
        if monitor.connectionState == .connected && !monitor.isStale { return .green }
        return monitor.connectionState == .connecting ? .secondary : .orange
    }
}

private struct QuotaRow: View {
    let quota: UsageQuota
    @ObservedObject var monitor: ProviderUsageMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(quota.name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(quota.remainingPercent)%").font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            }
            ProgressView(value: Double(quota.remainingPercent), total: 100).tint(color)
            Text(monitor.resetText(for: quota)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        guard !monitor.isStale else { return .gray }
        if quota.remainingPercent <= 5 { return .red }
        if quota.remainingPercent <= 20 { return .orange }
        return .green
    }
}
