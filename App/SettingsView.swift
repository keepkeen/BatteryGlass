import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: BatteryController

    @AppStorage(PreferenceKey.includeMac, store: SharedSnapshotStore.defaults)
    private var includeMac = true
    @AppStorage(PreferenceKey.includeMobile, store: SharedSnapshotStore.defaults)
    private var includeMobile = true
    @AppStorage(PreferenceKey.includeBluetooth, store: SharedSnapshotStore.defaults)
    private var includeBluetooth = true
    @AppStorage(PreferenceKey.menuBarShowsPercentage, store: SharedSnapshotStore.defaults)
    private var menuBarShowsPercentage = true

    var body: some View {
        Form {
            Section("显示内容") {
                Toggle(isOn: $includeMac) {
                    SettingLabel(
                        title: "Mac 内置电池",
                        subtitle: "显示本机电量、充电状态和电源连接状态。",
                        symbol: "laptopcomputer"
                    )
                }

                Toggle(isOn: $includeMobile) {
                    SettingLabel(
                        title: "iPhone、iPad 与 Apple Watch",
                        subtitle: "读取已信任并通过 USB 或 Wi-Fi 连接的 Apple 设备。",
                        symbol: "iphone.and.arrow.forward"
                    )
                }

                Toggle(isOn: $includeBluetooth) {
                    SettingLabel(
                        title: "AirPods 与蓝牙外设",
                        subtitle: "读取系统可见的耳机、键盘、鼠标和其他配件。",
                        symbol: "airpodspro"
                    )
                }
            }

            Section("菜单栏") {
                Toggle(isOn: $menuBarShowsPercentage) {
                    SettingLabel(
                        title: "显示百分比",
                        subtitle: "在菜单栏图标旁显示当前最低的未充电设备电量。",
                        symbol: "percent"
                    )
                }
            }

            Section("桌面组件") {
                LabeledContent {
                    Text("小号、 中号")
                        .foregroundStyle(.secondary)
                } label: {
                    SettingLabel(
                        title: "BatteryGlass 小组件",
                        subtitle: "右键点按桌面，选择“编辑小组件”，然后搜索 BatteryGlass。",
                        symbol: "rectangle.3.group"
                    )
                }
            }

            Section("连接与隐私") {
                LabeledContent {
                    Button("打开蓝牙隐私设置") {
                        openBluetoothPrivacySettings()
                    }
                } label: {
                    SettingLabel(
                        title: "蓝牙访问",
                        subtitle: "短时扫描用于补齐 AirPods 分体电量；所有数据只保存在本机。",
                        symbol: "lock.shield"
                    )
                }

                SettingLabel(
                    title: "移动设备兼容性",
                    subtitle: "iPhone、iPad 和 Watch 使用 macOS 自带但未公开的 MobileDevice 接口，系统更新后可能暂时失效，不适用于 Mac App Store。",
                    symbol: "exclamationmark.shield"
                )
            }

            Section {
                HStack {
                    Text(lastUpdatedText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("立即刷新") {
                        Task { await controller.refresh(force: true) }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(controller.phase == .refreshing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 610)
        .navigationTitle("BatteryGlass 设置")
        .onChange(of: includeMac) { refreshAfterPreferenceChange() }
        .onChange(of: includeMobile) { refreshAfterPreferenceChange() }
        .onChange(of: includeBluetooth) { refreshAfterPreferenceChange() }
    }

    private var lastUpdatedText: String {
        switch controller.phase {
        case .refreshing:
            return "正在读取设备…"
        case .idle:
            return "尚未刷新"
        case .empty:
            return "未发现可读取的设备"
        case .ready:
            return "上次更新：\(controller.snapshot.generatedAt.formatted(date: .omitted, time: .standard))"
        case let .failed(message):
            return message
        }
    }

    private func refreshAfterPreferenceChange() {
        Task { await controller.refresh(force: true) }
    }

    private func openBluetoothPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingLabel: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .frame(width: 24)
        }
        .padding(.vertical, 3)
    }
}
