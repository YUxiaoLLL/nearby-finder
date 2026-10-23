import Foundation
import Combine
import CoreBluetooth
import UIKit
import AudioToolbox

struct DeviceRow: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var time: Date
    var connectable: Bool?
    var services: [String]
}

final class FinderModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let library = DeviceLibrary()
    let watchSound = WatchSoundController()
    let lastPlace = LastPlaceController()
    let signalGuide = SignalGuideController()
    @Published var serial: String
    @Published private(set) var bluetooth = "初始化"
    @Published private(set) var status = "点击开始扫描，允许蓝牙访问"
    @Published private(set) var rows: [DeviceRow] = []
    @Published private(set) var selectedName = "尚未识别手表"
    @Published private(set) var targetID: UUID?
    @Published private(set) var connection = "未连接"
    @Published private(set) var signal = SignalWindow()
    @Published private(set) var scanning = false
    @Published private(set) var running = false
    @Published private(set) var now = Date()
    @Published private(set) var logs: [String] = []
    @Published private(set) var restartCount = 0
    @Published private(set) var sampleCount = 0
    @Published private(set) var rssiError = ""
    @Published private(set) var exportedLog: URL?
    @Published var keepAwake = UserDefaults.standard.object(forKey: "keepAwake") as? Bool ?? true {
        didSet {
            defaults.set(keepAwake, forKey: "keepAwake")
            UIApplication.shared.isIdleTimerDisabled = keepAwake && running && appActive
        }
    }
    @Published var haptics = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
        didSet { defaults.set(haptics, forKey: "haptics") }
    }
    @Published var sound = UserDefaults.standard.bool(forKey: "sound") {
        didSet { defaults.set(sound, forKey: "sound") }
    }
    @Published private(set) var lastSeen = UserDefaults.standard.object(forKey: "lastSeen") as? Date
    @Published private(set) var lastSeenSource = UserDefaults.standard.string(forKey: "lastSource") ?? "未知"
    private var lastFeedback = Date.distantPast
    private var strongSince: Date?
    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var target: CBPeripheral?
    private var clock: Timer?
    private var lastAdvertisement: Date?
    private var scanStarted = Date()
    private var lastRestart = Date.distantPast
    private var connectionStarted: Date?
    private var rssiRequested: Date?
    private var connectedAt: Date?
    private var autoConnect = false
    private var reconnectAt: Date?
    private var retries = 0
    private var appActive = true
    private var resumeOnActive = false
    private var defaults: UserDefaults { .standard }
    private var normalizedSerial: String { serial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    var currentDevice: SavedDevice? {
        guard let id = UUID(uuidString: defaults.string(forKey: "targetID") ?? "") else { return nil }
        return library.item(id)
    }
    var hasSavedTarget: Bool { UUID(uuidString: defaults.string(forKey: "targetID") ?? "") != nil }
    var freshRSSI: Int? { running ? signal.value(at: now) : nil }
    var trend: String { running ? signal.trend(at: now) : "监听已停止" }
    var observation: String {
        guard running, let first = signal.samples.first, let last = signal.last else { return "尚未验证持续 RSSI" }
        let duration = last.time.timeIntervalSince(first.time)
        return signal.isFresh(at: now) && signal.samples.count >= 5 && duration >= 10
            ? "已收到连续样本：≥5 个，跨度 ≥10 秒"
            : "本次有效样本 \(sampleCount) 个；当前窗口跨度 \(Int(duration)) 秒"
    }

    override init() {
        serial = UserDefaults.standard.string(forKey: "serial") ?? ""
        selectedName = UserDefaults.standard.string(forKey: "targetName") ?? "尚未选择设备"
        super.init()
        if let device = currentDevice {
            selectedName = device.displayName
            lastSeen = device.lastSeen
            lastSeenSource = device.lastSource
        }
        watchSound.log = { [weak self] event, data in self?.record(event, data) }
        let savedID = UUID(uuidString: defaults.string(forKey: "targetID") ?? "")
        watchSound.setDevice(savedID); lastPlace.setDevice(savedID); signalGuide.setDevice(savedID)
        // All model mutations and delegate callbacks use the main queue.
        central = CBCentralManager(delegate: self, queue: .main)
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        record("launch", ["version":"0.12-native", "savedTarget":defaults.string(forKey:"targetID") ?? "none"])
    }

    func record(_ event: String, _ data: [String: Any] = [:]) {
        let object: [String: Any] = ["time":ISO8601DateFormatter().string(from: Date()), "event":event, "data":data]
        guard let bytes = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), let line = String(data: bytes, encoding:.utf8) else { return }
        logs.append(line)
        // Ring buffer bounds memory on long walks. Export before ending a test.
        if logs.count > 4000 { logs.removeFirst(logs.count-4000) }
    }
    private func recordError(_ event: String, _ error: Error?) {
        guard let e = error as NSError? else { record(event, ["error":"none"]); return }
        record(event, ["domain":e.domain,"code":e.code,"message":e.localizedDescription,"details":String(describing:e.userInfo)])
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetooth = [CBManagerState.unknown:"未知", .resetting:"系统正在重置", .unsupported:"硬件不支持", .unauthorized:"蓝牙权限未授权", .poweredOff:"蓝牙已关闭", .poweredOn:"蓝牙已开启"][central.state] ?? "未知"
        record("centralState", ["raw":central.state.rawValue,"state":bluetooth])
        if central.state == .poweredOn {
            if running && appActive { lastPlace.setSeeking(true); beginScan(); if hasSavedTarget { recoverKnown() } }
        } else {
            watchSound.suspend(); lastPlace.setSeeking(false)
            scanning = false; rssiRequested = nil; reconnectAt = nil
            connectionStarted = nil; connectedAt = nil; target = nil
            signal.reset(); connection = "系统蓝牙不可用"
            status = "请在 iPhone 设置中检查蓝牙与本 App 权限；程序无法替你切换系统蓝牙"
        }
    }
    func start() {
        stop(cancelSoundTests: false)
        serial = normalizedSerial; defaults.set(serial, forKey:"serial")
        lastPlace.setSeeking(true)
        running = true; UIApplication.shared.isIdleTimerDisabled = keepAwake && appActive; signal.reset(); rows = []; sampleCount = 0; restartCount = 0
        lastAdvertisement = nil; strongSince = nil; retries = 0; lastRestart = .distantPast
        status = "选择已收藏设备寻找，或从附近列表添加自己的设备"
        if central.state == .poweredOn { beginScan(); if hasSavedTarget { recoverKnown() } } else { status = "等待系统蓝牙开启／授权" }
    }
    private func beginScan() {
        guard running, appActive, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices:nil, options:[CBCentralManagerScanOptionAllowDuplicatesKey:true])
        scanning = true; scanStarted = Date()
        record("scanStart", ["serviceFilter":"none","allowDuplicates":true])
    }
    func stop(cancelSoundTests: Bool = true) {
        if cancelSoundTests { watchSound.stop() } else { watchSound.suspend() }
        lastPlace.setSeeking(false)
        UIApplication.shared.isIdleTimerDisabled = false
        running = false; resumeOnActive = false; autoConnect = false; reconnectAt = nil
        central?.stopScan(); scanning = false
        if let target, target.state == .connecting || target.state == .connected { central.cancelPeripheralConnection(target) }
        self.target = nil; targetID = nil; connectionStarted = nil; connectedAt = nil; rssiRequested = nil
        connection = "已停止"; status = "已停止；旧读数不会显示为实时信号"
        record("stop")
    }
    func setForeground(_ active: Bool) {
        appActive = active
        record("foreground", ["active":active])
        if !active { let resume = running; stop(cancelSoundTests: false); resumeOnActive = resume; status = "后台已暂停。本版仅在前台寻找。" }
        else if resumeOnActive { resumeOnActive = false; start() }
    }
    func restartScan() {
        guard running, central.state == .poweredOn else { return }
        central.stopScan(); scanning = false; restartCount += 1; lastRestart = Date()
        record("scanRestart", ["count":restartCount,"note":"only app scan; not system bluetooth reset"])
        beginScan(); status = "已重启本 App 扫描（没有关闭系统蓝牙）"
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String:Any], rssi RSSI: NSNumber) {
        guard running, appActive else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "未命名设备"
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        peripherals[peripheral.identifier] = peripheral
        let row = DeviceRow(id:peripheral.identifier,name:name,rssi:RSSI.intValue,time:Date(),connectable:connectable,services:services)
        if let i = rows.firstIndex(where:{$0.id == row.id}) { rows[i] = row } else { rows.append(row) }
        // Bound diagnostics to current sightings. The registered target remains in UserDefaults.
        rows.removeAll { Date().timeIntervalSince($0.time) > 60 }
        rows.sort { $0.rssi > $1.rssi }
        let manufacturer = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.map { String(format:"%02x", $0) }.joined() ?? ""
        record("advertisement", ["id":row.id.uuidString,"name":name,"rssi":RSSI.intValue,"services":services,"connectable":connectable.map { String($0) } ?? "unknown","manufacturerHex":manufacturer,"allFields":String(describing:advertisementData)])
        let savedID = UUID(uuidString: defaults.string(forKey: "targetID") ?? "")
        if TargetMatchPolicy.matches(id: peripheral.identifier, selected: savedID, name: name, hint: serial) {
            if targetID != peripheral.identifier { register(peripheral, name:name, services:services) }
        }
        if targetID == peripheral.identifier {
            if !autoConnect { connectTarget() }
            lastAdvertisement = Date()
            if peripheral.state != .connected { acceptRSSI(RSSI.intValue, source:"广播") }
        }
    }
    private func register(_ peripheral: CBPeripheral, name: String, services: [String]) {
        library.observe(id: peripheral.identifier, name: name, services: services)
        watchSound.setDevice(peripheral.identifier); signalGuide.setDevice(peripheral.identifier)
        lastPlace.setDevice(peripheral.identifier); lastPlace.setSeeking(running && appActive)
        if defaults.string(forKey: "targetID") != peripheral.identifier.uuidString {
            lastSeen = nil; lastSeenSource = "未知"
            defaults.removeObject(forKey: "lastSeen"); defaults.removeObject(forKey: "lastSource")
            defaults.removeObject(forKey: "lastRSSI"); defaults.removeObject(forKey: "services")
        }
        target = peripheral; targetID = peripheral.identifier; selectedName = library.item(peripheral.identifier)?.displayName ?? name; peripheral.delegate = self
        defaults.set(peripheral.identifier.uuidString, forKey:"targetID")
        defaults.set(name, forKey:"targetName")
        if let device = library.item(peripheral.identifier) {
            lastSeen = device.lastSeen; lastSeenSource = device.lastSource
        }
        if !services.isEmpty { defaults.set(services, forKey:"services") }
        record("targetRegistered", ["id":peripheral.identifier.uuidString,"name":name])
        status = "已识别设备，正在寻找。保持手机姿势稳定，缓慢移动。"
    }
    func select(_ row: DeviceRow) {
        // UI asks for explicit confirmation for an unnamed or differently named device.
        guard running, let peripheral = peripherals[row.id] else { status = "先开始扫描，等待设备再次出现"; return }
        if let target, target.identifier != row.id { central.cancelPeripheralConnection(target) }
        autoConnect = false; reconnectAt = nil; connectionStarted = nil; connectedAt = nil; rssiRequested = nil
        signal.reset(); sampleCount = 0; lastAdvertisement = nil
        register(peripheral, name:row.name, services:row.services)
        connectTarget()
    }
    func selectSaved(_ device: SavedDevice) {
        stop()
        defaults.set(device.id.uuidString, forKey: "targetID")
        defaults.set(device.advertisedName, forKey: "targetName")
        defaults.set(device.services, forKey: "services")
        serial = ""; defaults.set("", forKey: "serial")
        selectedName = device.displayName; lastSeen = device.lastSeen; lastSeenSource = device.lastSource
        watchSound.setDevice(device.id); lastPlace.setDevice(device.id); signalGuide.setDevice(device.id)
        start()
    }
    func saveDevice(_ device: SavedDevice) {
        library.save(device)
        if currentDevice?.id == device.id {
            selectedName = device.displayName
            if device.kind != .watch { watchSound.stop() }
        }
    }
    func forgetDevice(_ id: UUID) {
        if currentDevice?.id == id {
            stop(); defaults.removeObject(forKey: "targetID"); defaults.removeObject(forKey: "targetName")
            defaults.removeObject(forKey: "services"); defaults.removeObject(forKey: "lastSeen"); defaults.removeObject(forKey: "lastSource")
            selectedName = "尚未选择设备"; lastSeen = nil; lastSeenSource = "未知"
            serial = ""; defaults.set("", forKey: "serial"); defaults.removeObject(forKey: "lastRSSI")
            watchSound.setDevice(nil); lastPlace.setDevice(nil); signalGuide.setDevice(nil)
        }
        library.remove(id)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("watchSound.\(id.uuidString).") || key == "lastPlace.record.\(id.uuidString)" || key.hasPrefix("lastPlace.record.\(id.uuidString).") {
            defaults.removeObject(forKey: key)
        }
    }
    func addDevice(_ row: DeviceRow, nickname: String, kind: DeviceKind, note: String) {
        guard running, peripherals[row.id] != nil else { status = "请先扫描，等待设备再次出现"; return }
        var device = library.item(row.id) ?? SavedDevice(id: row.id, advertisedName: row.name, nickname: nickname, kind: kind)
        device.nickname = nickname; device.kind = kind; device.storageNote = note; device.services = row.services
        library.save(device); select(row)
    }
    func recoverKnown() {
        if !running { start(); return }
        guard running, central.state == .poweredOn else { return }
        guard let id = UUID(uuidString:defaults.string(forKey:"targetID") ?? "") else { status = "先从附近列表确认并收藏自己的设备"; return }
        var known = central.retrievePeripherals(withIdentifiers:[id])
        let services = (library.item(id)?.services ?? defaults.stringArray(forKey:"services") ?? []).map { CBUUID(string:$0) }
        if !services.isEmpty {
            let connected = central.retrieveConnectedPeripherals(withServices:services)
            record("retrieveConnected", ["services":services.map(\.uuidString),"ids":connected.map { $0.identifier.uuidString }])
            known += connected.filter { $0.identifier == id }
        }
        guard let peripheral = known.first(where:{$0.identifier == id}) else { status = "系统未返回已登记 UUID；继续扫描。不能据此断言手表离线。"; record("retrieveKnownEmpty"); return }
        register(peripheral, name:defaults.string(forKey:"targetName") ?? "已登记设备", services:[])
        record("retrieveKnown", ["id":id.uuidString,"note":"object returned does not prove online"])
        connectTarget()
    }
    func connectTarget() {
        guard running, let target, central.state == .poweredOn else { status = "请先扫描识别，或尝试恢复已登记手表"; return }
        autoConnect = true; retries = 0; rssiError = ""; connect(target)
    }
    private func connect(_ peripheral: CBPeripheral) {
        guard running, appActive else { return }
        // Even if connected elsewhere at system level, establish this central's own connection.
        if connectedAt != nil || connectionStarted != nil { return }
        connection = "正在连接（最多等待 15 秒）"; connectionStarted = Date(); reconnectAt = nil
        record("connectRequest", ["id":peripheral.identifier.uuidString,"peripheralState":peripheral.state.rawValue])
        central.connect(peripheral, options:nil)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard running, appActive, targetID == peripheral.identifier else { central.cancelPeripheralConnection(peripheral); return }
        target = peripheral; peripheral.delegate = self; connectedAt = Date(); connectionStarted = nil; rssiRequested = nil
        signal.reset(); connection = "本 App 已连接；等待 RSSI 回调"; status = "连接本身不是 RSSI。只显示 didReadRSSI 返回的有效数值。"
        record("didConnect", ["id":peripheral.identifier.uuidString]); requestRSSI()
        record("ancsAuthorization", ["authorized": peripheral.ancsAuthorized])
    }
    private func requestRSSI() {
        guard running, appActive, let target, connectedAt != nil, target.state == .connected, rssiRequested == nil else { return }
        rssiRequested = Date(); target.readRSSI(); record("readRSSIRequest")
    }
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard running, targetID == peripheral.identifier, connectedAt != nil else { return }
        rssiRequested = nil
        if let error { rssiError = error.localizedDescription; recordError("readRSSIError",error); return }
        record("didReadRSSI", ["rssi":RSSI.intValue]); acceptRSSI(RSSI.intValue, source:"连接后 readRSSI")
        connection = "本 App 已连接"
    }
    private func acceptRSSI(_ value: Int, source: String) {
        guard signal.add(value,source:source) else { record("invalidRSSI",["value":value,"source":source]); return }
        sampleCount += 1; rssiError = ""
        lastSeen = Date(); lastSeenSource = source
        defaults.set(lastSeen, forKey:"lastSeen"); defaults.set(value, forKey:"lastRSSI")
        defaults.set(source, forKey:"lastSource")
        if let targetID { library.recordSignal(id: targetID, source: source, at: lastSeen ?? Date()) }
        lastPlace.observeSignal(rssi: value, source: source, at: lastSeen ?? Date())
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard targetID == peripheral.identifier else { return }
        recordError("didFailToConnect",error); connectionStarted = nil; connectedAt = nil; rssiRequested = nil
        connection = "连接失败；仍可观察广播"; scheduleReconnect()
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard targetID == peripheral.identifier else { return }
        watchSound.suspend()
        recordError("didDisconnect",error); connectionStarted = nil; connectedAt = nil; rssiRequested = nil
        signal.reset(); strongSince = nil; connection = "已断开；继续扫描"; scheduleReconnect()
    }
    private func scheduleReconnect() {
        guard running, autoConnect, reconnectAt == nil, retries < 3 else { return }
        retries += 1; reconnectAt = Date().addingTimeInterval(Double(retries * 3))
        record("reconnectScheduled",["attempt":retries])
    }
    private func tick() {
        now = Date()
        watchSound.update(signal: signal, at: now, running: running)
        signalGuide.update(signal, at: now, running: running)
        guard running, appActive, central.state == .poweredOn else { return }
        if let started = connectionStarted, now.timeIntervalSince(started) >= 15, let target {
            connectionStarted = nil; record("connectTimeout"); central.cancelPeripheralConnection(target)
            connection = "连接超时，不代表手表没电"; scheduleReconnect()
        }
        if let due = reconnectAt, now >= due, let target { connect(target) }
        if let connectedAt, let target,
           now.timeIntervalSince(signal.last?.time ?? connectedAt) > 15 {
            // A silent connection must not block recovery forever.
            watchSound.suspend()
            self.connectedAt = nil; rssiRequested = nil; strongSince = nil; signal.reset()
            central.cancelPeripheralConnection(target)
            connection = "连接无有效信号，正在恢复"; scheduleReconnect()
            record("staleConnectionRecovery")
        }
        if connectedAt != nil {
            if let requested = rssiRequested, now.timeIntervalSince(requested) > 5 {
                rssiRequested = nil; rssiError = "RSSI 回调超时"; record("readRSSITimeout")
            }
            requestRSSI()
        }
        if let strength = freshRSSI {
            if strength >= -60 { if strongSince == nil { strongSince = now } } else { strongSince = nil }
            let stableStrong = strongSince.map { now.timeIntervalSince($0) >= 5 } ?? false
            let improving = (signal.delta(at: now) ?? 0) >= 4
            let interval: TimeInterval = stableStrong ? 3 : 8
            if !watchSound.isRinging, (stableStrong || improving), now.timeIntervalSince(lastFeedback) >= interval {
                if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                if sound { AudioServicesPlaySystemSound(1057) }
                lastFeedback = now
            }
        } else { strongSince = nil }
        let reference = lastAdvertisement ?? scanStarted
        if connectedAt == nil, connectionStarted == nil, scanning, now.timeIntervalSince(reference) > 20, now.timeIntervalSince(lastRestart) > 25 {
            restartScan()
        }
    }
    func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        guard targetID == peripheral.identifier else { return }
        record("ancsAuthorization", ["authorized": peripheral.ancsAuthorized])
    }
    func export() {
        record("export",["bufferedLines":logs.count])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SuuntoFinder-diagnostics.ndjson")
        do { try logs.joined(separator:"\n").write(to:url,atomically:true,encoding:.utf8); exportedLog = url }
        catch { status = "日志导出失败：\(error.localizedDescription)" }
    }
}
