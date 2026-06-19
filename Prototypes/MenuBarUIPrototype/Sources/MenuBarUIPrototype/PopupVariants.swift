import SwiftUI

struct VariantAOperational: View {
    let data: UsageViewData

    var body: some View {
        VStack(spacing: 18) {
            if let hourly = data.hourly, let weekly = data.weekly {
                OperationalRow(quota: hourly, refreshFailed: data.refreshFailed)
                Divider()
                OperationalRow(quota: weekly, refreshFailed: data.refreshFailed)
            } else {
                DisconnectedView()
            }
        }
    }
}

private struct OperationalRow: View {
    let quota: QuotaViewData
    let refreshFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(quota.name).font(.headline)
                Spacer()
                Text(quota.displayValue(refreshFailed: refreshFailed))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            ProgressView(value: Double(quota.remaining), total: 100)
                .tint(quota.tint)
            Text(quota.resetText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct VariantBDualGauges: View {
    let data: UsageViewData

    var body: some View {
        Group {
            if let hourly = data.hourly, let weekly = data.weekly {
                HStack(spacing: 28) {
                    GaugeCell(quota: hourly, refreshFailed: data.refreshFailed)
                    GaugeCell(quota: weekly, refreshFailed: data.refreshFailed)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            } else {
                DisconnectedView()
            }
        }
    }
}

private struct GaugeCell: View {
    let quota: QuotaViewData
    let refreshFailed: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(quota.remaining) / 100)
                    .stroke(quota.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(quota.displayValue(refreshFailed: refreshFailed))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(8)
            }
            .frame(width: 108, height: 108)
            Text(quota.name).font(.headline)
            Text(quota.resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VariantCResetTimeline: View {
    let data: UsageViewData

    var body: some View {
        Group {
            if let hourly = data.hourly, let weekly = data.weekly {
                VStack(alignment: .leading, spacing: 0) {
                    Text("NEXT RESET")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1.4)
                    TimelineRow(quota: hourly, refreshFailed: data.refreshFailed, isFirst: true)
                    TimelineRow(quota: weekly, refreshFailed: data.refreshFailed, isFirst: false)
                    Text("Percentages show quota remaining")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            } else {
                DisconnectedView()
            }
        }
    }
}

private struct TimelineRow: View {
    let quota: QuotaViewData
    let refreshFailed: Bool
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(quota.tint).frame(width: 9, height: 9)
                if isFirst { Rectangle().fill(.quaternary).frame(width: 1, height: 55) }
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(quota.name).font(.headline)
                    Spacer()
                    Text("\(quota.remaining)% left")
                        .foregroundStyle(quota.tint)
                        .font(.subheadline.weight(.semibold))
                }
                Text(quota.displayValue(refreshFailed: refreshFailed))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text(quota.resetText).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Codex not connected").font(.headline)
            Text("Sign in with Codex CLI, then retry.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 165)
    }
}
