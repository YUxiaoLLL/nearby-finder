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
                } header: { Text("随手寻 · V0.10（开发版）") }
                Section {
                    Button { showLibrary = true } label: { Label("我的设备", systemImage: "square.grid.2x2") }
                    Button {
                        if !model.running { model.start() }
                        showNearby = true
                    } label: { Label("添加附近设备", systemImage: "plus.circle") }
                }
                DeviceCategorySection()
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
        } header: { Text("通知辅助（手表）") }
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
                LabeledContent("最后有效信号") { Text(date, format: .dateTime.month().day().hour().minute().second()) }.font(.subheadline)
            } else { Text("尚未收到有效信号").foregroundStyle(.secondary) }

            Button {
                mapToCalibrate = controller.calibrationReference
            } label: { Label("手动对齐／确认位置", systemImage: "mappin.and.ellipse") }
                .disabled(controller.calibrationReference == nil)
            Text(controller.calibrationReference == nil
                 ? "先收到一次此物品的有效信号。已有历史记录时，暂停寻找或 GPS 不准也能手动对齐。"
                 : "对齐的是这次信号对应的手机位置参考。暂停寻找或 GPS 不准也可操作，请核对信号时间。")
                .font(.caption).foregroundStyle(.secondary)

            if let reference = controller.manualReference {
                LastPlaceMap(place: controller.displayRecord(reference), manual: true)
                    .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("你确认的参考位置").font(.headline)
                if !reference.note.isEmpty { Text(reference.note).font(.subheadline) }
                Text("对应信号：\(reference.signalTime.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("手动确认：\(reference.confirmedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("此参考点不会过期或被自动采样覆盖；它是你的历史确认，不代表物品现在仍在这里，也没有 GPS 精度保证。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("修改此历史参考") { mapToCalibrate = controller.displayRecord(reference) }
                Button("在地图中查看手动参考") { controller.openMap(manual: true) }
                Button("撤销手动参考") { controller.resetMapCalibration() }
            }
            if let place = controller.lastPlace {
                Text("自动记录：收到信号时手机的位置").font(.headline)
                Text("对应信号：\(place.signalTime.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("系统报告不确定范围约 \(Int(ceil(place.accuracy))) 米，不是实际误差保证")
                    .font(.caption).foregroundStyle(.secondary)
                if place.qualityVersion != 3 {
                    Text("旧版记录未通过本版稳定性检查，请核对后手动确认或重新采集。")
                        .font(.caption).foregroundStyle(.orange)
                }
                if place.userRejected == true {
                    Text("你已标记此自动位置不可靠，自动更新已暂停。")
                        .font(.caption).foregroundStyle(.orange)
                }
                if controller.manualReference == nil && place.qualityVersion == 3 && place.userRejected != true {
                    LastPlaceMap(place: place).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("在地图中查看自动位置") { controller.openMap() }
                }
                DisclosureGroup("查看自动定位原始参考") {
                    LastPlaceMap(place: place).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("圆圈是系统报告的手机定位不确定范围，不是物品所在范围；室内通常不能判断房间、楼层或无声物品的具体位置。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("在地图中查看自动位置") { controller.openMap() }
                }
                Button("这个自动位置不对") { controller.rejectAutomaticLocation() }
            } else {
                Text("尚无符合条件的自动位置").foregroundStyle(.secondary)
                Text("只接受本次采样开始后的新定位：系统报告范围 ≤20 米、至少 5 个样本、连续稳定 6 秒，并与有效信号相隔不超过 3 秒。无合格定位就不新增标记；以前的信号不能补回位置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("重新采集手机位置") {
                if !model.running { model.start() }
                controller.improveLocation()
            }
            if !controller.enabled { Button("开启自动最后位置记录") { controller.enable() } }
            if controller.enabled && controller.reducedAccuracy { Button("请求精确位置") { controller.improveLocation() } }
            Text(controller.status).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("位置记录设置") {
                if controller.enabled { Button("关闭自动位置记录") { controller.disable() } }
                if controller.authorizationDenied {
                    Button("打开 App 设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                if controller.lastPlace != nil || controller.manualReference != nil {
                    Button("删除此物品的全部位置参考", role: .destructive) { confirmClear = true }
                }
                Text("自动定位只在前台寻找时采样。自动位置、手动确认与常放位置备注分别保存；手动确认不修改 GPS 原始记录。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("最后信号与位置参考") }
            .sheet(item: $mapToCalibrate) { place in
                MapCalibrationView(controller: controller, place: place)
            }
            .confirmationDialog("删除此物品的自动位置及手动参考？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("删除全部位置参考", role: .destructive) { controller.clear() }
            }
    }
}

private struct LastPlaceMap: UIViewRepresentable {
    let place: LastPlaceRecord
    var manual = false
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator; map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let fingerprint = "\(place.deviceID),\(place.latitude),\(place.longitude),\(place.accuracy),\(manual)"
        guard context.coordinator.fingerprint != fingerprint else { return }
        context.coordinator.fingerprint = fingerprint
        map.removeAnnotations(map.annotations); map.removeOverlays(map.overlays)
        let pin = MKPointAnnotation(); pin.coordinate = place.coordinate
        pin.title = manual ? "手动确认的参考位置" : "手机曾在此附近"
        map.addAnnotation(pin)
        if !manual { map.addOverlay(MKCircle(center: place.coordinate, radius: max(1, place.accuracy))) }
        let width = manual ? 250 : max(150, place.accuracy * 4)
        map.setRegion(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: width, longitudinalMeters: width), animated: false)
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
                    Text("最后位置是信号发生时的手机位置参考。自动记录需新定位、系统不确定范围不超过 20 米并稳定至少六秒；此范围不是准确性保证。地图偏移时可直接打开手动对齐，确认地点和时间，独立保存的参考不会过期或被自动覆盖。")
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
            }.navigationTitle("寻找指引").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct MapCalibrationView: View {
    @ObservedObject var controller: LastPlaceController
    let place: LastPlaceRecord
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var confirmed = false
    @State private var note = ""
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchStatus = ""
    init(controller: LastPlaceController, place: LastPlaceRecord) {
        self.controller = controller; self.place = place
        _note = State(initialValue: controller.manualReference?.signalTime == place.signalTime ? controller.manualReference?.note ?? "" : "")
        _region = State(initialValue: place.accuracy >= 10000
            ? MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180))
            : MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("这次信号：\(place.signalTime.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption).padding(.horizontal)
                Text("将十字中心对齐这次信号发生时，手机实际所在的位置。可先搜索地点，再拖动微调；不要把现在的位置误当成历史位置。")
                    .font(.caption).padding(.horizontal)
                HStack {
                    TextField("搜索地点或地址（发送给 Apple 地图）", text: $query).textFieldStyle(.roundedBorder)
                    Button("搜索") { search() }.disabled(searching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(.horizontal)
                if !searchStatus.isEmpty { Text(searchStatus).font(.caption) }
                if !results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                                Button(item.name ?? "地图地点") {
                                    region = MKCoordinateRegion(center: item.placemark.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
                                    results = []; confirmed = false
                                }
                            }
                        }
                    }.frame(maxHeight: 90).padding(.horizontal)
                }
                ZStack {
                    Map(coordinateRegion: $region)
                    Image(systemName: "plus.circle.fill").font(.largeTitle).foregroundStyle(.red).allowsHitTesting(false)
                }.frame(minHeight: 170)
                    .onChange(of: region.center.latitude) { _ in confirmed = false }
                    .onChange(of: region.center.longitude) { _ in confirmed = false }
                TextField("位置备注，例如公司三楼会议室", text: $note).textFieldStyle(.roundedBorder).padding(.horizontal)
                Toggle("我确认此处对应上述信号发生时的手机位置", isOn: $confirmed).font(.caption).padding(.horizontal)
                Text("独立保存为手动参考，不修改原始定位、不自动过期，也不代表物品目前的位置。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                Text(controller.status).font(.caption).padding(.horizontal)
            }.navigationTitle("手动对齐／确认位置").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存参考") {
                            if controller.calibrateMap(place, selected: region.center, note: note) { dismiss() }
                        }.disabled(!confirmed)
                    }
                }
        }
    }
    private func search() {
        searching = true; searchStatus = "搜索中…"
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        Task { @MainActor in
            defer { searching = false }
            do {
                let response = try await MKLocalSearch(request: request).start()
                results = Array(response.mapItems.prefix(5))
                searchStatus = results.isEmpty ? "未找到地点，请换一个更具体的地址" : "选择结果后仍需拖动地图并亲自确认"
            } catch { searchStatus = "地图搜索暂不可用，仍可手动拖动地图" }
        }
    }
}
