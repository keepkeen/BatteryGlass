import Foundation

enum SharedSnapshotStore {
    static let suiteName = "group.com.liuliming.BatteryGlass"
    private static let snapshotKey = "battery.snapshot.v1"
    private static let widgetBundleIdentifier = "com.liuliming.BatteryGlass.Widget"
    private static let compatibilityDirectoryName = "BatteryGlass"
    private static let compatibilityFileName = "battery-snapshot-v1.json"

    static func load() -> BatterySnapshot? {
        load(
            defaults: defaults,
            compatibilityURLs: [
                processCompatibilitySnapshotURL,
                widgetCompatibilitySnapshotURL,
            ].compactMap { $0 }
        )
    }

    @discardableResult
    static func save(_ snapshot: BatterySnapshot) throws -> Bool {
        try save(snapshot, defaults: defaults, compatibilityURL: widgetCompatibilitySnapshotURL)
    }

    static func load(defaults: UserDefaults, compatibilityURL: URL?) -> BatterySnapshot? {
        load(
            defaults: defaults,
            compatibilityURLs: compatibilityURL.map { [$0] } ?? []
        )
    }

    private static func load(
        defaults: UserDefaults,
        compatibilityURLs: [URL]
    ) -> BatterySnapshot? {
        let sharedSnapshot = defaults.data(forKey: snapshotKey)
            .flatMap { try? decoder.decode(BatterySnapshot.self, from: $0) }
        let compatibilitySnapshots = compatibilityURLs.compactMap { url in
            try? decoder.decode(BatterySnapshot.self, from: Data(contentsOf: url))
        }

        return ([sharedSnapshot].compactMap { $0 } + compatibilitySnapshots)
            .max { $0.generatedAt < $1.generatedAt }
    }

    @discardableResult
    static func save(
        _ snapshot: BatterySnapshot,
        defaults: UserDefaults,
        compatibilityURL: URL?
    ) throws -> Bool {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: snapshotKey)

        guard let compatibilityURL else { return false }
        let fileManager = FileManager.default
        let createdCompatibilityFile = !fileManager.fileExists(atPath: compatibilityURL.path)
        try fileManager.createDirectory(
            at: compatibilityURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: compatibilityURL, options: .atomic)
        return createdCompatibilityFile
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static var processCompatibilitySnapshotURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(compatibilityDirectoryName, isDirectory: true)
            .appendingPathComponent(compatibilityFileName)
    }

    private static var widgetCompatibilitySnapshotURL: URL? {
        // The locally distributed ad-hoc build cannot authorize App Group access for the
        // sandboxed widget, so the unsandboxed host mirrors the snapshot into its extension's container.
        let widgetDataContainer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(widgetBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: widgetDataContainer.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return nil
        }

        return widgetDataContainer
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(compatibilityDirectoryName, isDirectory: true)
            .appendingPathComponent(compatibilityFileName)
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
