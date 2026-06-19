import AIUsageCounterCore
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        if let bundlePath = Bundle.module.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: bundlePath) {
            NSApplication.shared.applicationIconImage = image
        } else if let image = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = image
        }
    }
}

@main
struct AIUsageCounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(controller: controller)
        } label: {
            MenuBarUsageLabel(monitor: controller.monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarUsageLabel: View {
    @ObservedObject var monitor: UsageMonitor
    @Environment(\.displayScale) var displayScale

    var body: some View {
        renderedImage
            .opacity(monitor.isStale ? 0.58 : 1)
            .help(monitor.menuBarTooltip)
    }
    
    private var renderedImage: Image {
        let contentView = HStack(alignment: .center, spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .imageScale(.medium)
            
            Text(monitor.menuBarText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.black) // สำคัญมาก เพื่อให้เวลาแปลงเป็น Template Image จะได้มี Alpha ที่ชัดเจน
        
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = displayScale
        
        if let nsImage = renderer.nsImage {
            nsImage.isTemplate = true // บอกให้ macOS รู้ว่านี่คือ Icon สีเดียว (จะสลับสีดำ/ขาว ตาม Light/Dark mode อัตโนมัติ)
            return Image(nsImage: nsImage)
        }
        
        return Image(systemName: "sparkles") // Fallback
    }
}

private struct UsagePopover: View {
    @ObservedObject var controller: AppController
    @ObservedObject var monitor: UsageMonitor

    init(controller: AppController) {
        self.controller = controller
        self.monitor = controller.monitor
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if monitor.snapshot != nil {
                QuotaRow(kind: .hourly, name: "Hourly", monitor: monitor)
                Divider()
                QuotaRow(kind: .weekly, name: "Weekly", monitor: monitor)
            } else {
                unavailableState
            }

            if let error = controller.launchAtLoginError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .padding(20)
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .onAppear { monitor.setPopupOpen(true) }
        .onDisappear { monitor.setPopupOpen(false) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex").font(.title3.weight(.semibold))
                Text(monitor.lastUpdatedText)
                    .font(.caption)
                    .foregroundStyle(monitor.isStale ? .orange : .secondary)
                    .accessibilityLabel(monitor.lastUpdatedText)
            }
            Spacer()
            Label(monitor.statusTitle, systemImage: statusIcon)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
                .accessibilityLabel("Codex status: \(monitor.statusTitle)")
        }
    }

    private var statusIcon: String {
        switch monitor.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath.circle.fill"
        case .disconnected, .codexUnavailable, .failed: return "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch monitor.connectionState {
        case .connected where !monitor.isStale: return .green
        case .connecting: return .secondary
        case .connected, .disconnected, .codexUnavailable, .failed: return monitor.isStale ? .gray : .orange
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: monitor.connectionState == .codexUnavailable ? "terminal" : "bolt.horizontal.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(monitor.connectionState == .codexUnavailable ? "Codex CLI unavailable" : "Codex not connected")
                .font(.headline)
            Text(monitor.errorMessage ?? "Sign in with Codex CLI, then retry.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { monitor.manualRefresh() }
                .disabled(monitor.refreshState == .refreshing)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
    }

    private var footer: some View {
        HStack {
            Button {
                monitor.manualRefresh()
            } label: {
                Label(monitor.refreshState == .refreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(monitor.refreshState == .refreshing)

            Menu("Settings") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    )
                )
            }
            Spacer()
            Button("Quit") { controller.quit() }
        }
        .controlSize(.small)
    }
}

private struct QuotaRow: View {
    let kind: QuotaKind
    let name: String
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        if let quota = monitor.quota(for: kind) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name).font(.headline)
                    Spacer()
                    Text(monitor.displayValue(for: kind))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(rowColor)
                }
                ProgressView(value: Double(quota.remainingPercent), total: 100)
                    .tint(rowColor)
                    .accessibilityLabel("\(name) quota remaining")
                    .accessibilityValue("\(quota.remainingPercent) percent")
                Text(monitor.resetText(for: kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(name) \(monitor.resetText(for: kind))")
            }
        }
    }

    private var rowColor: Color {
        guard !monitor.isStale, let remaining = monitor.quota(for: kind)?.remainingPercent else { return .gray }
        if remaining <= 5 { return .red }
        if remaining <= 20 { return .orange }
        return .green
    }
}
