import Foundation

enum SharedSnapshotStore {
    static let suiteName = "group.com.liuliming.BatteryGlass"
    private static let snapshotKey = "battery.snapshot.v1"

    static func load() -> BatterySnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? decoder.decode(BatterySnapshot.self, from: data)
    }

    static func save(_ snapshot: BatterySnapshot) throws {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: snapshotKey)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
