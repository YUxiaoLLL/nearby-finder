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
    @Published private(set) var manualReference: ManualPlaceReference?
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "lastPlace.enabled")
    @Published private(set) var status = "开启后，记录收到信号时手机的位置参考"
    @Published private(set) var reducedAccuracy = false
    @Published private(set) var authorizationDenied = false
    @Published private(set) var automaticPaused = false
    private let manager = CLLocationManager()
    private var deviceID = ""
    private var seeking = false
    private var trackingStarted: Date?
    private var window = PhoneLocationWindow()
    private var signal: (time: Date, rssi: Int, source: String)?
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
        stopTracking()
        deviceID = value; signal = nil; lastPlace = nil; manualReference = nil
        automaticPaused = UserDefaults.standard.bool(forKey: key + ".paused")
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(LastPlaceRecord.self, from: data),
           saved.deviceID == value, saved.isValid { lastPlace = saved }
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key + ".manual"),
           let saved = try? JSONDecoder().decode(ManualPlaceReference.self, from: data), saved.belongs(to: value) {
            manualReference = saved
        }
        preserveLegacyAlignment()
        updateTracking()
    }
    private func preserveLegacyAlignment() {
        // Preserve a valid previous confirmation as a separate historical reference.
        // Never carry a local offset over to new GPS samples or silently expire it.
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
        if !active { signal = nil; stopTracking() }
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
        lastPlace = nil; manualReference = nil; signal = nil; automaticPaused = false
        stopTracking()
        if !deviceID.isEmpty {
            for suffix in ["", ".manual", ".alignment", ".paused"] { UserDefaults.standard.removeObject(forKey: key + suffix) }
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
            status = "等待新定位：报告不确定范围需 ≤20 米，连续稳定至少 6 秒"
            manager.startUpdatingLocation()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateTracking() }
    func observeSignal(rssi: Int, source: String, at time: Date) {
        guard seeking, !deviceID.isEmpty, (-126 ... -1).contains(rssi) else { return }
        signal = (time, rssi, source)
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
        guard let location = window.stable(at: now, minimumDuration: duration) else {
            if !window.samples.isEmpty {
                status = duration > 6 ? "新位置与旧记录差距较大，需稳定 20 秒再更新" : "正在积累稳定定位（至少 5 个样本、跨度 6 秒）"
            }
            return
        }
        guard LastPlacePolicy.canAssociate(locationTime: location.time, accuracy: location.accuracy,
            signalTime: signal.time, at: now) else { return }
        if let old = lastPlace, old.signalTime >= signal.time { return }
        let record = LastPlaceRecord(deviceID: deviceID, latitude: location.latitude, longitude: location.longitude,
            accuracy: location.accuracy, locationTime: location.time, signalTime: signal.time,
            rssi: signal.rssi, source: signal.source, qualityVersion: 3)
        guard record.isValid else { return }
        lastPlace = record
        if let data = try? JSONEncoder().encode(record) { UserDefaults.standard.set(data, forKey: key) }
        status = "已保存近期稳定的手机位置；系统不确定范围不是准确性保证"
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
    var calibrationReference: LastPlaceRecord? {
        if let signal, (0...8).contains(Date().timeIntervalSince(signal.time)) {
            let fix = window.stable(at: Date())
            return LastPlaceRecord(deviceID: deviceID, latitude: fix?.latitude ?? lastPlace?.latitude ?? 0,
                longitude: fix?.longitude ?? lastPlace?.longitude ?? 0, accuracy: fix?.accuracy ?? 10000,
                locationTime: min(fix?.time ?? signal.time, signal.time), signalTime: signal.time,
                rssi: signal.rssi, source: signal.source, qualityVersion: 3)
        }
        if let manualReference { return displayRecord(manualReference) }
        return lastPlace
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
        saveManual(ref)
        status = "手动参考已保存；不会过期或被自动定位覆盖，不表示实时设备位置"
        return true
    }
    private func saveManual(_ reference: ManualPlaceReference) {
        manualReference = reference
        if let data = try? JSONEncoder().encode(reference) { UserDefaults.standard.set(data, forKey: key + ".manual") }
    }
    func resetMapCalibration() {
        manualReference = nil
        UserDefaults.standard.removeObject(forKey: key + ".manual")
        UserDefaults.standard.removeObject(forKey: key + ".alignment")
        status = "手动参考已撤销；原始自动定位记录保持不变"
    }
    func displayRecord(_ reference: ManualPlaceReference) -> LastPlaceRecord {
        LastPlaceRecord(deviceID: reference.deviceID, latitude: reference.latitude, longitude: reference.longitude,
            accuracy: 0, locationTime: reference.signalTime, signalTime: reference.signalTime,
            rssi: reference.rssi, source: reference.source, qualityVersion: 3)
    }
    func openMap(manual: Bool = false) {
        let place: LastPlaceRecord?
        if manual, let reference = manualReference { place = displayRecord(reference) } else { place = lastPlace }
        guard let place else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = manual ? "手动确认的手机位置参考" : "收到物品信号时的手机位置（非物品坐标）"
        item.openInMaps(launchOptions: nil)
    }
}
