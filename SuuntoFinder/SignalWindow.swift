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
        accuracy.isFinite && accuracy >= 0 && accuracy <= 50
            && (0...8).contains(now.timeIntervalSince(signalTime))
            && (0...8).contains(signalTime.timeIntervalSince(locationTime))
            && (0...10).contains(now.timeIntervalSince(locationTime))
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
