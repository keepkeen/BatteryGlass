import SwiftUI

@main
struct BatteryGlassApp: App {
    @StateObject private var controller = BatteryController.shared

    init() {
        BatteryController.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(controller: controller)
        } label: {
            MenuBarBatteryLabel(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}
