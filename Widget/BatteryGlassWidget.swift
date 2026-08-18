import SwiftUI
import WidgetKit

private enum WidgetIdentity {
    static let kind = "BatteryGlassWidget"
}

struct BatteryWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: BatterySnapshot
}

struct BatteryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryWidgetEntry {
        BatteryWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryWidgetEntry) -> Void) {
        let snapshot = context.isPreview
            ? BatterySnapshot.preview
            : SharedSnapshotStore.load() ?? BatterySnapshot(devices: [])
        completion(BatteryWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryWidgetEntry>) -> Void) {
        let snapshot = SharedSnapshotStore.load() ?? BatterySnapshot(devices: [])
        let entry = BatteryWidgetEntry(date: .now, snapshot: snapshot)
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(15 * 60))
            )
        )
    }
}

struct BatteryGlassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetIdentity.kind, provider: BatteryWidgetProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("设备电量")
        .description("在桌面快速查看 Mac、iPhone、Apple Watch、AirPods 与外设电量。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryWidgetEntry

    var body: some View {
        Group {
            if entry.snapshot.devices.isEmpty {
                WidgetEmptyView()
            } else {
                switch family {
                case .systemSmall:
                    SmallBatteryWidget(snapshot: entry.snapshot)
                case .systemLarge:
                    LargeBatteryWidget(snapshot: entry.snapshot)
                default:
                    MediumBatteryWidget(snapshot: entry.snapshot)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SmallBatteryWidget: View {
    let snapshot: BatterySnapshot

    private var featured: BatteryDevice {
        snapshot.lowestDevice ?? snapshot.devices[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("设备电量", systemImage: "bolt.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if featured.status.isPowered {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer(minLength: 4)

            HStack(alignment: .center, spacing: 12) {
                WidgetBatteryRing(device: featured, diameter: 61)

                VStack(alignment: .leading, spacing: 2) {
                    Text(featured.clampedLevel.map { "\($0)%" } ?? "--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                    Text(featured.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                    Text(featured.status.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                ForEach(snapshot.devices.prefix(5)) { device in
                    Circle()
                        .fill(WidgetBatteryPalette.color(for: device))
                        .frame(width: 5, height: 5)
                }
                if snapshot.devices.count > 5 {
                    Text("+\(snapshot.devices.count - 5)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MediumBatteryWidget: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("设备电量", systemImage: "bolt.circle.fill")
                    .font(.headline)
                Spacer()
                if snapshot.devices.count > 4 {
                    Text("+\(snapshot.devices.count - 4)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(snapshot.generatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(snapshot.devices.prefix(4)) { device in
                    MediumDeviceTile(device: device)
                }
            }
        }
    }
}

private struct LargeBatteryWidget: View {
    let snapshot: BatterySnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("设备电量", systemImage: "bolt.circle.fill")
                    .font(.headline)

                Text("\(snapshot.devices.count) 台")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if snapshot.devices.count > 8 {
                    Text("另有 \(snapshot.devices.count - 8) 台")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(snapshot.generatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(snapshot.devices.prefix(8)) { device in
                    LargeDeviceTile(device: device)
                }
            }
        }
    }
}

private struct LargeDeviceTile: View {
    let device: BatteryDevice

    var body: some View {
        HStack(spacing: 10) {
            WidgetBatteryRing(device: device, diameter: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(device.clampedLevel.map { "\($0)%" } ?? "--")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .monospacedDigit()

                    if device.status.isPowered {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Text(device.status.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(8)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MediumDeviceTile: View {
    let device: BatteryDevice

    var body: some View {
        VStack(spacing: 7) {
            WidgetBatteryRing(device: device, diameter: 45)

            VStack(spacing: 1) {
                Text(device.clampedLevel.map { "\($0)%" } ?? "--")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(device.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WidgetBatteryRing: View {
    let device: BatteryDevice
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: Double(device.clampedLevel ?? 0) / 100)
                .stroke(
                    WidgetBatteryPalette.color(for: device),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            Image(systemName: device.kind.symbol)
                .font(.system(size: diameter * 0.32, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(WidgetBatteryPalette.color(for: device))
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct WidgetEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.0percent")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("打开 BatteryGlass")
                .font(.headline)
            Text("首次启动后，设备电量会显示在这里。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        ZStack {
            Color.clear
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color.cyan.opacity(0.045),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum WidgetBatteryPalette {
    static func color(for device: BatteryDevice) -> Color {
        if device.status.isPowered { return .green }
        guard let level = device.clampedLevel else { return .secondary }
        if level <= 10 { return .red }
        if level <= 20 { return .orange }

        switch device.kind {
        case .mac: return .blue
        case .iPhone, .iPad, .iPod: return .cyan
        case .watch: return .pink
        case .vision: return .indigo
        case .airPods: return .purple
        case .magicAccessory: return .mint
        case .bluetooth: return .teal
        case .mouse: return .green
        case .other: return .blue
        }
    }
}

#Preview(as: .systemSmall) {
    BatteryGlassWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    BatteryGlassWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemLarge) {
    BatteryGlassWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, snapshot: .preview)
}
