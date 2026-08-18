import Foundation

/// Compatibility shim for the Apache-licensed MacTools sampler.
///
/// BatteryGlass changed the original plugin implementation to use the host app's
/// bundle directly instead of depending on MacToolsPluginKit.
struct PluginLocalization: @unchecked Sendable {
    let bundle: Bundle

    func string(_ key: String, defaultValue: String) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    func format(_ key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        String(format: string(key, defaultValue: defaultValue), arguments: arguments)
    }
}

enum RapooBatteryAccessState: Equatable, Sendable {
    case idle
    case scanning
    case waitingForReport
    case connected
    case noDevice
    case permissionDenied
    case failed(String)
}
