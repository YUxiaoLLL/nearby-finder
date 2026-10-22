import SwiftUI

struct DeviceLibraryView: View {
    @ObservedObject var model: FinderModel
    @ObservedObject var library: DeviceLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var editing: SavedDevice?
    @State private var pendingRemoval: SavedDevice?
    var body: some View {
        NavigationStack {
            List {
                if library.devices.isEmpty {
                    Text("先从附近设备中确认自己的物品，再加入收藏。以后可以直接点名字寻找。")
                }
                ForEach(library.devices) { device in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(device.displayName, systemImage: device.kind.icon).font(.headline)
                        Text(device.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                        if !device.storageNote.isEmpty { Text("常放：\(device.storageNote)").font(.subheadline) }
                        if let date = device.lastSeen { Text("最后信号：\(date.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                        if device.kind == .watch { Text("通知提醒：\(device.notificationSupport.rawValue)").font(.caption).foregroundStyle(.secondary) }
                        HStack {
                            Button("寻找这件物品") { model.selectSaved(device); dismiss() }
                            Spacer()
                            Button("编辑") { editing = device }
                            Button("移出收藏", role: .destructive) { pendingRemoval = device }
                        }.buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
                Section {
                    Text("同名设备可能不是同一件物品；UUID 变化后需要重新确认。耳机、手环及其他设备是否持续广播、允许连接或响应通知，必须分别测试。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("我的设备")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .sheet(item: $editing) { DeviceEditorView(model: model, device: $0) }
                .confirmationDialog("将此设备移出收藏？不会解除系统蓝牙配对。", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                    if let device = pendingRemoval { Button("移出收藏", role: .destructive) { model.forgetDevice(device.id); pendingRemoval = nil } }
                }
        }
    }
}

struct DeviceEditorView: View {
    @ObservedObject var model: FinderModel
    @Environment(\.dismiss) private var dismiss
    @State private var device: SavedDevice
    init(model: FinderModel, device: SavedDevice) { self.model = model; _device = State(initialValue: device) }
    var body: some View {
        NavigationStack {
            Form {
                TextField("昵称", text: $device.nickname)
                Picker("类别", selection: $device.kind) { ForEach(DeviceKind.allCases) { Text($0.rawValue).tag($0) } }
                TextField("常放位置，例如玄关抽屉", text: $device.storageNote)
                Text("常放位置由你填写，与手机定位记录不同。").font(.caption).foregroundStyle(.secondary)
                if device.kind == .watch {
                    Picker("通知提醒实测结果", selection: $device.notificationSupport) {
                        ForEach(NotificationSupport.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text("只有亲自确认这件设备会响应本 App 的通知后，才标为已验证。通知经系统转发，可能同时提醒其他已配对配件，不是按 UUID 定向响铃。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(device.advertisedName).font(.caption)
                Text(device.id.uuidString).font(.caption2).textSelection(.enabled)
            }.navigationTitle("编辑物品")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { model.saveDevice(device); dismiss() } }
                }
        }
    }
}

struct AddDeviceView: View {
    @ObservedObject var model: FinderModel
    let row: DeviceRow
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var kind = DeviceKind.other
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                Text(row.name).font(.headline)
                Text(row.id.uuidString).font(.caption2).textSelection(.enabled)
                TextField("给自己的物品起个名字", text: $nickname)
                Picker("类别", selection: $kind) { ForEach(DeviceKind.allCases) { Text($0.rawValue).tag($0) } }
                TextField("常放位置（选填）", text: $note)
                Text("请先在设备已找到时确认身份。名称相同或信号很强，都不能证明这是你的设备。加入收藏不等于保证能连接或响铃。")
                    .font(.caption).foregroundStyle(.secondary)
                if !model.running { Text("请返回并开始扫描，再添加设备。").foregroundStyle(.orange) }
            }.navigationTitle("确认并收藏")
                .onAppear {
                    nickname = row.name
                    if row.name.localizedCaseInsensitiveContains("Suunto") { kind = .watch }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("这是我的设备") { model.addDevice(row, nickname: nickname, kind: kind, note: note); dismiss() }
                            .disabled(!model.running)
                    }
                }
        }
    }
}

struct DeviceShelfHeader: View {
    @ObservedObject var model: FinderModel
    @ObservedObject var library: DeviceLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(model.selectedName, systemImage: model.currentDevice?.kind.icon ?? "shippingbox").font(.headline)
            if let device = model.currentDevice, !device.storageNote.isEmpty { Text("常放：\(device.storageNote)").font(.subheadline).foregroundStyle(.secondary) }
            Text("收藏 \(library.devices.count) 件 · 当前逐件寻找").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct NearbyDevicesView: View {
    @ObservedObject var model: FinderModel
    @Environment(\.dismiss) private var dismiss
    @State private var pending: DeviceRow?
    var body: some View {
        NavigationStack {
            List {
                Text("这里只显示当前可被本 App 发现的 BLE 广播，不是系统全部已配对设备。先确认是自己的设备，再加入收藏。")
                    .font(.caption).foregroundStyle(.secondary)
                if model.rows.isEmpty { Text("等待设备广播；某些设备休眠、连接厂商 App 后可能不再广播。") }
                ForEach(model.rows) { row in
                    Button { pending = row } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(row.name); Spacer(); Text("\(row.rssi) dBm") }
                            Text(row.id.uuidString).font(.caption2)
                        }
                    }.foregroundStyle(.primary)
                }
            }.navigationTitle("附近设备")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .sheet(item: $pending) { AddDeviceView(model: model, row: $0) }
        }
    }
}
