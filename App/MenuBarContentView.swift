import AppKit
import SwiftUI

struct MenuBarBatteryLabel: View {
    @ObservedObject var controller: BatteryController
    @AppStorage(
        PreferenceKey.menuBarShowsPercentage,
        store: SharedSnapshotStore.defaults
    ) private var showsPercentage = true

    private var featuredDevice: BatteryDevice? {
        controller.snapshot.lowestDevice ?? controller.snapshot.devices.first
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(
                systemName: BatteryVisualStyle.batterySymbol(
                    level: featuredDevice?.clampedLevel,
                    powered: featuredDevice?.status.isPowered ?? false
                )
            )
            .symbolRenderingMode(.hierarchical)

            if showsPercentage, let level = featuredDevice?.clampedLevel {
                Text("\(level)%")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let featuredDevice else { return "BatteryGlass，未发现设备" }
        let percentage = featuredDevice.clampedLevel.map { "，\($0)%" } ?? ""
        return "\(featuredDevice.name)\(percentage)，\(featuredDevice.status.title)"
    }
}

struct MenuBarContentView: View {
    @ObservedObject var controller: BatteryController

    var body: some View {
        VStack(spacing: 0) {
            header

            if controller.snapshot.devices.isEmpty {
                EmptyDevicesView(phase: controller.phase)
                    .frame(maxWidth: .infinity, minHeight: 238)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(controller.snapshot.devices) { device in
                            BatteryDeviceRow(device: device)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(height: deviceListHeight)
            }

            footer
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("设备电量")
                        .font(.title3.weight(.semibold))

                    if controller.phase == .refreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("正在刷新")
                    }
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 12)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        Task { await controller.refresh(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.glass)
                    .disabled(controller.phase == .refreshing)
                    .help("立即刷新")

                    SettingsLink {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.glass)
                    .help("设置")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Label("数据仅保存在本机", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    private var statusText: String {
        switch controller.phase {
        case .idle:
            return "准备读取设备"
        case .refreshing:
            return "正在读取附近设备…"
        case .ready:
            return "\(controller.snapshot.devices.count) 台设备 · \(relativeUpdateText)"
        case .empty:
            return "未发现可读取的设备"
        case let .failed(message):
            return message
        }
    }

    private var relativeUpdateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: controller.snapshot.generatedAt, relativeTo: .now)
    }

    private var deviceListHeight: CGFloat {
        let count = controller.snapshot.devices.count
        let rowHeight: CGFloat = 72
        let rowSpacing: CGFloat = 8
        let verticalPadding: CGFloat = 20
        let contentHeight = verticalPadding
            + CGFloat(count) * rowHeight
            + CGFloat(max(count - 1, 0)) * rowSpacing
        return min(contentHeight, 430)
    }
}

private struct BatteryDeviceRow: View {
    let device: BatteryDevice

    private var color: Color {
        BatteryVisualStyle.color(for: device)
    }

    var body: some View {
        HStack(spacing: 12) {
            BatteryRing(device: device)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(device.clampedLevel.map { "\($0)%" } ?? "--")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(device.clampedLevel == nil ? .secondary : color)

                        if device.status.isPowered {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.08))
                        Capsule()
                            .fill(color.gradient)
                            .frame(
                                width: geometry.size.width * CGFloat(device.clampedLevel ?? 0) / 100
                            )
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        let parts = [device.parentName, device.status.title, device.detail]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
        return parts.isEmpty ? device.model : parts.joined(separator: " · ")
    }
}

private struct EmptyDevicesView: View {
    let phase: BatteryController.Phase

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "battery.0percent")
                .font(.system(size: 34, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 5) {
                Text(phase == .refreshing ? "正在寻找设备" : "还没有电量数据")
                    .font(.headline)
                Text("iPhone 和 iPad 需先连接 Finder 并信任此 Mac；\nAirPods 需处于系统可见或已连接状态。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(28)
    }
}
