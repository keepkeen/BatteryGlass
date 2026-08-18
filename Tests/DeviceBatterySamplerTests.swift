import XCTest
@testable import BatteryGlass

final class DeviceBatterySamplerTests: XCTestCase {
    func testInternalBatterySampleIsPresentAndBounded() async throws {
        let items = await DeviceBatterySampler().collectInternalBattery(referenceDate: .now)
        guard !items.isEmpty else {
            throw XCTSkip("This Mac does not expose an internal battery.")
        }

        XCTAssertTrue(items.allSatisfy { $0.kind == .internalBattery })
        XCTAssertTrue(items.allSatisfy { item in
            guard let level = item.clampedLevel else { return false }
            return (0...100).contains(level)
        })
    }
}
