import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class BatteryController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case refreshing
        case ready
        case empty
        case failed(String)
    }

    static let shared = BatteryController()

    @Published private(set) var snapshot: BatterySnapshot
    @Published private(set) var phase: Phase = .idle

    private let sampler = DeviceBatterySampler()
    private var refreshLoop: Task<Void, Never>?
    private var lastActiveBluetoothScan: Date?

    private init() {
        snapshot = SharedSnapshotStore.load() ?? BatterySnapshot(devices: [])
        phase = snapshot.devices.isEmpty ? .idle : .ready
    }

    func start() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await refresh(force: false)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await refresh(force: false)
            }
        }
    }

    func refresh(force: Bool) async {
        guard phase != .refreshing else { return }
        phase = .refreshing

        let defaults = SharedSnapshotStore.defaults
        let includeMac = defaults.object(forKey: PreferenceKey.includeMac) as? Bool ?? true
        let includeMobile = defaults.object(forKey: PreferenceKey.includeMobile) as? Bool ?? true
        let includeBluetooth = defaults.object(forKey: PreferenceKey.includeBluetooth) as? Bool ?? true
        let referenceDate = Date()
        let shouldActivelyScan = includeBluetooth && shouldPerformActiveScan(at: referenceDate, force: force)

        let items = await withTaskGroup(of: [DeviceBatteryItem].self) { group in
            if includeMac {
                group.addTask { [sampler] in
                    await sampler.collectInternalBattery(referenceDate: referenceDate)
                }
            }

            if includeMobile {
                group.addTask { [sampler] in
                    await sampler.collectAppleMobileDevices(
                        referenceDate: referenceDate,
                        minimumRefreshInterval: force ? 0 : 90
                    )
                }
            }

            if includeBluetooth {
                group.addTask { [sampler] in
                    await sampler.collectBluetoothDevices(
                        referenceDate: referenceDate,
                        options: DeviceBatteryBluetoothSamplingOptions(
                            forceProfileRefresh: force,
                            performActiveScan: shouldActivelyScan
                        )
                    )
                }
            }

            var collected: [DeviceBatteryItem] = []
            for await result in group {
                collected.append(contentsOf: result)
            }
            return collected
        }

        if shouldActivelyScan {
            lastActiveBluetoothScan = referenceDate
        }

        guard !Task.isCancelled else { return }
        let normalizedItems = DeviceBatteryItemNormalizer.removingRedundantComponentAggregates(items)
        let devices = deduplicated(normalizedItems.map(BatteryDevice.init(deviceBatteryItem:)))
            .sorted(by: Self.sortDevices)
        let newSnapshot = BatterySnapshot(generatedAt: referenceDate, devices: devices)
        let contentChanged = newSnapshot.devices != snapshot.devices
        snapshot = newSnapshot
        phase = devices.isEmpty ? .empty : .ready

        do {
            try SharedSnapshotStore.save(newSnapshot)
            if contentChanged {
                WidgetCenter.shared.reloadTimelines(ofKind: BatteryWidgetConstants.kind)
            }
        } catch {
            phase = .failed("无法更新桌面组件：\(error.localizedDescription)")
        }
    }

    private func shouldPerformActiveScan(at date: Date, force: Bool) -> Bool {
        if force { return true }
        guard let lastActiveBluetoothScan else { return true }
        return date.timeIntervalSince(lastActiveBluetoothScan) >= 5 * 60
    }

    private func deduplicated(_ devices: [BatteryDevice]) -> [BatteryDevice] {
        var seen = Set<String>()
        return devices.filter { seen.insert($0.id).inserted }
    }

    private static func sortDevices(_ lhs: BatteryDevice, _ rhs: BatteryDevice) -> Bool {
        if lhs.isLow != rhs.isLow { return lhs.isLow }
        let leftRank = kindRank(lhs.kind)
        let rightRank = kindRank(rhs.kind)
        if leftRank != rightRank { return leftRank < rightRank }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func kindRank(_ kind: BatteryDeviceKind) -> Int {
        switch kind {
        case .mac: 0
        case .iPhone, .iPad, .iPod, .watch, .vision: 1
        case .airPods: 2
        case .magicAccessory: 3
        case .mouse: 4
        case .bluetooth: 5
        case .other: 6
        }
    }
}

enum PreferenceKey {
    static let includeMac = "sources.includeMac"
    static let includeMobile = "sources.includeMobile"
    static let includeBluetooth = "sources.includeBluetooth"
    static let menuBarShowsPercentage = "menuBar.showsPercentage"
}

enum BatteryWidgetConstants {
    static let kind = "BatteryGlassWidget"
}

extension BatteryDevice {
    init(deviceBatteryItem item: DeviceBatteryItem) {
        id = item.id
        name = item.name
        model = item.model
        kind = Self.kind(for: item)
        level = item.clampedLevel
        status = BatteryChargeStatus(item.chargeState)
        parentName = item.parentName
        source = item.source
        lastUpdated = item.lastUpdated
        detail = item.detail
    }

    private static func kind(for item: DeviceBatteryItem) -> BatteryDeviceKind {
        switch item.kind {
        case .internalBattery: return .mac
        case .phone: return .iPhone
        case .tablet: return .iPad
        case .mediaPlayer: return .iPod
        case .watch: return .watch
        case .spatialComputer: return .vision
        case .magicAccessory: return .magicAccessory
        case .rapooMouse: return .mouse
        case .airPodsPart: return .airPods
        case .bluetooth:
            let identity = [item.name, item.model, item.parentName]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return identity.contains("airpod") || identity.contains("beats") ? .airPods : .bluetooth
        case .other: return .other
        }
    }
}

private extension BatteryChargeStatus {
    init(_ state: DeviceBatteryChargeState) {
        switch state {
        case .unknown: self = .unknown
        case .normal: self = .normal
        case .charging: self = .charging
        case .charged: self = .charged
        case .plugged: self = .plugged
        case .invalid: self = .unavailable
        }
    }
}
