import Foundation
import Combine

enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    case watch = "手表／手环", headphones = "耳机", other = "其他 BLE 物品"
    var id: String { rawValue }
    var icon: String { self == .watch ? "applewatch" : self == .headphones ? "headphones" : "shippingbox" }
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
