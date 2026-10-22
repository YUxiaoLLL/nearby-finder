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
    var id: String { deviceID }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(coordinate) && latitude.isFinite && longitude.isFinite
            && accuracy.isFinite && (0...10000).contains(accuracy) && (-126 ... -1).contains(rssi)
    }
}

/// Stores the PHONE's position at a contemporaneous valid watch signal, never the watch's GPS.
final class LastPlaceController: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var lastPlace: LastPlaceRecord?
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "lastPlace.enabled")
    @Published private(set) var status = "开启后，记录收到信号时手机的大概位置"
    @Published private(set) var reducedAccuracy = false
    @Published private(set) var alignment: LocalMapAlignment?
    private var fixes: [CLLocation] = []
    @Published private(set) var authorizationDenied = false
    private let manager = CLLocationManager()
    private var deviceID = ""
    private var seeking = false
    private var latestLocation: CLLocation?
    private var signal: (time: Date, rssi: Int, source: String)?
    private var key: String { "lastPlace.record.\(deviceID)" }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = true
    }
    func setDevice(_ id: UUID?) {
        let value = id?.uuidString ?? ""
        guard deviceID != value else { return }
        deviceID = value; signal = nil; latestLocation = nil; lastPlace = nil; fixes = []
        alignment = UserDefaults.standard.data(forKey: key + ".alignment").flatMap { try? JSONDecoder().decode(LocalMapAlignment.self, from: $0) }
        if !value.isEmpty, let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(LastPlaceRecord.self, from: data),
           saved.deviceID == value, saved.isValid { lastPlace = saved }
        updateTracking()
    }
    func setSeeking(_ active: Bool) {
        seeking = active
        if !active { signal = nil; latestLocation = nil; fixes = [] }
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
        signal = nil; latestLocation = nil; updateTracking()
    }
    func clear() {
        lastPlace = nil; signal = nil
        if !deviceID.isEmpty { UserDefaults.standard.removeObject(forKey: key) }
        status = "此手表的位置记录已删除"
    }
    private func updateTracking() {
        let auth = manager.authorizationStatus
        reducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        authorizationDenied = auth == .denied || auth == .restricted
        guard enabled else { manager.stopUpdatingLocation(); status = "位置记录已关闭"; return }
        guard auth == .authorizedWhenInUse || auth == .authorizedAlways else {
            manager.stopUpdatingLocation()
            status = authorizationDenied ? "定位未授权，可在 iPhone 设置中开启；寻表和响铃仍可使用" : "等待定位授权"
            return
        }
        guard seeking, !deviceID.isEmpty else { manager.stopUpdatingLocation(); status = "等待前台寻找并收到手表信号"; return }
        status = reducedAccuracy ? "请开启精确位置；大概位置不再保存为寻找标记" : "正在检查定位精度与连续样本，误差需在 50 米内"
        manager.startUpdatingLocation()
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateTracking() }
    func observeSignal(rssi: Int, source: String, at time: Date) {
        guard enabled, seeking, !deviceID.isEmpty else { return }
        signal = (time, rssi, source)
        if let latestLocation { saveIfContemporaneous(latestLocation, at: time) }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard enabled, seeking, !deviceID.isEmpty else { return }
        let now = Date()
        guard let fix = locations.filter({
            CLLocationCoordinate2DIsValid($0.coordinate) && $0.horizontalAccuracy >= 0
                && (0...10).contains(now.timeIntervalSince($0.timestamp))
        }).max(by: { $0.timestamp < $1.timestamp }) else { return }
        guard !reducedAccuracy, fix.horizontalAccuracy <= 50 else {
            status = "定位精度不足（约 ±\(Int(ceil(fix.horizontalAccuracy))) 米），保留旧记录；请开启精确位置或到窗边重试"
            latestLocation = nil; fixes = []; return
        }
        if let previous = fixes.last, fix.timestamp <= previous.timestamp { return }
        if let previous = fixes.last, fix.distance(from: previous) > max(40, fix.horizontalAccuracy + previous.horizontalAccuracy) {
            fixes = []; latestLocation = nil; status = "检测到定位跳动，等待稳定后再记录"
        }
        fixes.append(fix); fixes = Array(fixes.filter { now.timeIntervalSince($0.timestamp) <= 10 }.suffix(5))
        guard fixes.count >= 3, let first = fixes.first, fix.timestamp.timeIntervalSince(first.timestamp) >= 2 else { return }
        latestLocation = fix
        saveIfContemporaneous(fix, at: now)
    }
    private func saveIfContemporaneous(_ location: CLLocation, at now: Date) {
        guard let signal, LastPlacePolicy.canAssociate(locationTime: location.timestamp,
            accuracy: location.horizontalAccuracy, signalTime: signal.time, at: now) else { return }
        guard manager.accuracyAuthorization == .fullAccuracy else { return }
        if let lastPlace {
            if lastPlace.signalTime > signal.time { return }
            if now.timeIntervalSince(lastPlace.signalTime) < 20,
               location.horizontalAccuracy > max(20, lastPlace.accuracy * 2) { return }
        }
        let record = LastPlaceRecord(deviceID: deviceID, latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy,
            locationTime: location.timestamp, signalTime: signal.time, rssi: signal.rssi, source: signal.source, qualityVersion: 2)
        guard record.isValid else { return }
        lastPlace = record
        if let data = try? JSONEncoder().encode(record) { UserDefaults.standard.set(data, forKey: key) }
        status = "已保存收到信号时手机的位置"
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard enabled, seeking else { return }
        status = "暂未取得可用位置，保留已有记录；室内可到窗边重试"
    }
    func improveLocation() {
        fixes = []; latestLocation = nil
        enable()
        if (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways), manager.accuracyAuthorization == .reducedAccuracy {
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "FindWatchLocation") { [weak self] _ in
                DispatchQueue.main.async { self?.updateTracking() }
            }
        } else { updateTracking() }
    }
    func displayCoordinate(for place: LastPlaceRecord) -> CLLocationCoordinate2D {
        guard let alignment, alignment.applies(latitude: place.latitude, longitude: place.longitude, at: Date()) else { return place.coordinate }
        return CLLocationCoordinate2D(latitude: place.latitude + alignment.mapLatitude - alignment.latitude,
                                      longitude: place.longitude + alignment.mapLongitude - alignment.longitude)
    }
    func aligned(_ place: LastPlaceRecord) -> Bool {
        alignment?.applies(latitude: place.latitude, longitude: place.longitude, at: Date()) ?? false
    }
    func calibrateMap(_ place: LastPlaceRecord, selected: CLLocationCoordinate2D) -> Bool {
        guard let signal, Date().timeIntervalSince(signal.time) < 8,
              let live = latestLocation, Date().timeIntervalSince(live.timestamp) < 10,
              live.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude)) < 30,
              place.deviceID == deviceID, place.qualityVersion == 2,
              CLLocationCoordinate2DIsValid(selected),
              CLLocation(latitude: place.latitude, longitude: place.longitude).distance(from: CLLocation(latitude: selected.latitude, longitude: selected.longitude)) <= 1500 else {
            status = "请保持原地、持续收到信号并取得精确位置后再校准；所选偏移需在 1.5 公里内"; return false
        }
        alignment = LocalMapAlignment(latitude: place.latitude, longitude: place.longitude,
            mapLatitude: selected.latitude, mapLongitude: selected.longitude, time: Date())
        if let data = try? JSONEncoder().encode(alignment) { UserDefaults.standard.set(data, forKey: key + ".alignment") }
        status = "已按你确认的位置对齐地图；仅对附近 1 公里、24 小时内有效"
        return true
    }
    func resetMapCalibration() {
        alignment = nil; UserDefaults.standard.removeObject(forKey: key + ".alignment")
        status = "已恢复原始坐标显示"
    }
    func openMap() {
        guard let place = lastPlace else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: displayCoordinate(for: place)))
        item.name = "收到 Suunto 信号时的手机位置"
        item.openInMaps(launchOptions: nil)
    }
}
