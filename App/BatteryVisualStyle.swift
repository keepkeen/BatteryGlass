import SwiftUI

enum BatteryVisualStyle {
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

    static func batterySymbol(level: Int?, powered: Bool) -> String {
        if powered { return "battery.100percent.bolt" }
        guard let level else { return "battery.0percent" }
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

struct BatteryRing: View {
    let device: BatteryDevice
    var diameter: CGFloat = 48

    private var progress: Double {
        Double(device.clampedLevel ?? 0) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    BatteryVisualStyle.color(for: device),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: device.kind.symbol)
                .font(.system(size: diameter * 0.32, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(BatteryVisualStyle.color(for: device))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
