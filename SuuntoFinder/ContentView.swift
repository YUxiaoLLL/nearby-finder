import SwiftUI
import Charts
import MapKit

struct ContentView: View {
    @ObservedObject var model: FinderModel
    @State private var showGuide = false
    @State private var showLibrary = false
    @State private var showNearby = false
    @State private var showAll = false
    @State private var pending: DeviceRow?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeviceShelfHeader(model: model, library: model.library)
                    Text(model.connection).font(.caption).foregroundStyle(.secondary)
                    GeometryReader { geometry in
                        let diameter = min(280.0, max(160.0, geometry.size.width - 40))
                        ZStack {
                            Circle().stroke(.secondary.opacity(0.15), lineWidth: 18)
                            Circle().trim(from: 0, to: strength)
                                .stroke(.mint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            SignalReadout(controller: model.signalGuide, model: model)
                        }
                        .frame(width: diameter, height: diameter)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                    }.frame(height: 320).frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                    Text(model.trend).font(.headline)
                    Text("缓慢移动，每走几步停一下。信号强度不代表实际距离。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(model.running ? "暂停信号寻找" : "开始寻找") { model.running ? model.stop() : model.start() }
                    if !model.rssiError.isEmpty { Text(model.rssiError).font(.caption).foregroundStyle(.orange) }
                } header: { Text("随手寻 · V0.9（开发版）") }
                Section {
                    Button { showLibrary = true } label: { Label("我的设备", systemImage: "square.grid.2x2") }
                    Button {
                        if !model.running { model.start() }
                        showNearby = true
                    } label: { Label("添加附近设备", systemImage: "plus.circle") }
                }
                WatchSoundSection(controller: model.watchSound, model: model, library: model.library)
                SignalRouteSection(controller: model.signalGuide, model: model)
                LastPlaceSection(controller: model.lastPlace, model: model)
                Section {
                    DisclosureGroup("信号曲线与手机提示") {
                        if model.signal.samples.isEmpty { Text("收到信号后显示曲线").foregroundStyle(.secondary) }
                        else {
                            Chart {
                                ForEach(Array(model.signal.samples.enumerated()), id: \.offset) { _, sample in
                                    PointMark(x: .value("时间", sample.time), y: .value("RSSI", sample.rssi))
                                        .foregroundStyle(.gray.opacity(0.5)).symbolSize(12)
                                    if let value = model.signal.value(at: sample.time) {
                                        LineMark(x: .value("时间", sample.time), y: .value("平滑 RSSI", value)).foregroundStyle(.mint)
                                    }
                                }
                            }.chartXScale(domain: model.now.addingTimeInterval(-60)...model.now)
                                .chartYScale(domain: -127 ... 0).frame(height: 150)
                            Text("过去 60 秒 · 灰点原始值，绿线平滑值").font(.caption).foregroundStyle(.secondary)
                        }
                        Toggle("手机振动提示", isOn: $model.haptics)
                        Toggle("手机声音提示", isOn: $model.sound)
                    }
                    DisclosureGroup("设备设置与诊断") {
                        Toggle("寻找时保持屏幕常亮", isOn: $model.keepAwake)
                        Text(model.bluetooth).font(.caption)
                        TextField("名称匹配提示（选填）", text: $model.serial)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled().disabled(model.running)
                        Button("恢复已登记手表") { model.recoverKnown() }
                        Text(model.status).font(.caption).foregroundStyle(.secondary)
                        Toggle("显示全部 BLE 设备", isOn: $showAll)
                        Text("本 App 扫描重启：\(model.restartCount) 次").font(.caption)
                        Button("重新扫描") { model.restartScan() }.disabled(!model.running)
                        ForEach(visibleRows) { row in
                            Button { pending = row } label: {
                                VStack(alignment: .leading) {
                                    Text(row.name)
                                    Text("\(row.rssi) dBm · \(row.id.uuidString)").font(.caption2)
                                }
                            }.foregroundStyle(.primary)
                        }
                        Button("准备诊断日志") { model.export() }
                        if let url = model.exportedLog {
                            ShareLink(item: url) { Label("分享日志", systemImage: "square.and.arrow.up") }
                        }
                        Text("日志含附近蓝牙设备信息；位置坐标不写入诊断日志。仅在前台扫描及记录位置，已安排的四次通知可在锁屏后继续。")
                            .font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("最近事件") {
                            Text(model.logs.suffix(30).joined(separator: "\n"))
                                .font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("寻找设备")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showGuide = true } label: { Image(systemName: "questionmark.circle") }
                        .accessibilityLabel("寻表使用指引")
                }
            }
            .sheet(isPresented: $showGuide) { FinderGuideView() }
            .onAppear { if !model.running { model.start() } }
            .sheet(isPresented: $showLibrary) { DeviceLibraryView(model: model, library: model.library) }
            .sheet(isPresented: $showNearby) { NearbyDevicesView(model: model) }
            .sheet(item: $pending) { AddDeviceView(model: model, row: $0) }
        }
    }
    private var strength: CGFloat {
        guard let value = model.freshRSSI else { return 0 }
        return CGFloat(min(1, max(0.04, Double(value + 100) / 60)))
    }
    private var visibleRows: [DeviceRow] {
        model.rows.filter { showAll || $0.name.localizedCaseInsensitiveContains("Suunto") || $0.id == model.targetID }
    }
}

private struct WatchSoundSection: View {
    @ObservedObject var controller: WatchSoundController
    @ObservedObject var model: FinderModel
    @ObservedObject var library: DeviceLibrary
    var body: some View {
        Section {
            if model.currentDevice?.kind == .watch {
            if let device = model.currentDevice { Text("通知提醒：\(device.notificationSupport.rawValue)").font(.caption).foregroundStyle(.secondary) }
            Button { controller.ring() } label: {
                Label(controller.isRinging ? "正在提醒 · 剩余约 \(controller.remaining) 秒" : "发送手表通知提醒", systemImage: "speaker.wave.2.fill")
                    .frame(maxWidth: .infinity).padding(8)
            }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                .disabled(controller.isRinging || controller.preparing || (!model.hasSavedTarget && model.targetID == nil))
            Text("第 5、10、15、20 秒各提醒一次，可以锁屏听声寻找。")
                .font(.caption).foregroundStyle(.secondary)
            if controller.isRinging || controller.armed || controller.preparing {
                Button("找到手表了 · 停止提醒", role: .destructive) { controller.stop() }
            }
            if controller.needsPermission { Button("允许通知") { controller.authorizeNotifications() } }
            Text(controller.message).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("信号达标自动响铃") {
                Text("先找一个信号明显增强、你希望自动开始响铃的位置，停 12 秒记录强度。以后寻找时，信号持续达到这个强度便触发响铃，不判断距离或圆圈。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("记录当前位置的触发信号") { controller.calibrate(model.signal, at: Date()) }
                    .disabled(!model.running || model.freshRSSI == nil)
                if controller.calibrated { Text("已记录触发强度 · \(controller.threshold) dBm").font(.caption) }
                Button(controller.armed ? "等待信号达标 · \(controller.remaining) 秒" : "开启本次自动响铃") { controller.arm() }
                    .disabled(!controller.calibrated || controller.armed || controller.preparing || !model.running)
                Text("每次寻找时手动开启，前台信号持续达标约 5 秒后发送四次提醒，最多等待两分钟。后台不持续监测；退后台、信号减弱或中断会停止自动模式。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("收不到声音时") {
                Text("检查手表提示音与通知是否开启、勿扰是否关闭，以及 iPhone 蓝牙详情中的共享系统通知。本 App 通知应允许锁定屏幕、通知中心和声音。手机也可能发出通知声音。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("检查通知权限") { controller.refreshPermission() }
                Text(controller.noticePermission).font(.caption)
            }
            Text("系统通知可能同时提醒其他已配对手表；不同型号需实测。可在我的设备中标注结果。").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("此类设备目前提供信号寻找，尚未提供发声控制。蓝牙可见不等于可以远程响铃。").font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("听声寻找") }
    }
}

private struct LastPlaceSection: View {
    @ObservedObject var controller: LastPlaceController
    @ObservedObject var model: FinderModel
    @State private var confirmClear = false
    @State private var mapToCalibrate: LastPlaceRecord?
    var body: some View {
        Section {
            if let date = model.lastSeen {
                LabeledContent("最后有效信号") { Text(date, format: .dateTime.month().day().hour().minute().second()) }
                    .font(.subheadline)
            } else { Text("尚未收到有效信号").foregroundStyle(.secondary) }
            if let place = controller.lastPlace {
                LastPlaceMap(place: place, coordinate: controller.displayCoordinate(for: place)).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("收到信号时，手机曾在此附近").font(.headline)
                if place.qualityVersion != 2 { Text("旧版记录，尚未通过新的精度检查；请刷新后再判断位置").font(.caption).foregroundStyle(.orange) }
                if controller.aligned(place) { Text("已应用你确认的局部地图对齐").font(.caption).foregroundStyle(.secondary) }
                Text("位置对应信号：\(place.signalTime.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("手机定位误差约 ±\(Int(ceil(place.accuracy))) 米\(place.accuracy > 100 ? " · 精度较低" : "")")
                    .font(.caption).foregroundStyle(place.accuracy > 100 ? .orange : .secondary)
                Text("标记和圆圈表示手机的位置与定位误差，不是手表坐标或手表所在范围。室内通常无法区分房间或楼层。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("在地图中查看") { controller.openMap() }
                Button("刷新精确位置") { controller.improveLocation() }
                DisclosureGroup("地图仍有偏移？") {
                    Text("先核对记录时间与定位精度。若你正站在收到信号的位置，且地图仍偏移，可手动将地图中心对齐你实际所在处。原始坐标不修改。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("校准地图显示") { mapToCalibrate = place }
                        .disabled(place.qualityVersion != 2 || !model.running)
                    if controller.alignment != nil { Button("撤销地图校准") { controller.resetMapCalibration() } }
                }
            } else {
                Text("尚无可用位置").foregroundStyle(.secondary)
                Text("开启后，在前台收到手表信号且取得近期定位时自动保存。以前的信号无法补回位置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !controller.enabled { Button("开启最后位置记录") { controller.enable() } }
            if controller.enabled && controller.reducedAccuracy { Button("请求精确位置") { controller.improveLocation() } }
            Text(controller.status).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("位置记录设置") {
                if controller.enabled { Button("关闭位置记录") { controller.disable() } }
                if controller.authorizationDenied {
                    Button("打开 App 设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                if controller.lastPlace != nil { Button("删除此手表的位置记录", role: .destructive) { confirmClear = true } }
                Text("仅请求使用 App 期间定位，记录保存在本机；退后台不继续追踪。位置时间可能早于最后信号时间。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("最后发现与位置") }
            .sheet(item: $mapToCalibrate) { place in
                MapCalibrationView(controller: controller, place: place)
            }
            .confirmationDialog("删除此手表的位置记录？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("删除记录", role: .destructive) { controller.clear() }
            }
    }
}

private struct LastPlaceMap: UIViewRepresentable {
    let place: LastPlaceRecord
    let coordinate: CLLocationCoordinate2D
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator; map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let fingerprint = "\(coordinate.latitude),\(coordinate.longitude),\(place.accuracy)"
        guard context.coordinator.fingerprint != fingerprint else { return }
        context.coordinator.fingerprint = fingerprint
        map.removeAnnotations(map.annotations); map.removeOverlays(map.overlays)
        let pin = MKPointAnnotation(); pin.coordinate = coordinate; pin.title = "手机曾在此"
        map.addAnnotation(pin)
        map.addOverlay(MKCircle(center: coordinate, radius: max(1, place.accuracy)))
        let width = max(150, place.accuracy * 3)
        map.setRegion(MKCoordinateRegion(center: coordinate, latitudinalMeters: width, longitudinalMeters: width), animated: false)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var fingerprint = ""
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemTeal.withAlphaComponent(0.15)
            renderer.strokeColor = .systemTeal; renderer.lineWidth = 1.5
            return renderer
        }
    }
}

private struct SignalReadout: View {
    @ObservedObject var controller: SignalGuideController
    @ObservedObject var model: FinderModel
    var body: some View {
        VStack(spacing: 7) {
            Text(controller.headline).foregroundStyle(.mint).font(.system(size: 34, weight: .bold, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
            Text(model.freshRSSI.map { "\($0) dBm" } ?? "— dBm").font(.headline).monospacedDigit().foregroundStyle(.secondary)
            Text("信号强度 · 不表示米数").font(.caption2).foregroundStyle(.secondary)
        }.padding(.horizontal, 24)
    }
}

private struct SignalRouteSection: View {
    @ObservedObject var controller: SignalGuideController
    @ObservedObject var model: FinderModel
    var body: some View {
        Section {
            DisclosureGroup("移动路线比较") {
                Text(controller.detail).font(.caption).foregroundStyle(.secondary)
                Text("比较哪条路线更值得找").font(.headline)
                Text("这是你移动后的采样比较，不是手机测出了手表方位。先记录起点，每次从起点沿一条路线走几步、停 12 秒记录，再回起点换路线。")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(["起点", "前方", "左侧", "右侧", "后方"], id: \.self) { route in
                    Button {
                        controller.recordRoute(route, signal: model.signal, at: Date())
                    } label: {
                        HStack { Text("记录\(route)采样点"); Spacer(); if let value = controller.routeReadings[route] { Text("\(value) dBm").monospacedDigit() } }
                    }.disabled(!model.running)
                }
                Text(controller.routeAdvice).font(.caption).foregroundStyle(.mint)
            }
        }
    }
}

private struct FinderGuideView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("两步寻找") {
                    Label("先找信号明显变强的区域", systemImage: "1.circle.fill").font(.headline)
                    Text("拿着手机缓慢移动，每走几步停一下，观察信号趋势。先缩小到房间内值得重点寻找的区域，不必盯着单次数值。")
                    Label("再响铃，听声找具体位置", systemImage: "2.circle.fill").font(.headline)
                    Text("点击“发送手表通知提醒”，第 5、10、15、20 秒各提醒一次。可以锁屏后安静听声，检查沙发缝、抽屉或衣物下面。找到后点停止提醒。")
                }
                Section("信号达标自动响铃是什么意思？") {
                    Text("先在信号明显增强的位置记录一次触发强度。以后每次寻找时开启自动响铃，App 在前台等候；当前信号持续达到保存的强度约五秒，才发送四次提醒。")
                    Text("不需要另外建立两米配对，也不会形成两米圆圈。换房间、遮挡和握持姿势都可能改变信号，建议重新记录。它不会全天后台监测，单次最多等待两分钟。直接点击响铃则不必做这项设置。")
                }
                Section("信号、路线与地图") {
                    Text("页面显示信号较强／适中／较弱和变化趋势，不换算米数。20 厘米、一米或隔着抽屉都可能出现相似读数，因此不能把信号等级当成实际距离。")
                    Text("前后左右只能通过你实际移动、记录不同路线的信号进行比较；单个 RSSI 没有入射角。路线结果表示哪个采样点信号更强，不是测得的设备方向。")
                    Text("最后位置是当时手机的位置。开启精确定位，等待误差小于 50 米且连续样本稳定再保存。地图偏移时先看时间和精度；手动地图校准只在附近一公里、24 小时内生效，可撤销。")
                }
                Section("为什么不能直接调大手表音量？") {
                    Text("目前可用通知链路没有手表音量控制接口。请在手表 General → Tones 中开启提示音，并打开振动、关闭勿扰。手机音量并不等于手表音量。改变提醒次数不能提高单次声压。")
                    Text("响铃期间 App 暂停原有手机寻表提示，但系统通知仍可能令手机发声。可以让手机离耳朵远一点，注意听房间里的手表。")
                }
                Section("设备收藏与隐私") {
                    Text("只添加你自己的设备。昵称、常放位置、测试结果和最后位置保存在本机；移出收藏可删除该设备的记录。系统蓝牙标识可能变化，名称相同不代表同一设备。")
                    Text("本 App 无账号、广告或自建服务器。地图由系统地图提供；诊断分享由你主动操作，可能包含设备名称和蓝牙标识，请先检查。删除 App 会移除本机数据，系统备份由你的 iOS 设置管理。")
                    Text("通知转发由 iOS 决定，可能同时提醒其他已配对配件，不能指定只向收藏的某一块表发送。其他品牌及耳机的响铃能力必须逐项验证。")
                    Text("随手寻是开发中的独立工具，与 Suunto 或其他设备品牌无隶属关系。")
                }
                Section("关于固件") {
                    Text("增加固件逻辑不能凭空增加天线阵列或 UWB 硬件。若将来确认芯片支持专用测向信号，还需要接收端硬件和可用接口配合。目前没有可验证的这块表的固件测向或音量接口，不会把猜测命令写入手表。")
                }
            }.navigationTitle("寻表指引").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct MapCalibrationView: View {
    @ObservedObject var controller: LastPlaceController
    let place: LastPlaceRecord
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    init(controller: LastPlaceController, place: LastPlaceRecord) {
        self.controller = controller; self.place = place
        _region = State(initialValue: MKCoordinateRegion(center: controller.displayCoordinate(for: place), latitudinalMeters: 1200, longitudinalMeters: 1200))
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("保持原地且持续收到手表信号。拖动地图，让十字中心对准你明确知道的手机实际位置。")
                    .font(.subheadline).padding(.horizontal)
                ZStack {
                    Map(coordinateRegion: $region)
                    Image(systemName: "plus.circle.fill").font(.largeTitle).foregroundStyle(.red).allowsHitTesting(false)
                }
                Text("这是人工确认的局部显示对齐，不会更改 GPS 原始记录，也不是自动修复定位漂移。").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                Text(controller.status).font(.caption).padding(.horizontal)
            }.navigationTitle("地图校准").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存对齐") { if controller.calibrateMap(place, selected: region.center) { dismiss() } }
                    }
                }
        }
    }
}
