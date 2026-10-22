import Foundation
import Combine

enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    // Keep existing raw values so V0.9 collections still decode.
    case watch = "手表／手环", headphones = "耳机", stylus = "Apple Pencil／触控笔"
    case mouse = "蓝牙鼠标", keyboard = "蓝牙键盘", other = "其他 BLE 物品"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .watch: return "applewatch"
        case .headphones: return "headphones"
        case .stylus: return "pencil.tip"
        case .mouse: return "computermouse"
        case .keyboard: return "keyboard"
        case .other: return "shippingbox"
        }
    }
    var guidance: String {
        switch self {
        case .watch: return "Suunto 9 Peak Pro 有既往实测；其他手表仍需验证。通知转发不等于通用响铃。"
        case .headphones: return "AirPods 请优先使用 Apple 查找。其他耳机仅在可发现 BLE 信号时辅助寻找，盒内、断电或休眠时可能不可见；没有通用发声控制。"
        case .stylus: return "Apple Pencil Pro 优先使用 Apple 查找。其他代际与触控笔尚未实测，iPhone 不保证可发现；休眠后可能没有信号。"
        case .mouse: return "仅对本 App 能发现的 BLE 鼠标尝试信号寻找；连接电脑、休眠或使用专用 2.4 GHz 接收器时可能不可见。没有响铃支持。"
        case .keyboard: return "蓝牙键盘通常会休眠，连接其他设备后也可能停止广播。此类别不代表已兼容；没有响铃支持。"
        case .other: return "必须有电且能被本 App 发现或恢复连接。类别、名称和广播信号都不能代替身份确认。"
        }
    }
    var officialGuide: URL? {
        switch self {
        case .stylus: return URL(string: "https://support.apple.com/en-gb/guide/ipad/ipad445ff36d/ipados")
        case .headphones: return URL(string: "https://support.apple.com/en-gb/109020")
        default: return nil
        }
    }
    static func suggested(for name: String) -> Self {
        let value = name.lowercased()
        if value.contains("pencil") || value.contains("stylus") { return .stylus }
        if value.contains("keyboard") { return .keyboard }
        if value.contains("mouse") { return .mouse }
        if value.contains("airpod") || value.contains("headphone") || value.contains("earbud") { return .headphones }
        if value.contains("suunto") || value.contains("watch") { return .watch }
        return .other
    }
}
enum NotificationSupport: String, Codable, CaseIterable, Identifiable {
    case untested = "未验证", confirmed = "我已确认会提醒", unavailable = "测试后未响应"
    var id: String { rawValue }
}
struct SavedDevice: Identifiable, Codable {
    let id: UUID
    var advertisedName: String
    var nickname: String
    var kind: DeviceKind
    var storageNote = ""
    var notificationSupport: NotificationSupport = .untested
    var services: [String] = []
    var lastSeen: Date?
    var lastSource = "未知"
    var displayName: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? advertisedName : nickname }
}

/// Identity is CoreBluetooth's per-app UUID, never just a matching display name.
final class DeviceLibrary: ObservableObject {
    @Published private(set) var devices: [SavedDevice] = []
    private let defaults: UserDefaults
    private let key = "deviceLibrary.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([SavedDevice].self, from: data) {
            var seen = Set<UUID>()
            devices = decoded.filter { seen.insert($0.id).inserted }
        }
        if let id = UUID(uuidString: defaults.string(forKey: "targetID") ?? ""), item(id) == nil {
            let name = defaults.string(forKey: "targetName") ?? "已登记设备"
            let legacy = SavedDevice(id: id, advertisedName: name, nickname: name, kind: .watch,
                services: defaults.stringArray(forKey: "services") ?? [],
                lastSeen: defaults.object(forKey: "lastSeen") as? Date,
                lastSource: defaults.string(forKey: "lastSource") ?? "未知")
            var migrated = legacy
            if defaults.bool(forKey: "watchSound.\(id.uuidString).手机通知转发（实验）.verified") {
                migrated.notificationSupport = .confirmed
            }
            devices.append(migrated); persist()
        }
    }
    func item(_ id: UUID) -> SavedDevice? { devices.first { $0.id == id } }
    func save(_ device: SavedDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index] = device }
        else { devices.append(device) }
        persist()
    }
    func observe(id: UUID, name: String, services: [String]) {
        var device = item(id) ?? SavedDevice(id: id, advertisedName: name, nickname: name,
            kind: name.localizedCaseInsensitiveContains("Suunto") ? .watch : .other)
        device.advertisedName = name
        if !services.isEmpty { device.services = services }
        save(device)
    }
    func recordSignal(id: UUID, source: String, at date: Date) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].lastSeen = date; devices[index].lastSource = source; persist()
    }
    func remove(_ id: UUID) { devices.removeAll { $0.id == id }; persist() }
    private func persist() {
        if let data = try? JSONEncoder().encode(devices) { defaults.set(data, forKey: key) }
    }
}

enum TargetMatchPolicy {
    static func matches(id: UUID, selected: UUID?, name: String, hint: String) -> Bool {
        if let selected { return id == selected }
        let normalized = hint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !normalized.isEmpty && name.uppercased().contains(normalized)
    }
}
