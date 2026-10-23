import Foundation
import Combine
import UserNotifications

/// Uses the notification route verified on the user's watch. No GATT alert writes.
final class WatchSoundController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var message = "点击让手表响铃，前台或锁屏均可听声寻找"
    @Published private(set) var noticePermission = ""
    @Published private(set) var needsPermission = false
    @Published private(set) var isRinging = false
    @Published private(set) var preparing = false
    @Published private(set) var remaining = 0
    @Published private(set) var calibrated = false
    @Published private(set) var threshold = -65
    @Published private(set) var calibrationSource = ""
    @Published private(set) var armed = false
    var log: ((String, [String: Any]) -> Void)?
    private let notifications = UNUserNotificationCenter.current()
    private var deviceID = ""
    private var gate = CloseRangeGate()
    private var deadline: Date?
    private var automatic = false
    private var preparingAutomation = false
    private var ids: Set<String> = []
    private var session = UUID()
    private var key: String { "watchSound.\(deviceID)" }

    override init() {
        super.init()
        notifications.delegate = self
        notifications.getPendingNotificationRequests { [weak self] requests in
            DispatchQueue.main.async {
                guard let self else { return }
                let old = requests.map(\.identifier).filter { $0.hasPrefix("finder-watch-") && !self.ids.contains($0) }
                self.notifications.removePendingNotificationRequests(withIdentifiers: old)
            }
        }
        refreshPermission()
    }
    func setDevice(_ id: UUID?) {
        let newID = id?.uuidString ?? ""
        guard newID != deviceID else { return }
        stop(); deviceID = newID
        let d = UserDefaults.standard
        let oldKey = key + ".手机通知转发（实验）"
        calibrationSource = d.string(forKey: key + ".source") ?? d.string(forKey: oldKey + ".source") ?? ""
        threshold = d.object(forKey: key + ".threshold") as? Int ?? d.object(forKey: oldKey + ".threshold") as? Int ?? -65
        calibrated = !calibrationSource.isEmpty
    }
    func refreshPermission() {
        notifications.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.needsPermission = settings.authorizationStatus != .authorized
                self?.noticePermission = settings.authorizationStatus == .authorized ? "通知已允许" : "请允许通知，并检查手表的共享系统通知设置"
            }
        }
    }
    func authorizeNotifications() {
        notifications.requestAuthorization(options: [.alert, .sound]) { [weak self] allowed, error in
            DispatchQueue.main.async {
                self?.refreshPermission()
                self?.message = error?.localizedDescription ?? (allowed ? "可以开始响铃" : "请到 iPhone 设置中允许本 App 通知")
            }
        }
    }
    func ring() {
        stop()
        guard !deviceID.isEmpty else { message = "请先登记你的手表"; return }
        preparing = true
        let token = session
        notifications.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self, self.session == token else { return }
                self.preparing = false
                guard settings.authorizationStatus == .authorized else {
                    self.message = "请先允许通知"; self.refreshPermission(); return
                }
                self.beginSequence(automatic: false)
            }
        }
    }
    private func beginSequence(automatic: Bool) {
        self.automatic = automatic; preparingAutomation = false
        armed = false; isRinging = true; preparing = false
        deadline = Date().addingTimeInterval(WatchRingPlan.delays.last! + 2)
        remaining = Int(WatchRingPlan.delays.last!)
        message = "已安排 5、10、15、20 秒四次提醒，可锁屏听声"
        let token = session
        for (index, delay) in WatchRingPlan.delays.enumerated() {
            let id = "finder-watch-\(UUID().uuidString)"
            ids.insert(id)
            let content = UNMutableNotificationContent()
            content.title = T("寻找 Suunto · \(index + 1)/4")
            content.body = T("请听手表的提示音。找到后返回 App 停止提醒。")
            content.sound = .default
            content.threadIdentifier = "suunto-finder-sound"
            let request = UNNotificationRequest(identifier: id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
            notifications.add(request) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.session == token, self.ids.contains(id) else {
                        self.notifications.removePendingNotificationRequests(withIdentifiers: [id])
                        self.notifications.removeDeliveredNotifications(withIdentifiers: [id]); return
                    }
                    if let error {
                        self.stop(); self.message = "通知安排失败：\(error.localizedDescription)"
                        self.log?("watchNotificationError", ["error": error.localizedDescription])
                    } else { self.log?("watchNotificationScheduled", ["delay": delay, "index": index + 1, "automatic": automatic]) }
                }
            }
        }
    }
    func calibrate(_ signal: SignalWindow, at now: Date) {
        stop()
        let samples = signal.samples.filter { (0..<12).contains(now.timeIntervalSince($0.time)) }
        guard let last = samples.last, now.timeIntervalSince(last.time) < 3,
              samples.count >= 8, let first = samples.first, last.time.timeIntervalSince(first.time) >= 7,
              let baseline = signal.median(samples.map(\.rssi)),
              let deviation = signal.median(samples.map { abs($0.rssi - baseline) }), deviation <= 6,
              zip(samples, samples.dropFirst()).allSatisfy({ $1.time.timeIntervalSince($0.time) <= 3 }) else {
            message = "请在你希望开始响铃的信号条件下，保持手机姿势稳定 12 秒后记录"; return
        }
        threshold = baseline
        calibrationSource = signal.source; calibrated = true
        UserDefaults.standard.set(threshold, forKey: key + ".threshold")
        UserDefaults.standard.set(calibrationSource, forKey: key + ".source")
        message = "触发信号已记录，可开启本次自动响铃"
    }
    func arm() {
        stop()
        guard calibrated, !deviceID.isEmpty else { message = "请先记录触发信号"; return }
        preparing = true; preparingAutomation = true
        let token = session
        notifications.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self, self.session == token else { return }
                self.preparing = false; self.preparingAutomation = false
                guard settings.authorizationStatus == .authorized else { self.message = "请先允许通知"; self.refreshPermission(); return }
                self.armed = true; self.deadline = Date().addingTimeInterval(120); self.remaining = 120
                self.message = "等待信号持续达到已保存强度，最多两分钟"
            }
        }
    }
    func update(signal: SignalWindow, at now: Date, running: Bool) {
        guard let deadline else { return }
        remaining = max(0, Int(ceil(deadline.timeIntervalSince(now) - (isRinging ? 2 : 0))))
        if now >= deadline { stop(); message = "本轮已结束，需要时可再响一轮"; return }
        guard armed || automatic else { return }
        guard running, signal.source == calibrationSource else { stop(); message = "自动提醒已暂停；来源变化时请重新校准"; return }
        let near = gate.update(value: signal.value(at: now), sampleTime: signal.last?.time, threshold: threshold, at: now)
        if automatic && !near { stop(); message = "信号减弱或中断，自动响铃已停止" }
        else if armed && near { beginSequence(automatic: true) }
    }
    /// Explicit four-notification sequences survive locking. RSSI automation requires the foreground.
    func suspend() { if armed || automatic || preparingAutomation { stop() } }
    func stop() {
        session = UUID(); armed = false; automatic = false; preparingAutomation = false; isRinging = false; preparing = false
        remaining = 0; deadline = nil; gate.reset()
        notifications.removePendingNotificationRequests(withIdentifiers: Array(ids))
        notifications.removeDeliveredNotifications(withIdentifiers: Array(ids))
        ids.removeAll(); message = "提醒已停止"
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.ids.contains(notification.request.identifier) else { completionHandler([]); return }
            completionHandler([.banner, .list, .sound])
            self.log?("localNotificationPresented", ["id": notification.request.identifier, "watchReceiptKnown": false])
        }
    }
}
