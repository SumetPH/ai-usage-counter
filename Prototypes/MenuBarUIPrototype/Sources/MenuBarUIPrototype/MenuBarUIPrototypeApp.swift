import AppKit
import SwiftUI

// Three native popup variants, switchable from the high-contrast bottom bar.

@main
struct MenuBarUIPrototypeApp: App {
    @StateObject private var store = PrototypeStore()

    var body: some Scene {
        MenuBarExtra {
            PrototypePopover(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                Text(store.menuBarText).monospacedDigit()
            }
            .help("Codex — Hourly | Weekly quota remaining")
        }
        .menuBarExtraStyle(.window)
    }
}

struct PrototypePopover: View {
    @ObservedObject var store: PrototypeStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                header
                fixturePicker
                Group {
                    switch store.variant {
                    case .operational: VariantAOperational(data: store.data)
                    case .gauges: VariantBDualGauges(data: store.data)
                    case .timeline: VariantCResetTimeline(data: store.data)
                    }
                }
                .frame(minHeight: 205, alignment: .top)
                footerActions
            }
            .padding(20)

            VariantSwitcher(variant: $store.variant)
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .onKeyPress(.leftArrow) {
            store.variant.move(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            store.variant.move(1)
            return .handled
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex").font(.title3.weight(.semibold))
                Text(store.data.updatedText)
                    .font(.caption)
                    .foregroundStyle(store.data.stale ? .orange : .secondary)
            }
            Spacer()
            Label(store.data.connected ? "Connected" : "Offline", systemImage: store.data.connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(store.data.connected ? .green : .secondary)
        }
    }

    private var fixturePicker: some View {
        HStack {
            Text("Preview state").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Picker("Preview state", selection: $store.fixture) {
                ForEach(FixtureState.allCases) { state in Text(state.rawValue).tag(state) }
            }
            .labelsHidden()
            .frame(width: 165)
        }
    }

    private var footerActions: some View {
        HStack {
            Button {
                store.refresh()
            } label: {
                Label(store.isRefreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Menu("Settings") {
                Toggle("Launch at Login", isOn: $store.launchAtLogin)
                Divider()
                Text("Prototype — setting is not persisted")
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
    }
}

struct VariantSwitcher: View {
    @Binding var variant: PopupVariant

    var body: some View {
        HStack(spacing: 13) {
            Button { variant.move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Text(variant.rawValue)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
            Button { variant.move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.88))
    }
}
