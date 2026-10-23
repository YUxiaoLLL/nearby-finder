import Foundation
import Combine
import CoreLocation
import MapKit

struct LastPlaceRecord: Codable, Identifiable {
    let deviceID: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let locationTime: Date
    let signalTime: Date
    let rssi: Int
    let source: String
    // Raw latitude/longitude always stay in Core Location's coordinate space.
    var mapLatitude: Double? = nil
    var mapLongitude: Double? = nil
    var mapSource: String? = nil
    var qualityVersion: Int? = nil
    var userRejected: Bool? = nil
    var id: String { "\(deviceID)-\(signalTime.timeIntervalSince1970)" }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var isValid: Bool {
        PlaceGeometry.valid(latitude, longitude) && accuracy.isFinite && (0...10000).contains(accuracy)
            && (-126 ... -1).contains(rssi) && locationTime <= signalTime
    }
}

/// Records the PHONE at a current signal. No location claim is made for the BLE item.
final class LastPlaceController: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var lastPlace: LastPlaceRecord?
    @Published private(set) var systemMapBridge: SystemMapBridge?
    @Published private(set) var renderedDifference: Double?
    private var phoneFixes: [PhoneLocationFix] = []
    private var mapFixes: [PhoneLocationFix] = []
    var shouldMatchSystemMap: Bool {
        enabled && seeking && !reducedAccuracy &&
            (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways)
    }
    @Published private(set) var alignment: PlaceDisplayAlignment?
    @Published private(set) var manualReference: ManualPlaceReference?
    @Published private(set) var enabled = (UserDefaults.standard.object(forKey: "lastPlace.enabled") as? Bool ?? true)
    @Published private(set) var status = "开启后，记录收到信号时手机的位置参考"
    @Published private(set) var reducedAccuracy = false
    @Published private(set) var authorizationDenied = false
    @Published private(set) var automaticPaused = false
    private let manager = CLLocationManager()
    private var deviceID = ""
    private var seeking = false
    private var trackingStarted: Date?
    private var window = PhoneLocationWindow()
    private var signalHistory = PlaceSignalHistory()
    private var signal: PlaceSignalEvidence? { signalHistory.live }
    private var signalPersistedAt: Date?
    private var key: String { "lastPlace.record.\(deviceID)" }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }
    func setDevice(_ id: UUID?) {
        let value = id?.uuidString ?? ""
        guard deviceID != value else { return }
        persistSignal()
        stopTracking()
        deviceID = value; signalHistory = PlaceSignalHistory(); signalPersistedAt = nil
        lastPlace = nil; manualReference = nil; alignment = nil; systemMapBridge = nil; renderedDifference = nil; phoneFixes = []; mapFixes = []
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key + ".signal"),
           let saved = try? JSONDecoder().decode(PlaceSignalEvidence.self, from: data), saved.time <= Date() {
            signalHistory = PlaceSignalHistory(restored: saved, deviceID: value)
        }
        automaticPaused = false
        UserDefaults.standard.removeObject(forKey: key + ".paused")
        if let data = UserDefaults.standard.data(forKey: key + ".correction") {
            let saved = try? JSONDecoder().decode(PlaceDisplayAlignment.self, from: data)
            // V0.11 offsets had no map-coordinate provenance. Keep the manual history,
            // but do not apply an unverified old offset to fresh automatic records.
            alignment = saved?.version == 2 ? saved : nil
        }
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(LastPlaceRecord.self, from: data),
           saved.deviceID == value, saved.isValid { lastPlace = saved }
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key + ".manual"),
           let saved = try? JSONDecoder().decode(ManualPlaceReference.self, from: data), saved.belongs(to: value) {
            manualReference = saved
        }
        preserveLegacyAlignment()
        if let data = UserDefaults.standard.data(forKey: key + ".mapBridge") {
            systemMapBridge = try? JSONDecoder().decode(SystemMapBridge.self, from: data)
        }
        updateTracking()
    }
    private func preserveLegacyAlignment() {
        // Preserve a valid previous confirmation as a separate historical reference.
        // Migration below requires a matching raw fix before enabling display correction.
        guard manualReference == nil, let place = lastPlace,
              let data = UserDefaults.standard.data(forKey: key + ".alignment"),
              let old = try? JSONDecoder().decode(LocalMapAlignment.self, from: data),
              PlaceGeometry.valid(old.mapLatitude, old.mapLongitude),
              abs(place.signalTime.timeIntervalSince(old.time)) <= 60,
              PlaceGeometry.distance(place.latitude, place.longitude, old.latitude, old.longitude) <= 30 else { return }
        let ref = ManualPlaceReference(deviceID: deviceID, latitude: old.mapLatitude, longitude: old.mapLongitude,
            signalTime: min(place.signalTime, old.time), rssi: place.rssi, source: place.source,
            confirmedAt: old.time, note: "由旧版地图对齐保留，请核对历史时间")
        saveManual(ref)
    }
    func setSeeking(_ active: Bool) {
        seeking = active
        if !active { signalHistory.stopLive(); persistSignal(); stopTracking() }
        if active && enabled && manager.authorizationStatus == .notDetermined { enable() }
        updateTracking()
    }
    func enable() {
        enabled = true; UserDefaults.standard.set(true, forKey: "lastPlace.enabled")
        if manager.authorizationStatus == .notDetermined {
            status = "请选择使用 App 期间允许定位"
            manager.requestWhenInUseAuthorization()
        } else { updateTracking() }
    }
    func disable() {
        enabled = false; UserDefaults.standard.set(false, forKey: "lastPlace.enabled")
        stopTracking(); updateTracking()
    }
    func clear() {
        lastPlace = nil; manualReference = nil; alignment = nil; systemMapBridge = nil; renderedDifference = nil; phoneFixes = []; mapFixes = []; signalHistory = PlaceSignalHistory(); signalPersistedAt = nil; automaticPaused = false
        stopTracking()
        if !deviceID.isEmpty {
            for suffix in ["", ".manual", ".alignment", ".paused", ".signal", ".correction", ".mapBridge", ".renderAudit"] { UserDefaults.standard.removeObject(forKey: key + suffix) }
        }
        status = "此物品的自动位置、手动参考与旧对齐已删除"
        updateTracking()
    }
    private func stopTracking() {
        manager.stopUpdatingLocation(); trackingStarted = nil; window.reset()
    }
    private func updateTracking() {
        let auth = manager.authorizationStatus
        reducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        authorizationDenied = auth == .denied || auth == .restricted
        guard enabled else { stopTracking(); status = "自动位置记录已关闭；已有手动参考仍保留"; return }
        guard auth == .authorizedWhenInUse || auth == .authorizedAlways else {
            stopTracking()
            status = authorizationDenied ? "定位未授权；可手动确认已有信号的参考位置，或在设置中授权" : "等待定位授权"
            return
        }
        guard !automaticPaused else { stopTracking(); status = "已标记自动位置不可靠；可手动对齐，或点重新采集再试"; return }
        guard seeking, !deviceID.isEmpty else { stopTracking(); status = "自动采样已暂停；历史记录和手动参考仍保留"; return }
        guard !reducedAccuracy else { stopTracking(); status = "请开启精确位置；粗略位置不保存为标记"; return }
        if trackingStarted == nil {
            trackingStarted = Date(); window.reset()
            status = "正在自动读取手机位置…"
            manager.startUpdatingLocation()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateTracking() }
    func observeSignal(rssi: Int, source: String, at time: Date) {
        guard seeking, !deviceID.isEmpty, (-126 ... -1).contains(rssi) else { return }
        let evidence = PlaceSignalEvidence(deviceID: deviceID, time: time, rssi: rssi, source: source)
        guard signalHistory.observe(evidence, deviceID: deviceID) else { return }
        if signalPersistedAt == nil || time.timeIntervalSince(signalPersistedAt!) >= 3 { persistSignal() }
        saveIfContemporaneous(at: time)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard enabled, seeking, !automaticPaused, !deviceID.isEmpty, let started = trackingStarted,
              manager.accuracyAuthorization == .fullAccuracy else { return }
        let now = Date()
        // Process individual samples, not merely the final element in a batch.
        for fix in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            let sample = PhoneLocationFix(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                accuracy: fix.horizontalAccuracy, time: fix.timestamp)
            if ProcessInfo.processInfo.arguments.contains("--location-audit") {
                UserDefaults.standard.set(["latitude": sample.latitude, "longitude": sample.longitude,
                    "accuracy": sample.accuracy, "time": sample.time.timeIntervalSince1970], forKey: "locationAudit.core")
            }
            if PlaceGeometry.valid(sample.latitude, sample.longitude), sample.accuracy > 0, sample.accuracy <= 20,
               (0...10).contains(now.timeIntervalSince(sample.time)) {
                phoneFixes.append(sample)
                phoneFixes = Array(phoneFixes.filter { (0...20).contains(now.timeIntervalSince($0.time)) }.suffix(40))
                matchSystemMap(at: now)
            }
            let accepted = window.add(sample, sessionStarted: started, at: now)
            if !accepted {
                status = "定位缓存、过期或不确定范围过大；保留历史参考，等待新样本"
                continue
            }
            if window.rejectedJump { status = "检测到定位跳动，重新等待稳定样本" }
        }
        saveIfContemporaneous(at: now)
    }
    private func saveIfContemporaneous(at now: Date) {
        guard enabled, seeking, !automaticPaused, trackingStarted != nil,
              manager.accuracyAuthorization == .fullAccuracy, let signal else { return }
        var duration: TimeInterval = 6
        if let old = lastPlace, let recent = window.samples.last,
           now.timeIntervalSince(old.signalTime) < 60,
           PlaceGeometry.distance(old.latitude, old.longitude, recent.latitude, recent.longitude) > 150 {
            duration = 20
        }
        // A fresh valid fix can be recorded immediately; large jumps still need a stable window.
        let candidate = window.candidate(at: now, minimumDuration: duration)
        guard let location = candidate else {
            if !window.samples.isEmpty {
                status = duration > 6 ? "新位置与旧记录差距较大，需稳定 20 秒再更新" : "正在积累稳定定位（至少 5 个样本、跨度 6 秒）"
            }
            return
        }
        guard LastPlacePolicy.canAssociate(locationTime: location.time, accuracy: location.accuracy,
            signalTime: signal.time, at: now) else { return }
        if let old = lastPlace, old.signalTime >= signal.time { return }
        var record = LastPlaceRecord(deviceID: deviceID, latitude: location.latitude, longitude: location.longitude,
            accuracy: location.accuracy, locationTime: location.time, signalTime: signal.time,
            rssi: signal.rssi, source: signal.source, qualityVersion: 3)
        if let coordinate = systemMapBridge?.coordinate(latitude: record.latitude, longitude: record.longitude, at: now) {
            record.mapLatitude = coordinate.0; record.mapLongitude = coordinate.1; record.mapSource = "paired-system-map"
        }
        guard record.isValid else { return }
        lastPlace = record
        if let data = try? JSONEncoder().encode(record) { UserDefaults.standard.set(data, forKey: key) }
        status = "已自动记录收到信号时的手机位置"
    }
    func observeSystemMap(_ location: CLLocation, source: String = "normal-map") {
        if ProcessInfo.processInfo.arguments.contains("--location-audit") {
            UserDefaults.standard.set(["enabled": enabled, "seeking": seeking, "reduced": reducedAccuracy,
                "authorized": manager.authorizationStatus.rawValue, "time": Date().timeIntervalSince1970],
                forKey: "locationAudit.probeState")
        }
        guard shouldMatchSystemMap else { return }
        if ProcessInfo.processInfo.arguments.contains("--location-audit") {
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "locationAudit." + source) + 1,
                forKey: "locationAudit." + source)
        }
        let now = Date()
        let fix = PhoneLocationFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy, time: location.timestamp)
        if ProcessInfo.processInfo.arguments.contains("--location-audit") {
            UserDefaults.standard.set(["age": now.timeIntervalSince(fix.time), "accuracy": fix.accuracy,
                "latitude": fix.latitude, "longitude": fix.longitude, "time": fix.time.timeIntervalSince1970], forKey: "locationAudit.mapInput")
        }
        guard SystemMapBridge.canQueue(fix, at: now) else { return }
        mapFixes.append(fix)
        mapFixes = Array(mapFixes.filter { SystemMapBridge.canQueue($0, at: now) }.suffix(40))
        matchSystemMap(at: now)
    }
    private func matchSystemMap(at now: Date) {
        if ProcessInfo.processInfo.arguments.contains("--location-audit") {
            let gap = mapFixes.last.flatMap { m in phoneFixes.map { abs($0.time.timeIntervalSince(m.time)) }.min() } ?? -1
            UserDefaults.standard.set(["phoneCount": Double(phoneFixes.count), "mapCount": Double(mapFixes.count),
                "nearestTimeGap": gap], forKey: "locationAudit.pairing")
        }
        for map in mapFixes.reversed() {
            guard let phone = phoneFixes.min(by: { abs($0.time.timeIntervalSince(map.time)) < abs($1.time.timeIntervalSince(map.time)) }),
                  let bridge = SystemMapBridge.pair(phone: phone, map: map, at: now) else { continue }
            if let old = systemMapBridge, old.map.time >= bridge.map.time { return }
            systemMapBridge = bridge
            if let data = try? JSONEncoder().encode(bridge) { UserDefaults.standard.set(data, forKey: key + ".mapBridge") }
            // Complete a recent record without changing its raw phone coordinates or sighting time.
            if var record = lastPlace, record.mapLatitude == nil,
               abs(record.locationTime.timeIntervalSince(phone.time)) <= 10,
               let point = bridge.coordinate(latitude: record.latitude, longitude: record.longitude, at: now) {
                record.mapLatitude = point.0; record.mapLongitude = point.1; record.mapSource = "paired-system-map"
                lastPlace = record
                if let data = try? JSONEncoder().encode(record) { UserDefaults.standard.set(data, forKey: key) }
            }
            return
        }
    }
    func confirmRenderedCoordinate(expected: CLLocationCoordinate2D, actual: CLLocationCoordinate2D) {
        let difference = PlaceGeometry.distance(expected.latitude, expected.longitude, actual.latitude, actual.longitude)
        guard difference.isFinite else { return }
        if renderedDifference != difference { renderedDifference = difference }
        UserDefaults.standard.set(["differenceMeters": difference, "time": Date().timeIntervalSince1970], forKey: key + ".renderAudit")
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        window.reset()
        if enabled && seeking { status = "暂未取得可用定位，保留历史记录；可手动确认参考位置" }
    }
    func improveLocation() {
        automaticPaused = false; UserDefaults.standard.removeObject(forKey: key + ".paused")
        stopTracking(); enable()
        if (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways),
           manager.accuracyAuthorization == .reducedAccuracy {
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "FindWatchLocation") { [weak self] _ in
                DispatchQueue.main.async { self?.updateTracking() }
            }
        } else { updateTracking() }
    }
    func rejectAutomaticLocation() {
        guard var place = lastPlace else { return }
        place.userRejected = true; lastPlace = place; automaticPaused = true
        if let data = try? JSONEncoder().encode(place) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(true, forKey: key + ".paused")
        stopTracking(); status = "自动位置已标记为不可靠并暂停更新；请手动对齐或重新采集"
    }
    private func persistSignal() {
        guard let latest = signalHistory.latest, latest.deviceID == deviceID, !deviceID.isEmpty else { return }
        if let data = try? JSONEncoder().encode(latest) {
            UserDefaults.standard.set(data, forKey: key + ".signal"); signalPersistedAt = latest.time
        }
    }
    var calibrationReference: LastPlaceRecord? {
        let manualTime = manualReference?.signalTime ?? .distantPast
        let automaticTime = lastPlace?.signalTime ?? .distantPast
        if let evidence = signalHistory.latest, evidence.time >= max(manualTime, automaticTime) {
            let now = Date()
            let fresh = window.samples.last.flatMap { (0...3).contains(now.timeIntervalSince($0.time)) ? $0 : nil }
            let matchedFix = fresh.flatMap { (0...3).contains(evidence.time.timeIntervalSince($0.time)) ? $0 : nil }
            let matchedRecord = lastPlace.flatMap { abs(evidence.time.timeIntervalSince($0.signalTime)) <= 3 ? $0 : nil }
            return LastPlaceRecord(deviceID: deviceID,
                latitude: matchedFix?.latitude ?? matchedRecord?.latitude ?? manualReference?.latitude ?? 0,
                longitude: matchedFix?.longitude ?? matchedRecord?.longitude ?? manualReference?.longitude ?? 0,
                accuracy: matchedFix?.accuracy ?? matchedRecord?.accuracy ?? 10000,
                locationTime: min(matchedFix?.time ?? matchedRecord?.locationTime ?? evidence.time, evidence.time),
                signalTime: evidence.time, rssi: evidence.rssi, source: evidence.source, qualityVersion: 3)
        }
        if let manualReference { return displayRecord(manualReference) }
        return lastPlace
    }
    func calibrationCoordinate(_ reference: LastPlaceRecord) -> CLLocationCoordinate2D {
        guard reference.accuracy > 0, reference.accuracy <= 20 else { return reference.coordinate }
        let point = alignment?.corrected(deviceID: deviceID, latitude: reference.latitude, longitude: reference.longitude)
            ?? systemMapBridge?.coordinate(latitude: reference.latitude, longitude: reference.longitude, at: Date())
        if let point { return CLLocationCoordinate2D(latitude: point.0, longitude: point.1) }
        return reference.coordinate
    }
    func calibrateMap(_ reference: LastPlaceRecord, selected: CLLocationCoordinate2D, note: String) -> Bool {
        guard reference.deviceID == deviceID, reference.isValid,
              PlaceGeometry.valid(selected.latitude, selected.longitude), reference.signalTime <= Date() else {
            status = "设备或信号记录已变化，请重新打开手动对齐"; return false
        }
        let ref = ManualPlaceReference(deviceID: deviceID, latitude: selected.latitude, longitude: selected.longitude,
            signalTime: reference.signalTime, rssi: reference.rssi, source: reference.source,
            confirmedAt: Date(), note: String(note.prefix(120)))
        guard ref.isValid else { return false }
        alignment = nil
        UserDefaults.standard.removeObject(forKey: key + ".correction")
        saveManual(ref)
        // Only a real phone fix belonging to this signal can establish an offset.
        // Historical/manual-only placeholders must never become GPS anchors.
        if reference.accuracy > 0 && reference.accuracy <= 20,
           (0...3).contains(reference.signalTime.timeIntervalSince(reference.locationTime)),
           PlaceGeometry.distance(reference.latitude, reference.longitude, selected.latitude, selected.longitude) <= 2000 {
            let correction = PlaceDisplayAlignment(deviceID: deviceID, latitude: reference.latitude,
                longitude: reference.longitude, targetLatitude: selected.latitude, targetLongitude: selected.longitude, version: 2)
            alignment = correction
            if let data = try? JSONEncoder().encode(correction) { UserDefaults.standard.set(data, forKey: key + ".correction") }
        }
        status = alignment == nil ? "已保存手动参考；取得手机定位后可再次对齐，使后续自动位置同步校正" : "已对齐；附近 500 米内的自动位置将使用此显示校正"
        automaticPaused = false
        updateTracking()
        return true
    }
    private func saveManual(_ reference: ManualPlaceReference) {
        manualReference = reference
        if let data = try? JSONEncoder().encode(reference) { UserDefaults.standard.set(data, forKey: key + ".manual") }
    }
    func resetMapCalibration() {
        manualReference = nil; alignment = nil
        UserDefaults.standard.removeObject(forKey: key + ".correction")
        UserDefaults.standard.removeObject(forKey: key + ".manual")
        UserDefaults.standard.removeObject(forKey: key + ".alignment")
        status = "手动参考已撤销；原始自动定位记录保持不变"
    }
    func displayRecord(_ reference: ManualPlaceReference) -> LastPlaceRecord {
        LastPlaceRecord(deviceID: reference.deviceID, latitude: reference.latitude, longitude: reference.longitude,
            accuracy: 0, locationTime: reference.signalTime, signalTime: reference.signalTime,
            rssi: reference.rssi, source: reference.source, qualityVersion: 3)
    }
    private func mappedRecord(_ raw: LastPlaceRecord, point: (Double, Double), manual: Bool = false) -> LastPlaceRecord {
        LastPlaceRecord(deviceID: raw.deviceID, latitude: point.0, longitude: point.1,
            accuracy: manual ? 0 : raw.accuracy, locationTime: raw.locationTime, signalTime: raw.signalTime,
            rssi: raw.rssi, source: raw.source, qualityVersion: raw.qualityVersion)
    }
    var displayedPlace: LastPlaceRecord? {
        if let raw = lastPlace {
            // Manual correction already maps RAW -> selected map point. Never stack it on a system map shift.
            if let point = alignment?.corrected(deviceID: deviceID, latitude: raw.latitude, longitude: raw.longitude) {
                return mappedRecord(raw, point: point, manual: true)
            }
            if let lat = raw.mapLatitude, let lon = raw.mapLongitude, PlaceGeometry.valid(lat, lon) {
                return mappedRecord(raw, point: (lat, lon))
            }
            if let point = systemMapBridge?.coordinate(latitude: raw.latitude, longitude: raw.longitude, at: Date()) {
                return mappedRecord(raw, point: point)
            }
            // An unverified raw point must not be plotted on a possibly different map coordinate system.
            return nil
        }
        return manualReference.map { displayRecord($0) }
    }
    var displayLabel: String {
        if let raw = lastPlace, alignment?.corrected(deviceID: deviceID, latitude: raw.latitude, longitude: raw.longitude) != nil {
            return "自动记录 · 手动对齐"
        }
        if lastPlace == nil && manualReference != nil { return "手动确认的历史参考" }
        return "自动记录 · 已匹配系统地图"
    }
    var coordinateCheckSummary: String {
        if let bridge = systemMapBridge {
            return "系统定位与地图显示坐标差约 \(Int(bridge.offset.rounded())) 米；已按同机同期数据匹配，不是 GPS 精度提升。"
        }
        return "等待系统地图与手机定位匹配；原始记录保留，暂不绘制未经匹配的位置。"
    }
    func openMap(manual: Bool = false) {
        let place: LastPlaceRecord?
        if manual, let reference = manualReference { place = displayRecord(reference) } else { place = displayedPlace }
        guard let place else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = manual ? "手动确认的手机位置参考" : "收到物品信号时的手机位置（非物品坐标）"
        item.openInMaps(launchOptions: nil)
    }
}
