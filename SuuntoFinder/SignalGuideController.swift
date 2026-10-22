import Foundation
import Combine

/// Signal guidance only: no RSSI-to-meter conversion or assumed physical radius.
final class SignalGuideController: ObservableObject {
    @Published private(set) var headline = "等待信号"
    @Published private(set) var detail = "信号强度不能直接换算成米数"
    @Published private(set) var routeReadings: [String: Int] = [:]
    @Published private(set) var routeAdvice = "先记录起点，再沿不同路线移动、停下采样"
    private var device = ""
    private var source = ""
    private var lastRouteTime: Date?
    func setDevice(_ id: UUID?) {
        let next = id?.uuidString ?? ""
        guard next != device else { return }
        device = next; source = ""; resetRoutes()
        headline = "等待信号"
    }
    func resetRoutes() {
        routeReadings = [:]; lastRouteTime = nil
        routeAdvice = "先记录起点，再沿不同路线移动、停下采样"
    }
    func update(_ signal: SignalWindow, at now: Date, running: Bool) {
        if source != signal.source { source = signal.source; resetRoutes() }
        guard running, let value = signal.value(at: now) else {
            headline = "等待信号"; detail = "暂无实时信号，不能比较当前强弱"; return
        }
        headline = value >= -60 ? "信号较强" : value >= -80 ? "信号适中" : "信号较弱"
        detail = "强弱分级只描述蓝牙信号，不代表距离；请结合移动趋势和响铃寻找"
    }
    private func stable(_ signal: SignalWindow, at now: Date) -> (Int, Date)? {
        let samples = signal.samples.filter { (0..<12).contains(now.timeIntervalSince($0.time)) }
        guard let first = samples.first, let last = samples.last, samples.count >= 8,
              last.time.timeIntervalSince(first.time) >= 7, now.timeIntervalSince(last.time) < 3,
              zip(samples, samples.dropFirst()).allSatisfy({ $1.time.timeIntervalSince($0.time) <= 3 }),
              let value = signal.median(samples.map(\.rssi)),
              let spread = signal.median(samples.map { abs($0.rssi - value) }), spread <= 5 else { return nil }
        return (value, last.time)
    }
    func recordRoute(_ route: String, signal: SignalWindow, at now: Date) {
        guard signal.source == source, let (value, time) = stable(signal, at: now) else {
            routeAdvice = "请先沿该路线走几步，再停下等待 12 秒稳定信号"; return
        }
        if let lastRouteTime, time.timeIntervalSince(lastRouteTime) < 12 {
            routeAdvice = "请完成移动并等待至少 12 秒，再记录下一个采样点"; return
        }
        if route == "起点" { routeReadings = [:] }
        guard route == "起点" || routeReadings["起点"] != nil else { routeAdvice = "先记录起点"; return }
        routeReadings[route] = value; lastRouteTime = time
        guard let baseline = routeReadings["起点"], let best = routeReadings.filter({ $0.key != "起点" }).max(by: { $0.value < $1.value }) else {
            routeAdvice = "起点已记录。每次从起点走向一条路线，停 12 秒记录，再返回起点换路线。"; return
        }
        routeAdvice = best.value - baseline >= 4 ? "\(best.key)路线采样信号最强，优先回到该采样点附近响铃确认" : "目前没有明显强于起点的路线，换路线继续比较"
    }
}
