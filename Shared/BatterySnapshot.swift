import Foundation

enum BatteryDeviceKind: String, Codable, CaseIterable, Sendable {
    case mac
    case iPhone
    case iPad
    case iPod
    case watch
    case vision
    case airPods
    case magicAccessory
    case bluetooth
    case mouse
    case other

    var symbol: String {
        switch self {
        case .mac: "laptopcomputer"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .iPod: "ipodtouch"
        case .watch: "applewatch"
        case .vision: "visionpro"
        case .airPods: "airpodspro"
        case .magicAccessory: "keyboard"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .mouse: "computermouse.fill"
        case .other: "battery.75percent"
        }
    }
}

enum BatteryChargeStatus: String, Codable, Sendable {
    case unknown
    case normal
    case charging
    case charged
    case plugged
    case unavailable

    var isPowered: Bool {
        self == .charging || self == .charged || self == .plugged
    }

    var title: String {
        switch self {
        case .unknown: "状态未知"
        case .normal: "使用电池"
        case .charging: "正在充电"
        case .charged: "已充满"
        case .plugged: "已接入电源"
        case .unavailable: "暂不可用"
        }
    }
}

struct BatteryDevice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let model: String?
    let kind: BatteryDeviceKind
    let level: Int?
    let status: BatteryChargeStatus
    let parentName: String?
    let source: String
    let lastUpdated: Date?
    let detail: String?

    var clampedLevel: Int? {
        level.map { min(max($0, 0), 100) }
    }

    var isLow: Bool {
        guard let clampedLevel else { return false }
        return clampedLevel <= 20 && !status.isPowered
    }
}

struct BatterySnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let generatedAt: Date
    let devices: [BatteryDevice]

    init(generatedAt: Date = .now, devices: [BatteryDevice]) {
        version = Self.currentVersion
        self.generatedAt = generatedAt
        self.devices = devices
    }

    var lowestDevice: BatteryDevice? {
        devices
            .filter { !$0.status.isPowered }
            .compactMap { device -> (BatteryDevice, Int)? in
                device.clampedLevel.map { (device, $0) }
            }
            .min { $0.1 < $1.1 }?.0
    }

    static let preview = BatterySnapshot(
        devices: [
            BatteryDevice(
                id: "preview-mac",
                name: "MacBook Pro",
                model: nil,
                kind: .mac,
                level: 86,
                status: .charging,
                parentName: nil,
                source: "IOPowerSources",
                lastUpdated: .now,
                detail: "1 小时 42 分钟后充满"
            ),
            BatteryDevice(
                id: "preview-iphone",
                name: "iPhone",
                model: "iPhone",
                kind: .iPhone,
                level: 64,
                status: .normal,
                parentName: nil,
                source: "MobileDevice",
                lastUpdated: .now,
                detail: "Wi-Fi"
            ),
            BatteryDevice(
                id: "preview-airpods",
                name: "AirPods Pro",
                model: nil,
                kind: .airPods,
                level: 38,
                status: .normal,
                parentName: nil,
                source: "Bluetooth",
                lastUpdated: .now,
                detail: "已连接"
            ),
        ]
    )
}
