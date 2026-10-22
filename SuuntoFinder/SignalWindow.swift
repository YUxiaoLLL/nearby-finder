import Foundation

struct SignalWindow {
    struct Sample { let time: Date; let rssi: Int }
    private(set) var samples: [Sample] = []
    private(set) var source = ""
    mutating func reset() { samples = []; source = "" }
    mutating func add(_ rssi: Int, source: String, at now: Date = Date()) -> Bool {
        guard (-126 ... -1).contains(rssi) else { return false }
        if self.source != source { reset(); self.source = source }
        samples.removeAll { now.timeIntervalSince($0.time) > 60 }
        samples.append(Sample(time: now, rssi: rssi))
        return true
    }
    var last: Sample? { samples.last }
    func isFresh(at now: Date) -> Bool { samples.last(where: { $0.time <= now }).map { (0..<8).contains(now.timeIntervalSince($0.time)) } ?? false }
    func median(_ values: [Int]) -> Int? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let n = sorted.count
        return n % 2 == 1 ? sorted[n/2] : (sorted[n/2-1] + sorted[n/2])/2
    }
    func value(at now: Date) -> Int? {
        guard isFresh(at: now) else { return nil }
        return median(samples.filter { (0..<5).contains(now.timeIntervalSince($0.time)) }.map(\.rssi)) ?? samples.last(where: { $0.time <= now })?.rssi
    }
    func delta(at now: Date) -> Int? {
        guard isFresh(at: now) else { return nil }
        let recent = samples.filter { (0..<7).contains(now.timeIntervalSince($0.time)) }
        let prior = samples.filter { (7..<20).contains(now.timeIntervalSince($0.time)) }
        guard recent.count >= 3, prior.count >= 3,
              let first = prior.first, let last = recent.last,
              last.time.timeIntervalSince(first.time) >= 9,
              let a = median(recent.map(\.rssi)), let b = median(prior.map(\.rssi)) else { return nil }
        return a - b
    }
    func trend(at now: Date) -> String {
        guard isFresh(at: now) else { return "暂无实时信号，停下等待重新检测" }
        guard let change = delta(at: now) else { return "缓慢走几步并停下，积累约 20 秒样本" }
        return change >= 4 ? "信号增强，尝试继续沿当前路线寻找" : change <= -4 ? "信号减弱，尝试返回上一处比较" : "信号变化不明显，换一条路线再试"
    }
}

/// A calibrated signal zone, never a distance measurement. Require live, consecutive samples.
struct CloseRangeGate {
    private var since: Date?
    private var previousSample: Date?
    private var count = 0
    private(set) var inside = false
    mutating func reset() { since = nil; previousSample = nil; count = 0; inside = false }
    mutating func update(value: Int?, sampleTime: Date?, threshold: Int, at now: Date) -> Bool {
        guard let value, let sampleTime, (0..<3).contains(now.timeIntervalSince(sampleTime)) else {
            reset(); return false
        }
        if let previousSample, sampleTime.timeIntervalSince(previousSample) > 3 { reset() }
        if inside {
            if value <= threshold - 6 { reset(); return false }
            previousSample = sampleTime
            return true
        }
        guard value >= threshold else { reset(); return false }
        if since == nil { since = sampleTime }
        if previousSample != sampleTime { count += 1 }
        previousSample = sampleTime
        if let since, sampleTime.timeIntervalSince(since) >= 5, count >= 4 { inside = true }
        return inside
    }
}

/// Offsets from the user's tap / entry into the calibrated zone.
enum WatchRingPlan {
    static let delays: [TimeInterval] = [5, 10, 15, 20]
}

/// Pure policy shared by location recording and its tests.
enum LastPlacePolicy {
    static func canAssociate(locationTime: Date, accuracy: Double, signalTime: Date, at now: Date) -> Bool {
        accuracy.isFinite && accuracy > 0 && accuracy <= 20
            && (0...8).contains(now.timeIntervalSince(signalTime))
            && (0...3).contains(signalTime.timeIntervalSince(locationTime))
            && (0...3).contains(now.timeIntervalSince(locationTime))
    }
}

/// User-confirmed local map alignment, NOT an automatic WGS84/GCJ02 conversion.
struct LocalMapAlignment: Codable {
    let latitude: Double
    let longitude: Double
    let mapLatitude: Double
    let mapLongitude: Double
    let time: Date
    func applies(latitude lat: Double, longitude lon: Double, at now: Date) -> Bool {
        let north = (lat - latitude) * 111_320
        let east = (lon - longitude) * 111_320 * cos(latitude * .pi / 180)
        return (0...86400).contains(now.timeIntervalSince(time)) && hypot(north, east) <= 1000
    }
}

/// Coordinate math for quality checks; never converts between map datums.
enum PlaceGeometry {
    static func valid(_ latitude: Double, _ longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let a = lat1 * .pi / 180, b = lat2 * .pi / 180
        let dLat = b - a, dLon = (lon2 - lon1) * .pi / 180
        let h = pow(sin(dLat / 2), 2) + cos(a) * cos(b) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, h))))
    }
}
struct PhoneLocationFix {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let time: Date
}
struct PhoneLocationWindow {
    private(set) var samples: [PhoneLocationFix] = []
    private(set) var rejectedJump = false
    mutating func reset() { samples = []; rejectedJump = false }
    @discardableResult mutating func add(_ fix: PhoneLocationFix, sessionStarted: Date, at now: Date) -> Bool {
        if let last = samples.last, fix.time <= last.time { return false }
        guard PlaceGeometry.valid(fix.latitude, fix.longitude), fix.accuracy.isFinite,
              fix.accuracy > 0, fix.accuracy <= 20, fix.time >= sessionStarted,
              (0...3).contains(now.timeIntervalSince(fix.time)) else {
            reset(); return false
        }
        rejectedJump = false
        if let last = samples.last, fix.time.timeIntervalSince(last.time) > 3 { samples = [] }
        samples = samples.filter { (0...30).contains(now.timeIntervalSince($0.time)) }
        // One outlier invalidates the cluster; several precise-looking samples are not enough.
        if samples.contains(where: { PlaceGeometry.distance($0.latitude, $0.longitude, fix.latitude, fix.longitude) > 20 }) {
            samples = []; rejectedJump = true
        }
        samples.append(fix); samples = Array(samples.suffix(40))
        return true
    }
    func stable(at now: Date, minimumDuration: TimeInterval = 6) -> PhoneLocationFix? {
        guard samples.count >= 5, let first = samples.first, let last = samples.last,
              last.time.timeIntervalSince(first.time) >= minimumDuration,
              (0...3).contains(now.timeIntervalSince(last.time)) else { return nil }
        // Do not claim averaging improved system-reported accuracy.
        let radius = samples.map(\.accuracy).max() ?? last.accuracy
        return PhoneLocationFix(latitude: last.latitude, longitude: last.longitude, accuracy: radius, time: last.time)
    }
}

/// A user-confirmed reference is separate from GPS and never silently expires.
struct ManualPlaceReference: Codable {
    let deviceID: String
    let latitude: Double
    let longitude: Double
    let signalTime: Date
    let rssi: Int
    let source: String
    let confirmedAt: Date
    let note: String
    var isValid: Bool {
        !deviceID.isEmpty && PlaceGeometry.valid(latitude, longitude) && (-126 ... -1).contains(rssi)
            && signalTime <= confirmedAt
    }
    func belongs(to id: String) -> Bool { isValid && deviceID == id }
}

struct PlaceSignalEvidence: Codable {
    let deviceID: String
    let time: Date
    let rssi: Int
    let source: String
    var isValid: Bool {
        !deviceID.isEmpty && time.timeIntervalSinceReferenceDate.isFinite && (-126 ... -1).contains(rssi)
    }
}
/// Stopping live measurement must not erase the historical context for manual confirmation.
struct PlaceSignalHistory {
    private(set) var live: PlaceSignalEvidence?
    private(set) var latest: PlaceSignalEvidence?
    init(restored: PlaceSignalEvidence? = nil, deviceID: String = "") {
        if let restored, restored.isValid, restored.deviceID == deviceID { latest = restored }
    }
    @discardableResult mutating func observe(_ evidence: PlaceSignalEvidence, deviceID: String) -> Bool {
        guard evidence.isValid, evidence.deviceID == deviceID,
              latest == nil || evidence.time >= latest!.time else { return false }
        live = evidence; latest = evidence; return true
    }
    mutating func stopLive() { live = nil }
}
