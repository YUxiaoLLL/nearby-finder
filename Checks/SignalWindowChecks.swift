import Foundation

func checkSignalWindow() {
    let t = Date(timeIntervalSince1970:1000)
    var s = SignalWindow()
    assert(!s.add(127,source:"广播",at:t))
    assert(!s.add(0,source:"广播",at:t))
    assert(s.value(at:t) == nil)
    for i in 0..<5 { assert(s.add(-80,source:"广播",at:t.addingTimeInterval(Double(i)))) }
    for i in 5..<10 { assert(s.add(-60,source:"广播",at:t.addingTimeInterval(Double(i)))) }
    assert(s.value(at:t.addingTimeInterval(10)) == -60)
    assert(s.trend(at:t.addingTimeInterval(10)).contains("增强"))
    assert(s.value(at:t.addingTimeInterval(18)) == nil)
    assert(s.add(-45,source:"连接后 readRSSI",at:t.addingTimeInterval(19)))
    assert(s.samples.count == 1) // sources are never mixed for a trend
    assert(s.trend(at:t.addingTimeInterval(19)).contains("积累"))
    var history = SignalWindow()
    for i in 0..<25 { _ = history.add(i < 15 ? -80 : -60, source: "广播", at: t.addingTimeInterval(Double(i))) }
    assert(history.value(at: t.addingTimeInterval(5)) == -80) // no future samples in chart
    assert(history.delta(at: t.addingTimeInterval(24)) == 20)
    assert(history.delta(at: t.addingTimeInterval(33)) == nil)
    var falling = SignalWindow()
    var noisy = SignalWindow()
    for i in 0..<20 {
        _ = falling.add(i < 13 ? -55 : -80, source: "广播", at: t.addingTimeInterval(Double(i)))
        _ = noisy.add(i == 19 ? -30 : -75, source: "广播", at: t.addingTimeInterval(Double(i)))
    }
    assert(falling.delta(at: t.addingTimeInterval(19)) == -25)
    assert(falling.trend(at: t.addingTimeInterval(19)).contains("减弱"))
    assert(noisy.delta(at: t.addingTimeInterval(19)) == 0)
    assert(noisy.value(at: t.addingTimeInterval(19)) == -75)
    var burst = SignalWindow()
    for i in 0..<100 { _ = burst.add(-50, source: "广播", at: t.addingTimeInterval(Double(i) / 100)) }
    assert(burst.delta(at: t.addingTimeInterval(1)) == nil)
    for i in 25..<100 { _ = history.add(-70, source: "广播", at: t.addingTimeInterval(Double(i))) }
    assert(history.samples.count <= 61)
    s.reset()
    assert(s.last == nil)
    print("PASS: invalid RSSI, median, rising/falling/noisy trends, stale signal, source isolation, historical smoothing, burst rejection, 60s retention, reset")
}
checkSignalWindow()

func checkCloseRangeGate() {
    let start = Date(timeIntervalSince1970: 2000)
    var gate = CloseRangeGate()
    for second in 0..<5 {
        let now = start.addingTimeInterval(Double(second))
        assert(!gate.update(value: -60, sampleTime: now, threshold: -65, at: now))
    }
    let entered = start.addingTimeInterval(5)
    assert(gate.update(value: -60, sampleTime: entered, threshold: -65, at: entered))
    let smallDip = start.addingTimeInterval(6)
    assert(gate.update(value: -68, sampleTime: smallDip, threshold: -65, at: smallDip))
    let outside = start.addingTimeInterval(7)
    assert(!gate.update(value: -71, sampleTime: outside, threshold: -65, at: outside))
    for second in 8...13 {
        let now = start.addingTimeInterval(Double(second))
        _ = gate.update(value: -60, sampleTime: now, threshold: -65, at: now)
    }
    assert(gate.inside)
    assert(!gate.update(value: -60, sampleTime: start.addingTimeInterval(13), threshold: -65, at: start.addingTimeInterval(16)))
    // One sample cannot establish a five-second dwell just by reusing it.
    gate.reset()
    assert(!gate.update(value: -60, sampleTime: start, threshold: -65, at: start))
    assert(!gate.update(value: -60, sampleTime: start, threshold: -65, at: start.addingTimeInterval(5)))
    // A gap restarts the dwell.
    assert(!gate.update(value: -60, sampleTime: start.addingTimeInterval(10), threshold: -65, at: start.addingTimeInterval(10)))
    assert(!gate.update(value: nil, sampleTime: nil, threshold: -65, at: start.addingTimeInterval(11)))
    print("PASS: near-zone dwell, hysteresis, stale exit, repeated-sample rejection, interrupted samples")
}
checkCloseRangeGate()

func checkLastPlaceAssociation() {
    let t = Date(timeIntervalSince1970: 3000)
    func accepted(locationOffset: Double, signalOffset: Double = 0, nowOffset: Double = 0, accuracy: Double = 12) -> Bool {
        LastPlacePolicy.canAssociate(locationTime: t.addingTimeInterval(locationOffset), accuracy: accuracy,
            signalTime: t.addingTimeInterval(signalOffset), at: t.addingTimeInterval(nowOffset))
    }
    assert(accepted(locationOffset: -2))
    assert(!accepted(locationOffset: -5, accuracy: 5000)) // coarse fixes no longer become precise-looking pins
    assert(accepted(locationOffset: -1, accuracy: 20))
    assert(!accepted(locationOffset: -1, accuracy: 21))
    assert(!accepted(locationOffset: -9)) // don't associate an old phone location
    assert(!accepted(locationOffset: 1, nowOffset: 1)) // phone moved AFTER final signal
    assert(!accepted(locationOffset: 0, nowOffset: 9)) // delayed callbacks cannot revive a stale sighting
    assert(!accepted(locationOffset: 0, accuracy: -1))
    assert(!accepted(locationOffset: 0, accuracy: .infinity))
    assert(!accepted(locationOffset: 0, accuracy: 10001))
    assert(!accepted(locationOffset: 0, signalOffset: 1)) // no future sightings
    let offsets = WatchRingPlan.delays
    assert(offsets.count == 4 && offsets.first == 5 && offsets.last == 20)
    assert(zip(offsets, offsets.dropFirst()).allSatisfy { $1 - $0 == 5 })
    print("PASS: contemporaneous location, stale/after-signal rejection, strict accuracy, invalid fixes, four-ring timing contract")
}
checkLastPlaceAssociation()


func checkAlignment() {
    let t = Date(timeIntervalSince1970: 4000)
    let a = LocalMapAlignment(latitude: 23.15, longitude: 113.35, mapLatitude: 23.152, mapLongitude: 113.354, time: t)
    assert(a.applies(latitude: 23.151, longitude: 113.351, at: t.addingTimeInterval(10)))
    assert(!a.applies(latitude: 24.15, longitude: 113.35, at: t))
    assert(!a.applies(latitude: 23.15, longitude: 113.35, at: t.addingTimeInterval(86401)))
    assert(!a.applies(latitude: 23.15, longitude: 113.35, at: t.addingTimeInterval(-1)))
    print("PASS: local alignment region/expiry")
}
checkAlignment()

func checkSignalGuidance() {
    let t = Date(timeIntervalSince1970: 5000)
    let controller = SignalGuideController()
    controller.setDevice(UUID())
    func window(_ rssi: Int, _ source: String, _ offset: Double) -> SignalWindow {
        var signal = SignalWindow()
        for i in 0...12 { _ = signal.add(rssi, source: source, at: t.addingTimeInterval(offset + Double(i))) }
        return signal
    }
    let a = window(-50, "A", 0)
    controller.update(a, at: t.addingTimeInterval(12), running: true)
    assert(controller.headline == "信号较强")
    assert(!controller.headline.contains("米"))
    let veryStrong = window(-30, "A", 20)
    controller.update(veryStrong, at: t.addingTimeInterval(32), running: true)
    assert(controller.headline == "信号较强") // no fabricated 0.2m / 1m floor
    let medium = window(-70, "A", 40)
    controller.update(medium, at: t.addingTimeInterval(52), running: true)
    assert(controller.headline == "信号适中")
    let weak = window(-90, "A", 60)
    controller.update(weak, at: t.addingTimeInterval(72), running: true)
    assert(controller.headline == "信号较弱")
    controller.recordRoute("起点", signal: weak, at: t.addingTimeInterval(72))
    let left = window(-65, "A", 80)
    controller.recordRoute("左侧", signal: left, at: t.addingTimeInterval(92))
    assert(controller.routeAdvice.contains("左侧"))
    controller.recordRoute("右侧", signal: left, at: t.addingTimeInterval(92))
    assert(controller.routeReadings["右侧"] == nil)
    controller.update(left, at: t.addingTimeInterval(100), running: true)
    assert(controller.headline == "等待信号")
    let changed = window(-60, "B", 110)
    controller.update(changed, at: t.addingTimeInterval(122), running: true)
    assert(controller.routeReadings.isEmpty)
    controller.update(changed, at: t.addingTimeInterval(122), running: false)
    assert(controller.headline == "等待信号")
    print("PASS: signal-only labels, no meter output, route comparison, source isolation, stale/stopped display")
}
checkSignalGuidance()

func checkDeviceLibrary() {
    let suite = "FinderChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = UUID(), second = UUID()
    defaults.set(first.uuidString, forKey: "targetID")
    defaults.set("Same Name", forKey: "targetName")
    defaults.set(Date(timeIntervalSince1970: 1000), forKey: "lastSeen")
    let library = DeviceLibrary(defaults: defaults)
    assert(library.devices.count == 1)
    assert(library.item(first)?.lastSeen != nil)
    assert(library.item(first)?.notificationSupport == .untested)
    library.save(SavedDevice(id: second, advertisedName: "Same Name", nickname: "Desk Headphones", kind: .headphones, storageNote: "Drawer"))
    assert(library.devices.count == 2) // matching names must not merge identities
    library.observe(id: second, name: "Changed BLE Name", services: ["180A"])
    assert(library.item(second)?.displayName == "Desk Headphones")
    assert(library.item(second)?.storageNote == "Drawer")
    assert(library.item(second)?.notificationSupport == .untested)
    library.recordSignal(id: second, source: "广播", at: Date(timeIntervalSince1970: 2000))
    assert(library.item(first)?.lastSeen == Date(timeIntervalSince1970: 1000))
    let restored = DeviceLibrary(defaults: defaults)
    assert(restored.item(second)?.lastSeen == Date(timeIntervalSince1970: 2000))
    restored.remove(second)
    assert(restored.item(first) != nil && restored.item(second) == nil)
    assert(!TargetMatchPolicy.matches(id: second, selected: nil, name: "Anything", hint: ""))
    assert(!TargetMatchPolicy.matches(id: second, selected: first, name: "My serial 123", hint: "123"))
    assert(TargetMatchPolicy.matches(id: first, selected: first, name: "New Name", hint: ""))
    assert(TargetMatchPolicy.matches(id: first, selected: nil, name: "Suunto 123", hint: " 123 "))
    print("PASS: legacy migration, device identity, metadata preservation, per-device last seen, persistence/removal, no empty-hint capture")
}
checkDeviceLibrary()

func checkLocationEvidence() {
    let t = Date(timeIntervalSince1970: 9000)
    var window = PhoneLocationWindow()
    func fix(_ offset: Double, lat: Double = 40, lon: Double = -75, accuracy: Double = 12) -> PhoneLocationFix {
        PhoneLocationFix(latitude: lat, longitude: lon, accuracy: accuracy, time: t.addingTimeInterval(offset))
    }
    for i in 0...6 {
        let now = t.addingTimeInterval(Double(i))
        assert(window.add(fix(Double(i)), sessionStarted: t, at: now))
        if i < 6 { assert(window.stable(at: now) == nil) }
    }
    assert(window.stable(at: t.addingTimeInterval(6))?.accuracy == 12)
    assert(window.stable(at: t.addingTimeInterval(10)) == nil)
    assert(!window.add(fix(6), sessionStarted: t, at: t.addingTimeInterval(6)))
    assert(window.add(fix(7, lat: 40.01), sessionStarted: t, at: t.addingTimeInterval(7)))
    assert(window.rejectedJump && window.samples.count == 1)
    assert(window.stable(at: t.addingTimeInterval(7)) == nil)
    assert(!window.add(fix(8, accuracy: 21), sessionStarted: t, at: t.addingTimeInterval(8)))
    assert(window.samples.isEmpty)
    assert(!window.add(fix(-1), sessionStarted: t, at: t))
    assert(!window.add(fix(1), sessionStarted: t, at: t))
    assert(!window.add(fix(0), sessionStarted: t, at: t.addingTimeInterval(4)))
    assert(!window.add(fix(0, lat: .nan), sessionStarted: t, at: t))
    assert(!window.add(fix(0, lon: 181), sessionStarted: t, at: t))
    assert(!window.add(fix(0, accuracy: 0), sessionStarted: t, at: t))
    window.reset()
    for i in 0...4 { _ = window.add(fix(Double(i)), sessionStarted: t, at: t.addingTimeInterval(Double(i))) }
    _ = window.add(fix(10), sessionStarted: t, at: t.addingTimeInterval(10))
    assert(window.samples.count == 1) // a sampling interruption restarts the dwell
    window.reset()
    for i in 0...20 { _ = window.add(fix(Double(i)), sessionStarted: t, at: t.addingTimeInterval(Double(i))) }
    assert(window.stable(at: t.addingTimeInterval(20), minimumDuration: 20) != nil)

    let manual = ManualPlaceReference(deviceID: "one", latitude: 40, longitude: -75,
        signalTime: t, rssi: -60, source: "test", confirmedAt: t.addingTimeInterval(600), note: "Office, third floor")
    let restored = try! JSONDecoder().decode(ManualPlaceReference.self, from: JSONEncoder().encode(manual))
    assert(restored.belongs(to: "one") && !restored.belongs(to: "two"))
    assert(restored.note == manual.note && restored.signalTime == t)
    // Confirmation has no automatic expiration and cannot overwrite automatic GPS storage.
    assert(restored.confirmedAt == t.addingTimeInterval(600))
    let invalid = ManualPlaceReference(deviceID: "one", latitude: 91, longitude: -75,
        signalTime: t, rssi: -60, source: "test", confirmedAt: t, note: "")
    assert(!invalid.isValid)
    let futureSignal = ManualPlaceReference(deviceID: "one", latitude: 40, longitude: -75,
        signalTime: t.addingTimeInterval(1), rssi: -60, source: "test", confirmedAt: t, note: "")
    assert(!futureSignal.isValid)

    let legacy = "{\"id\":\"11111111-1111-1111-1111-111111111111\",\"advertisedName\":\"Old\",\"nickname\":\"Old\",\"kind\":\"耳机\",\"storageNote\":\"\",\"notificationSupport\":\"未验证\",\"services\":[],\"lastSource\":\"未知\"}"
    assert((try! JSONDecoder().decode(SavedDevice.self, from: Data(legacy.utf8))).kind == .headphones)
    for kind in [DeviceKind.stylus, .mouse, .keyboard] {
        let device = SavedDevice(id: UUID(), advertisedName: "Test", nickname: "Test", kind: kind)
        assert((try! JSONDecoder().decode(SavedDevice.self, from: JSONEncoder().encode(device))).kind == kind)
    }
    assert(DeviceKind.suggested(for: "Apple Pencil") == .stylus)
    assert(DeviceKind.suggested(for: "Bluetooth Keyboard") == .keyboard)
    assert(DeviceKind.suggested(for: "Mouse") == .mouse)
    print("PASS: fresh session fixes, stable location dwell, jumps/gaps/stale/future/invalid rejection, persistent manual reference identity and categories migration")
}
checkLocationEvidence()

func checkSignalContextWithoutGPS() {
    let t = Date(timeIntervalSince1970: 10000)
    let evidence = PlaceSignalEvidence(deviceID: "one", time: t, rssi: -70, source: "test")
    var history = PlaceSignalHistory()
    assert(history.observe(evidence, deviceID: "one"))
    history.stopLive()
    assert(history.live == nil && history.latest?.time == t)
    let saved = try! JSONEncoder().encode(history.latest!)
    let decoded = try! JSONDecoder().decode(PlaceSignalEvidence.self, from: saved)
    let restored = PlaceSignalHistory(restored: decoded, deviceID: "one")
    assert(restored.live == nil && restored.latest?.time == t)
    assert(PlaceSignalHistory(restored: decoded, deviceID: "two").latest == nil)
    assert(!history.observe(evidence, deviceID: "two"))
    assert(!history.observe(PlaceSignalEvidence(deviceID: "one", time: t.addingTimeInterval(-1), rssi: -60, source: "test"), deviceID: "one"))
    print("PASS: manual-confirmation signal context survives pause/restart without GPS; device isolation and older-event rejection")
}
checkSignalContextWithoutGPS()

func checkAutomaticDisplayAlignment() {
    let t = Date(timeIntervalSince1970: 12000)
    var window = PhoneLocationWindow()
    let first = PhoneLocationFix(latitude: 23, longitude: 113, accuracy: 15, time: t)
    assert(window.add(first, sessionStarted: t, at: t))
    assert(window.candidate(at: t)?.latitude == 23) // first fresh fix need not wait for five callbacks
    assert(window.candidate(at: t.addingTimeInterval(4)) == nil)
    let jump = PhoneLocationFix(latitude: 23.01, longitude: 113, accuracy: 15, time: t.addingTimeInterval(1))
    assert(window.add(jump, sessionStarted: t, at: jump.time))
    assert(window.candidate(at: jump.time) == nil)
    let next = PhoneLocationFix(latitude: 23.01, longitude: 113, accuracy: 15, time: t.addingTimeInterval(2))
    assert(window.add(next, sessionStarted: t, at: next.time))
    assert(window.candidate(at: next.time) == nil) // jump protection survives another callback
    let alignment = PlaceDisplayAlignment(deviceID: "watch", latitude: 23, longitude: 113,
        targetLatitude: 23.001, targetLongitude: 113.002)
    let restored = try! JSONDecoder().decode(PlaceDisplayAlignment.self, from: JSONEncoder().encode(alignment))
    let point = restored.corrected(deviceID: "watch", latitude: 23.0001, longitude: 113.0001)!
    assert(abs(point.0 - 23.0011) < 0.000001 && abs(point.1 - 113.0021) < 0.000001)
    assert(restored.corrected(deviceID: "other", latitude: 23, longitude: 113) == nil)
    assert(restored.corrected(deviceID: "watch", latitude: 24, longitude: 113) == nil)
    assert(restored.corrected(deviceID: "watch", latitude: .nan, longitude: 113) == nil)
    print("PASS: immediate fresh automatic fixes, persistent jump protection, local correction persistence/movement/device isolation")
}
checkAutomaticDisplayAlignment()

func checkSystemMapBridge() {
    let t = Date(timeIntervalSince1970: 20000)
    let phone = PhoneLocationFix(latitude: 23, longitude: 113, accuracy: 8, time: t)
    let map = PhoneLocationFix(latitude: 22.9975, longitude: 113.005, accuracy: 8, time: t)
    let bridge = SystemMapBridge.pair(phone: phone, map: map, at: t)!
    let restored = try! JSONDecoder().decode(SystemMapBridge.self, from: JSONEncoder().encode(bridge))
    let point = restored.coordinate(latitude: 23.0001, longitude: 113.0001, at: t.addingTimeInterval(10))!
    assert(abs(point.0 - 22.9976) < 0.0000001 && abs(point.1 - 113.0051) < 0.0000001)
    assert(phone.latitude == 23 && phone.longitude == 113) // raw source remains unchanged
    assert(bridge.coordinate(latitude: 24, longitude: 113, at: t) == nil)
    assert(bridge.coordinate(latitude: 23, longitude: 113, at: t.addingTimeInterval(3601)) == nil)
    let late = PhoneLocationFix(latitude: map.latitude, longitude: map.longitude, accuracy: 8, time: t.addingTimeInterval(2))
    assert(SystemMapBridge.pair(phone: phone, map: late, at: late.time) == nil)
    assert(SystemMapBridge.pair(phone: phone, map: map, at: t.addingTimeInterval(11)) == nil)
    let coarse = PhoneLocationFix(latitude: map.latitude, longitude: map.longitude, accuracy: 100, time: t)
    assert(SystemMapBridge.pair(phone: phone, map: coarse, at: t) == nil)
    let identity = SystemMapBridge.pair(phone: phone, map: phone, at: t)!
    assert(identity.offset == 0 && identity.coordinate(latitude: 23, longitude: 113, at: t)!.0 == 23)
    print("PASS: paired system-map provenance, matching time/accuracy, raw preservation, identity mapping, regional/age limits")
}
checkSystemMapBridge()

func checkPredictiveMapTimestamp() {
    let t = Date(timeIntervalSince1970: 30000)
    let phone = PhoneLocationFix(latitude: 23, longitude: 113, accuracy: 8, time: t)
    let predictive = PhoneLocationFix(latitude: 22.9975, longitude: 113.005, accuracy: 8, time: t.addingTimeInterval(1.1))
    assert(SystemMapBridge.canQueue(predictive, at: t))
    assert(SystemMapBridge.pair(phone: phone, map: predictive, at: t) == nil)
    let nextPhone = PhoneLocationFix(latitude: 23, longitude: 113, accuracy: 8, time: t.addingTimeInterval(1))
    assert(SystemMapBridge.pair(phone: nextPhone, map: predictive, at: t.addingTimeInterval(1.2)) != nil)
    let future = PhoneLocationFix(latitude: 23, longitude: 113, accuracy: 8, time: t.addingTimeInterval(3))
    assert(!SystemMapBridge.canQueue(future, at: t))
    assert(!SystemMapBridge.canQueue(phone, at: t.addingTimeInterval(21)))
    print("PASS: predictive MapKit callbacks are queued, never paired before their timestamp, then matched to a contemporaneous phone fix")
}
checkPredictiveMapTimestamp()
