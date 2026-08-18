import XCTest
@testable import BatteryGlass

final class BatterySnapshotTests: XCTestCase {
    func testLowestDeviceIgnoresPoweredDevices() {
        let charging = makeDevice(id: "charging", level: 5, status: .charging)
        let low = makeDevice(id: "low", level: 18, status: .normal)
        let high = makeDevice(id: "high", level: 75, status: .normal)

        let snapshot = BatterySnapshot(devices: [charging, high, low])

        XCTAssertEqual(snapshot.lowestDevice?.id, "low")
    }

    func testClampedLevelProtectsPresentation() {
        XCTAssertEqual(makeDevice(id: "negative", level: -7).clampedLevel, 0)
        XCTAssertEqual(makeDevice(id: "overflow", level: 142).clampedLevel, 100)
        XCTAssertNil(makeDevice(id: "unknown", level: nil).clampedLevel)
    }

    func testSnapshotRoundTrip() throws {
        let snapshot = BatterySnapshot(devices: [makeDevice(id: "watch", level: 62)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let decoded = try decoder.decode(BatterySnapshot.self, from: encoder.encode(snapshot))

        XCTAssertEqual(decoded.version, snapshot.version)
        XCTAssertEqual(decoded.devices, snapshot.devices)
        XCTAssertEqual(
            decoded.generatedAt.timeIntervalSince1970,
            snapshot.generatedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testSnapshotStoreFallsBackToWidgetCompatibilityFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let compatibilityURL = directory.appendingPathComponent("snapshot.json")
        let writerSuite = "BatteryGlassTests.writer.\(UUID().uuidString)"
        let readerSuite = "BatteryGlassTests.reader.\(UUID().uuidString)"
        let writerDefaults = try XCTUnwrap(UserDefaults(suiteName: writerSuite))
        let readerDefaults = try XCTUnwrap(UserDefaults(suiteName: readerSuite))
        defer {
            writerDefaults.removePersistentDomain(forName: writerSuite)
            readerDefaults.removePersistentDomain(forName: readerSuite)
            try? FileManager.default.removeItem(at: directory)
        }

        let snapshot = BatterySnapshot(devices: [makeDevice(id: "phone", level: 73)])
        let created = try SharedSnapshotStore.save(
            snapshot,
            defaults: writerDefaults,
            compatibilityURL: compatibilityURL
        )
        let loaded = SharedSnapshotStore.load(
            defaults: readerDefaults,
            compatibilityURL: compatibilityURL
        )

        XCTAssertTrue(created)
        XCTAssertEqual(loaded?.devices, snapshot.devices)
    }

    func testSnapshotStoreReportsExistingCompatibilityFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let compatibilityURL = directory.appendingPathComponent("snapshot.json")
        let suite = "BatteryGlassTests.existing.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }

        let snapshot = BatterySnapshot(devices: [makeDevice(id: "watch", level: 58)])

        XCTAssertTrue(
            try SharedSnapshotStore.save(
                snapshot,
                defaults: defaults,
                compatibilityURL: compatibilityURL
            )
        )
        XCTAssertFalse(
            try SharedSnapshotStore.save(
                snapshot,
                defaults: defaults,
                compatibilityURL: compatibilityURL
            )
        )
    }

    private func makeDevice(
        id: String,
        level: Int?,
        status: BatteryChargeStatus = .normal
    ) -> BatteryDevice {
        BatteryDevice(
            id: id,
            name: id,
            model: nil,
            kind: .other,
            level: level,
            status: status,
            parentName: nil,
            source: "test",
            lastUpdated: nil,
            detail: nil
        )
    }
}
