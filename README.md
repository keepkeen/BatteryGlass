# BatteryGlass

BatteryGlass is a native macOS 26 menu bar utility and desktop widget for viewing the battery levels of your Mac, trusted iPhone/iPad devices, a paired Apple Watch, AirPods, and Bluetooth accessories.

![macOS 26](https://img.shields.io/badge/macOS-26%2B-1d1d1f)
![Swift](https://img.shields.io/badge/Swift-6-f05138)
![License](https://img.shields.io/badge/license-Apache--2.0-blue)

## Install

The current `v0.1.0` preview is universal (`arm64` and `x86_64`) and ad-hoc signed. It is not Apple-notarized yet because the project does not currently have a Developer ID certificate.

Install from the project Homebrew tap:

```sh
brew install --cask keepkeen/batteryglass/batteryglass
xattr -dr com.apple.quarantine /Applications/BatteryGlass.app
open -a BatteryGlass
```

The targeted `xattr` command is required only for this ad-hoc-signed preview. If you do not want to bypass Gatekeeper for the downloaded build, build from source instead. A future Developer ID release will remove this requirement.

After launching, use the menu bar battery icon. To add the desktop widget, Control-click the desktop, choose **Edit Widgets**, search for **BatteryGlass** or **设备电量**, and select a size.

## Architecture

- The `LSUIElement` host app performs all device sampling and owns the menu bar UI.
- A WidgetKit extension renders a small or medium desktop widget from a shared App Group snapshot.
- Mac battery data comes from IOPowerSources.
- Trusted mobile-device data is read through the system MobileDevice framework, with Apple Watch data obtained through a connected iPhone.
- AirPods and Bluetooth data combines `system_profiler`, IOBluetooth, IORegistry, recent BatteryCenter/bluetoothd events, and a short CoreBluetooth scan.

The MobileDevice path is a private macOS interface and is not suitable for Mac App Store distribution. It fails gracefully if Apple changes or removes the interface.

## Build

Open `BatteryGlass.xcworkspace` in Xcode 26. The project uses the App Group `group.com.liuliming.BatteryGlass`; select your development team and register that App Group for both targets before running the widget.

For a compile-only local check without signing:

```sh
xcodebuild -workspace BatteryGlass.xcworkspace -scheme BatteryGlass -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Mobile devices must first trust the Mac in Finder. BatteryGlass is intentionally not App Sandbox-enabled because the sampler needs system profiler, local unified logs, and the runtime MobileDevice framework.

## Compatibility and privacy

- Requires macOS 26 or later.
- Mobile devices must trust the Mac in Finder and be reachable over USB or Wi-Fi.
- Bluetooth access is requested only to read nearby accessory battery data.
- Battery snapshots remain on the Mac and are shared with the widget through the local App Group container.
- The MobileDevice reader uses a private macOS framework and may require maintenance after macOS updates. This also makes the app unsuitable for the Mac App Store.

## Attribution

The device sampling layer is adapted from the Apache-2.0 licensed MacTools DeviceBattery plugin. See [ThirdParty/NOTICE.md](ThirdParty/NOTICE.md) and [ThirdParty/MacTools-LICENSE](ThirdParty/MacTools-LICENSE).

## License

BatteryGlass is released under the [Apache License 2.0](LICENSE). This keeps the project license compatible with the adapted MacTools sampling layer and includes an explicit patent grant.
