import Foundation

/// UI preference only. Persisted device identities, source keys and user notes stay unchanged.
enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"
    static let preferenceKey = "appLanguage"
    static var selected: AppLanguage {
        get {
            resolve(saved: UserDefaults.standard.string(forKey: preferenceKey), preferred: Locale.preferredLanguages)
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey) }
    }
    static func resolve(saved: String?, preferred: [String]) -> AppLanguage {
        if let saved, let language = AppLanguage(rawValue: saved) { return language }
        for tag in preferred {
            if tag.hasPrefix("zh") { return .chinese }
            if tag.hasPrefix("en") { return .english }
        }
        return .english
    }
    var locale: Locale { Locale(identifier: rawValue) }
}

func T(_ text: String) -> String { AppTranslation.text(text, language: AppLanguage.selected) }
func localizedDate(_ date: Date, time: Date.FormatStyle.TimeStyle = .shortened) -> String {
    date.formatted(Date.FormatStyle(date: .abbreviated, time: time).locale(AppLanguage.selected.locale))
}

enum AppTranslation {
    static let english: [String: String] = [
        "暂无实时信号，停下等待重新检测": "No live signal. Pause and wait for detection.",
        "缓慢走几步并停下，积累约 20 秒样本": "Walk a few steps slowly, pause, and collect about 20 seconds of samples.",
        "信号增强，尝试继续沿当前路线寻找": "Signal is improving. Try continuing along this route.",
        "信号减弱，尝试返回上一处比较": "Signal is weakening. Try returning to the previous spot.",
        "信号变化不明显，换一条路线再试": "Little change in signal. Try another route.",
        "初始化": "Starting up",
        "点击开始扫描，允许蓝牙访问": "Start scanning and allow Bluetooth access.",
        "尚未识别手表": "Watch not identified yet",
        "未连接": "Not connected",
        "未知": "Unknown",
        "监听已停止": "Monitoring stopped",
        "尚未验证持续 RSSI": "Continuous RSSI not verified yet",
        "已收到连续样本：≥5 个，跨度 ≥10 秒": "Continuous samples received: at least 5 over 10 seconds",
        "本次有效样本 {0} 个；当前窗口跨度 {1} 秒": "{0} valid samples this session; current window spans {1} seconds",
        "尚未选择设备": "No device selected",
        "系统正在重置": "Bluetooth is resetting",
        "硬件不支持": "Hardware not supported",
        "蓝牙权限未授权": "Bluetooth permission not granted",
        "蓝牙已关闭": "Bluetooth is off",
        "蓝牙已开启": "Bluetooth is on",
        "系统蓝牙不可用": "System Bluetooth unavailable",
        "请在 iPhone 设置中检查蓝牙与本 App 权限；程序无法替你切换系统蓝牙": "Check Bluetooth and app permissions in iPhone Settings. The app cannot toggle system Bluetooth.",
        "选择已收藏设备寻找，或从附近列表添加自己的设备": "Choose a saved device, or add your own device from the nearby list.",
        "等待系统蓝牙开启／授权": "Waiting for Bluetooth or permission",
        "已停止": "Stopped",
        "已停止；旧读数不会显示为实时信号": "Stopped. Old readings are not shown as live signals.",
        "后台已暂停。本版仅在前台寻找。": "Paused in the background. Searching works in the foreground only.",
        "已重启本 App 扫描（没有关闭系统蓝牙）": "App scan restarted; system Bluetooth was not switched off.",
        "未命名设备": "Unnamed device",
        "广播": "Advertisement",
        "已识别设备，正在寻找。保持手机姿势稳定，缓慢移动。": "Device identified. Keep the phone steady and move slowly.",
        "先开始扫描，等待设备再次出现": "Start scanning and wait for the device to appear again.",
        "请先扫描，等待设备再次出现": "Please scan and wait for the device to appear again.",
        "先从附近列表确认并收藏自己的设备": "First identify and save your own device from the nearby list.",
        "系统未返回已登记 UUID；继续扫描。不能据此断言手表离线。": "The system did not return the saved UUID. Scanning continues; this does not prove the watch is offline.",
        "已登记设备": "Saved device",
        "请先扫描识别，或尝试恢复已登记手表": "Scan to identify the watch, or try restoring the saved device.",
        "正在连接（最多等待 15 秒）": "Connecting (up to 15 seconds)",
        "本 App 已连接；等待 RSSI 回调": "Connected to this app; waiting for RSSI",
        "连接本身不是 RSSI。只显示 didReadRSSI 返回的有效数值。": "A connection is not a signal reading. Only valid didReadRSSI values are shown.",
        "连接后 readRSSI": "Connected RSSI",
        "本 App 已连接": "Connected to this app",
        "连接失败；仍可观察广播": "Connection failed; advertisements can still be observed.",
        "已断开；继续扫描": "Disconnected; scanning continues.",
        "连接超时，不代表手表没电": "Connection timed out. This does not mean the watch battery is empty.",
        "连接无有效信号，正在恢复": "No valid connected signal; recovering",
        "RSSI 回调超时": "RSSI callback timed out",
        "日志导出失败：{0}": "Could not export log: {0}",
        "先从附近设备中确认自己的物品，再加入收藏。以后可以直接点名字寻找。": "Identify your own item in the nearby list and save it. Later, tap its name to search.",
        "常放：{0}": "Usually kept: {0}",
        "最后信号：{0}": "Last signal: {0}",
        "通知提醒：{0}": "Notification alerts: {0}",
        "寻找这件物品": "Find this item",
        "编辑": "Edit",
        "移出收藏": "Remove from saved devices",
        "同名设备可能不是同一件物品；UUID 变化后需要重新确认。耳机、手环及其他设备是否持续广播、允许连接或响应通知，必须分别测试。": "Matching names do not prove identity. Confirm the device again if its UUID changes. Advertising, connections and notification responses must be tested for each device.",
        "我的设备": "My devices",
        "完成": "Done",
        "将此设备移出收藏？不会解除系统蓝牙配对。": "Remove this saved device? System Bluetooth pairing will remain.",
        "昵称": "Nickname",
        "类别": "Category",
        "常放位置，例如玄关抽屉": "Usual location, e.g. entryway drawer",
        "常放位置由你填写，与手机定位记录不同。": "You provide the usual location. It is separate from phone location records.",
        "通知提醒实测结果": "Notification test result",
        "只有亲自确认这件设备会响应本 App 的通知后，才标为已验证。通知经系统转发，可能同时提醒其他已配对配件，不是按 UUID 定向响铃。": "Mark as verified only after testing this device yourself. iOS forwards notifications and may alert other paired accessories too; alerts are not targeted by UUID.",
        "编辑物品": "Edit item",
        "取消": "Cancel",
        "保存": "Save",
        "给自己的物品起个名字": "Give your item a nickname",
        "常放位置（选填）": "Usual location (optional)",
        "请先在设备已找到时确认身份。名称相同或信号很强，都不能证明这是你的设备。加入收藏不等于保证能连接或响铃。": "Confirm the identity while you have the device in hand. A matching name or strong signal does not prove ownership. Saving it does not guarantee connection or sound support.",
        "请返回并开始扫描，再添加设备。": "Go back and start scanning before adding a device.",
        "确认并收藏": "Confirm and save",
        "这是我的设备": "This is my device",
        "收藏 {0} 件 · 当前逐件寻找": "{0} saved items · Search one at a time",
        "这里只显示当前可被本 App 发现的 BLE 广播，不是系统全部已配对设备。先确认是自己的设备，再加入收藏。": "This list contains BLE advertisements this app can discover, not every device paired with iOS. Confirm ownership before saving.",
        "等待设备广播；某些设备休眠、连接厂商 App 后可能不再广播。": "Waiting for advertisements. Some devices stop advertising while asleep or connected to their companion app.",
        "附近设备": "Nearby devices",
        "查看 Apple 官方查找指南": "Open Apple's Find My guide",
        "物品类别与寻找方式": "Categories and finding methods",
        "增加类别是为了分类管理，不代表每个品牌都能被 iPhone 找到。无声设备可结合常放位置、信号趋势与手机最后位置参考；不能补回从未记录的位置。": "Categories help organize items; they do not guarantee compatibility. For silent items, combine storage notes, signal trends and the phone's last location reference. Missing past locations cannot be recovered.",
        "手表／手环": "Watches / bands",
        "耳机": "Headphones",
        "Apple Pencil／触控笔": "Apple Pencil / styluses",
        "蓝牙鼠标": "Bluetooth mice",
        "蓝牙键盘": "Bluetooth keyboards",
        "其他 BLE 物品": "Other BLE items",
        "Suunto 9 Peak Pro 有既往实测；其他手表仍需验证。通知转发不等于通用响铃。": "Suunto 9 Peak Pro has prior real-device test results. Other watches need testing. Notification forwarding is not universal ringing support.",
        "AirPods 请优先使用 Apple 查找。其他耳机仅在可发现 BLE 信号时辅助寻找，盒内、断电或休眠时可能不可见；没有通用发声控制。": "Use Apple Find My first for AirPods. Other headphones can only be searched when their BLE signal is discoverable. They may disappear in a case, when powered off or asleep. No universal sound control is available.",
        "Apple Pencil Pro 优先使用 Apple 查找。其他代际与触控笔尚未实测，iPhone 不保证可发现；休眠后可能没有信号。": "Use Apple Find My first for Apple Pencil Pro. Other generations and styluses are untested; iPhone discovery is not guaranteed, especially when asleep.",
        "仅对本 App 能发现的 BLE 鼠标尝试信号寻找；连接电脑、休眠或使用专用 2.4 GHz 接收器时可能不可见。没有响铃支持。": "Signal search only works for BLE mice this app can discover. A mouse may be invisible while connected to a computer, asleep, or using a dedicated 2.4 GHz receiver. No ringing support.",
        "蓝牙键盘通常会休眠，连接其他设备后也可能停止广播。此类别不代表已兼容；没有响铃支持。": "Bluetooth keyboards often sleep or stop advertising when connected elsewhere. This category does not imply verified compatibility. No ringing support.",
        "必须有电且能被本 App 发现或恢复连接。类别、名称和广播信号都不能代替身份确认。": "The item must have power and be discoverable or reconnectable by this app. A category, name or advertisement cannot establish ownership.",
        "未验证": "Not verified",
        "我已确认会提醒": "I verified that alerts work",
        "测试后未响应": "No response in my test",
        "等待信号": "Waiting for signal",
        "信号强度不能直接换算成米数": "Signal strength cannot be converted directly to meters.",
        "先记录起点，再沿不同路线移动、停下采样": "Record a starting point, then walk and pause along different routes.",
        "暂无实时信号，不能比较当前强弱": "No live signal to compare",
        "信号较强": "Stronger signal",
        "信号适中": "Moderate signal",
        "信号较弱": "Weaker signal",
        "强弱分级只描述蓝牙信号，不代表距离；请结合移动趋势和响铃寻找": "These levels describe Bluetooth signal, not distance. Use movement trends and audible alerts together.",
        "请先沿该路线走几步，再停下等待 12 秒稳定信号": "Walk along this route, then pause for 12 seconds to collect stable samples.",
        "请完成移动并等待至少 12 秒，再记录下一个采样点": "Finish moving and wait at least 12 seconds before recording another point.",
        "起点": "Start",
        "先记录起点": "Record the starting point first.",
        "起点已记录。每次从起点走向一条路线，停 12 秒记录，再返回起点换路线。": "Starting point saved. Walk along a route, pause for 12 seconds and record, then return to try another route.",
        "{0}路线采样信号最强，优先回到该采样点附近响铃确认": "The {0} route had the strongest sampled signal. Return near that point and try an audible alert.",
        "目前没有明显强于起点的路线，换路线继续比较": "No route is clearly stronger than the starting point. Try other routes.",
        "开启后，记录收到信号时手机的位置参考": "Enable to save the phone's position around a valid device signal.",
        "由旧版地图对齐保留，请核对历史时间": "Preserved from an older map alignment. Check its historical time.",
        "请选择使用 App 期间允许定位": "Choose Allow While Using App for location access.",
        "此物品的自动位置、手动参考与旧对齐已删除": "This item's automatic location, manual reference and old alignment were deleted.",
        "自动位置记录已关闭；已有手动参考仍保留": "Automatic location recording is off; manual history is retained.",
        "定位未授权；可手动确认已有信号的参考位置，或在设置中授权": "Location is not authorized. Confirm a historical reference manually, or allow access in Settings.",
        "等待定位授权": "Waiting for location permission",
        "已标记自动位置不可靠；可手动对齐，或点重新采集再试": "Automatic location was marked unreliable. Align manually or collect a new fix.",
        "自动采样已暂停；历史记录和手动参考仍保留": "Automatic sampling paused; historical records are retained.",
        "请开启精确位置；粗略位置不保存为标记": "Enable Precise Location. Approximate fixes are not saved as map pins.",
        "正在自动读取手机位置…": "Reading the phone's location…",
        "定位缓存、过期或不确定范围过大；保留历史参考，等待新样本": "Location is cached, stale or too uncertain. Keeping history and waiting for a fresh fix.",
        "检测到定位跳动，重新等待稳定样本": "Location jump detected; waiting for stable fixes.",
        "新位置与旧记录差距较大，需稳定 20 秒再更新": "The new fix is far from the recent record. Waiting for 20 seconds of stable samples.",
        "正在积累稳定定位（至少 5 个样本、跨度 6 秒）": "Collecting stable fixes: at least 5 samples spanning 6 seconds",
        "已自动记录收到信号时的手机位置": "Phone location saved around the received signal",
        "暂未取得可用定位，保留历史记录；可手动确认参考位置": "No usable location yet. History is retained; you can confirm a reference manually.",
        "自动位置已标记为不可靠并暂停更新；请手动对齐或重新采集": "Automatic location marked unreliable and paused. Align manually or collect a new fix.",
        "设备或信号记录已变化，请重新打开手动对齐": "The device or signal record changed. Reopen manual alignment.",
        "已保存手动参考；取得手机定位后可再次对齐，使后续自动位置同步校正": "Manual reference saved. After obtaining a phone fix, align again to correct future nearby records.",
        "已对齐；附近 500 米内的自动位置将使用此显示校正": "Aligned. Future automatic records within 500m will use this display correction.",
        "手动参考已撤销；原始自动定位记录保持不变": "Manual alignment removed; raw automatic location is unchanged.",
        "自动记录 · 手动对齐": "Automatic record · Manual alignment",
        "手动确认的历史参考": "Manually confirmed historical reference",
        "自动记录 · 已匹配系统地图": "Automatic record · Matched to system map",
        "系统定位与地图显示坐标差约 {0} 米；已按同机同期数据匹配，不是 GPS 精度提升。": "Phone and map coordinate values differ by about {0}m. Matched using same-phone samples; this does not improve GPS accuracy.",
        "等待系统地图与手机定位匹配；原始记录保留，暂不绘制未经匹配的位置。": "Waiting to match phone and system-map coordinates. Raw evidence is retained; an unverified pin is not plotted.",
        "手动确认的手机位置参考": "Manually confirmed phone reference",
        "收到物品信号时的手机位置（非物品坐标）": "Phone location when the item signal was received (not item coordinates)",
        "点击让手表响铃，前台或锁屏均可听声寻找": "Send watch alerts, then listen with the app open or the screen locked.",
        "通知已允许": "Notifications allowed",
        "请允许通知，并检查手表的共享系统通知设置": "Allow notifications and check Share System Notifications for the watch.",
        "可以开始响铃": "Ready to send alerts",
        "请到 iPhone 设置中允许本 App 通知": "Allow this app's notifications in iPhone Settings.",
        "请先登记你的手表": "Save your watch first.",
        "请先允许通知": "Allow notifications first.",
        "已安排 5、10、15、20 秒四次提醒，可锁屏听声": "Four alerts scheduled at 5, 10, 15 and 20 seconds. You can lock the screen and listen.",
        "寻找 Suunto · {0}/4": "Find Suunto · {0}/4",
        "请听手表的提示音。找到后返回 App 停止提醒。": "Listen for your watch. Return to the app and stop alerts when you find it.",
        "通知安排失败：{0}": "Could not schedule notifications: {0}",
        "请在你希望开始响铃的信号条件下，保持手机姿势稳定 12 秒后记录": "At the signal level where you want alerts to start, hold the phone steady for 12 seconds and record.",
        "触发信号已记录，可开启本次自动响铃": "Trigger level saved. You can arm automatic alerts for this search.",
        "请先记录触发信号": "Record a trigger level first.",
        "等待信号持续达到已保存强度，最多两分钟": "Waiting for the saved signal level, for up to two minutes",
        "本轮已结束，需要时可再响一轮": "This round has ended. Start another if needed.",
        "自动提醒已暂停；来源变化时请重新校准": "Automatic alerts paused. Recalibrate when the signal source changes.",
        "信号减弱或中断，自动响铃已停止": "Signal weakened or stopped; automatic alerts stopped.",
        "提醒已停止": "Alerts stopped",
        "缓慢移动，每走几步停一下。信号强度不代表实际距离。": "Move slowly and pause every few steps. Signal strength is not physical distance.",
        "暂停信号寻找": "Pause signal search",
        "开始寻找": "Start finding",
        "添加附近设备": "Add nearby device",
        "信号曲线与手机提示": "Signal chart and phone feedback",
        "收到信号后显示曲线": "The chart appears after a signal is received.",
        "时间": "Time",
        "平滑 RSSI": "Smoothed RSSI",
        "过去 60 秒 · 灰点原始值，绿线平滑值": "Last 60 seconds · Gray: raw samples · Green: smoothed signal",
        "手机振动提示": "Phone haptics",
        "手机声音提示": "Phone sound",
        "设备设置与诊断": "Device settings and diagnostics",
        "寻找时保持屏幕常亮": "Keep screen awake while finding",
        "名称匹配提示（选填）": "Name matching hint (optional)",
        "恢复已登记手表": "Restore saved watch",
        "显示全部 BLE 设备": "Show all BLE devices",
        "本 App 扫描重启：{0} 次": "App scan restarts: {0}",
        "重新扫描": "Scan again",
        "准备诊断日志": "Prepare diagnostic log",
        "分享日志": "Share log",
        "日志含附近蓝牙设备信息；位置坐标不写入诊断日志。仅在前台扫描及记录位置，已安排的四次通知可在锁屏后继续。": "Logs include nearby Bluetooth device information, but not location coordinates. Scanning and location recording are foreground-only; the four scheduled notifications may still arrive when locked.",
        "最近事件": "Recent events",
        "寻找设备": "Find device",
        "寻表使用指引": "Finding guide",
        "正在提醒 · 剩余约 {0} 秒": "Alerts active · About {0}s left",
        "发送手表通知提醒": "Send watch alerts",
        "第 5、10、15、20 秒各提醒一次，可以锁屏听声寻找。": "One alert each at 5, 10, 15 and 20 seconds. You can lock the screen and listen.",
        "找到手表了 · 停止提醒": "Found it · Stop alerts",
        "允许通知": "Allow notifications",
        "信号达标自动响铃": "Auto-alert at saved signal level",
        "先找一个信号明显增强、你希望自动开始响铃的位置，停 12 秒记录强度。以后寻找时，信号持续达到这个强度便触发响铃，不判断距离或圆圈。": "At a spot with a clearly stronger signal where you want alerts to start, pause for 12 seconds and record. On later searches, a sustained signal at that level triggers alerts. No distance or radius is measured.",
        "记录当前位置的触发信号": "Record trigger signal here",
        "已记录触发强度 · {0} dBm": "Trigger level saved · {0} dBm",
        "等待信号达标 · {0} 秒": "Waiting for trigger level · {0}s",
        "开启本次自动响铃": "Arm alerts for this search",
        "每次寻找时手动开启，前台信号持续达标约 5 秒后发送四次提醒，最多等待两分钟。后台不持续监测；退后台、信号减弱或中断会停止自动模式。": "Arm manually for each search. A sustained qualifying foreground signal for about 5 seconds triggers four alerts, with a two-minute waiting limit. Backgrounding, a weak signal or interruptions stop automatic mode.",
        "收不到声音时": "If you cannot hear alerts",
        "检查手表提示音与通知是否开启、勿扰是否关闭，以及 iPhone 蓝牙详情中的共享系统通知。本 App 通知应允许锁定屏幕、通知中心和声音。手机也可能发出通知声音。": "Check watch tones, notification settings and Do Not Disturb, plus Share System Notifications in iPhone Bluetooth settings. Allow Lock Screen, Notification Center and Sounds for this app. The phone may make a notification sound too.",
        "检查通知权限": "Check notification permission",
        "系统通知可能同时提醒其他已配对手表；不同型号需实测。可在我的设备中标注结果。": "iOS may alert other paired watches too. Test each model and record results in My devices.",
        "此类设备目前提供信号寻找，尚未提供发声控制。蓝牙可见不等于可以远程响铃。": "Signal search is available for this category; sound control is not. Bluetooth visibility does not imply remote ringing support.",
        "通知辅助（手表）": "Notification-assisted alerts (watches)",
        "最后有效信号": "Last valid signal",
        "尚未收到有效信号": "No valid signal received yet",
        "位置记录：{0}": "Location record: {0}",
        "在地图中查看": "Open in Maps",
        "正在匹配手机定位与系统地图，收到信号后自动记录。": "Matching phone and system-map locations. Records are saved around received signals.",
        "位置不准？手动对齐": "Wrong location? Align manually",
        "记录的是收到信号时的手机位置，供寻找物品时参考。": "This is the phone's location around the signal, provided as a search reference.",
        "重新采集手机位置": "Collect phone location again",
        "开启自动最后位置记录": "Enable last-location recording",
        "请求精确位置": "Request Precise Location",
        "位置详情与设置": "Location details and settings",
        "系统报告范围约 {0} 米，不是实际误差保证。": "System-reported uncertainty is about {0}m; actual error is not guaranteed.",
        "传入地图 → 标记坐标差：{0} 米": "Map input → Pin coordinate difference: {0}m",
        "查看本机坐标核验": "Inspect coordinates on this phone",
        "原始定位：{0}, {1}": "Raw location: {0}, {1}",
        "地图输入：{0}, {1}": "Map input: {0}, {1}",
        "定位与信号相差 {0} 秒": "Location and signal times differ by {0}s",
        "原始坐标按系统回调原样保存；地图坐标单独保存，仅在本机核验。": "Raw coordinates are preserved from the system callback. Map coordinates are stored separately for local checks.",
        "历史手动确认：{0}": "Historical manual confirmation: {0}",
        "查看历史手动参考": "View historical manual reference",
        "撤销手动对齐": "Remove manual alignment",
        "关闭自动位置记录": "Turn off automatic location recording",
        "打开 App 设置": "Open app settings",
        "删除此物品的全部位置参考": "Delete all location references for this item",
        "自动定位只在前台寻找时采样。原始定位与匹配后的地图坐标分开保存。系统匹配和手动对齐不会叠加；旧版未经核验的手动偏移已停用，历史确认仍保留。": "Location sampling is foreground-only. Raw and matched map coordinates are stored separately. System and manual corrections never stack. Unverified old offsets are disabled; historical confirmations are retained.",
        "最后信号与位置参考": "Last signal and location reference",
        "删除此物品的自动位置及手动参考？": "Delete this item's automatic and manual location references?",
        "删除全部位置参考": "Delete all location references",
        "手动确认的参考位置": "Manually confirmed reference",
        "手机曾在此附近": "Phone was near here",
        "信号强度 · 不表示米数": "Signal strength · Not meters",
        "移动路线比较": "Compare walking routes",
        "比较哪条路线更值得找": "Compare where to search next",
        "这是你移动后的采样比较，不是手机测出了手表方位。先记录起点，每次从起点沿一条路线走几步、停 12 秒记录，再回起点换路线。": "Compare samples from your own movement; the phone does not measure the watch's bearing. Record the start, walk a route, pause 12 seconds and record, then return and try another route.",
        "前方": "Front",
        "左侧": "Left",
        "右侧": "Right",
        "后方": "Back",
        "记录{0}采样点": "Record {0} sample",
        "两步寻找": "Find in two steps",
        "先找信号明显变强的区域": "First, find a stronger-signal area",
        "拿着手机缓慢移动，每走几步停一下，观察信号趋势。先缩小到房间内值得重点寻找的区域，不必盯着单次数值。": "Move slowly with your phone and pause every few steps. Watch the trend to narrow down which area of the room deserves attention; do not rely on a single reading.",
        "再响铃，听声找具体位置": "Then, listen for the exact hiding place",
        "点击“发送手表通知提醒”，第 5、10、15、20 秒各提醒一次。可以锁屏后安静听声，检查沙发缝、抽屉或衣物下面。找到后点停止提醒。": "Tap Send watch alerts. Alerts arrive at 5, 10, 15 and 20 seconds. Lock the screen and listen quietly; check sofa gaps, drawers and clothes. Stop alerts once found.",
        "信号达标自动响铃是什么意思？": "How do automatic signal-triggered alerts work?",
        "先在信号明显增强的位置记录一次触发强度。以后每次寻找时开启自动响铃，App 在前台等候；当前信号持续达到保存的强度约五秒，才发送四次提醒。": "Save a trigger level at a stronger-signal spot. Arm alerts for each search. The foreground app waits until the current signal stays at the saved level for about five seconds, then schedules four alerts.",
        "不需要另外建立两米配对，也不会形成两米圆圈。换房间、遮挡和握持姿势都可能改变信号，建议重新记录。它不会全天后台监测，单次最多等待两分钟。直接点击响铃则不必做这项设置。": "No two-meter pairing or detection circle is created. Rooms, obstructions and grip can change the signal, so record again when needed. Monitoring is not all-day or background, and each armed session waits up to two minutes. Direct alerts need no trigger setup.",
        "信号、路线与地图": "Signal, routes and maps",
        "页面显示信号较强／适中／较弱和变化趋势，不换算米数。20 厘米、一米或隔着抽屉都可能出现相似读数，因此不能把信号等级当成实际距离。": "The screen shows stronger, moderate or weaker signal and its trend, without converting it to meters. A similar reading may occur at 20cm, 1m or behind a drawer, so these levels are not distances.",
        "前后左右只能通过你实际移动、记录不同路线的信号进行比较；单个 RSSI 没有入射角。路线结果表示哪个采样点信号更强，不是测得的设备方向。": "Front, back, left and right are routes you walk and sample. A single RSSI reading has no arrival angle. Results identify a stronger sampled spot, not a measured device bearing.",
        "最后位置是信号发生时的手机位置参考。自动记录使用收到信号时的新手机定位；明显跳点需等待稳定确认。地图偏移时点手动对齐：有效原始定位附近 500 米内的后续记录会同步校正显示，此校正不提升 GPS 实际精度。": "The last location refers to the phone around a signal. Fresh fixes are recorded automatically; large jumps need stable evidence. Use manual alignment if needed. Local display correction does not improve GPS accuracy.",
        "为什么不能直接调大手表音量？": "Why can't the app turn up the watch volume?",
        "目前可用通知链路没有手表音量控制接口。请在手表 General → Tones 中开启提示音，并打开振动、关闭勿扰。手机音量并不等于手表音量。改变提醒次数不能提高单次声压。": "The available notification channel has no watch-volume control. Enable tones in watch General → Tones, enable vibration and turn off Do Not Disturb. Phone volume is separate from watch volume. More alerts do not make each alert louder.",
        "响铃期间 App 暂停原有手机寻表提示，但系统通知仍可能令手机发声。可以让手机离耳朵远一点，注意听房间里的手表。": "The app pauses its own phone-finding feedback while sending alerts, but iOS notifications may still sound on the phone. Hold it away from your ears and listen for the watch in the room.",
        "设备收藏与隐私": "Saved devices and privacy",
        "只添加你自己的设备。昵称、常放位置、测试结果和最后位置保存在本机；移出收藏可删除该设备的记录。系统蓝牙标识可能变化，名称相同不代表同一设备。": "Only add your own devices. Nicknames, usual locations, test results and last-location records stay on this phone. Removing a saved device deletes its records. Bluetooth identifiers may change; a matching name does not prove identity.",
        "本 App 无账号、广告或自建服务器。地图由系统地图提供；诊断分享由你主动操作，可能包含设备名称和蓝牙标识，请先检查。删除 App 会移除本机数据，系统备份由你的 iOS 设置管理。": "No account, ads or custom server. Maps use the system map service. You choose whether to share diagnostics, which may include device names and Bluetooth identifiers; review first. Deleting the app removes local data; iOS settings govern system backups.",
        "通知转发由 iOS 决定，可能同时提醒其他已配对配件，不能指定只向收藏的某一块表发送。其他品牌及耳机的响铃能力必须逐项验证。": "iOS controls notification forwarding and may alert other paired accessories too. It cannot target only one saved watch. Other brands and headphone alert support must be tested individually.",
        "随手寻是开发中的独立工具，与 Suunto 或其他设备品牌无隶属关系。": "Nearby Finder is an independent tool in development, with no affiliation to Suunto or other device brands.",
        "关于固件": "About firmware",
        "增加固件逻辑不能凭空增加天线阵列或 UWB 硬件。若将来确认芯片支持专用测向信号，还需要接收端硬件和可用接口配合。目前没有可验证的这块表的固件测向或音量接口，不会把猜测命令写入手表。": "Firmware cannot add missing antenna arrays or UWB hardware. Even a supported direction-finding radio would need compatible receiver hardware and accessible APIs. No verified direction or volume interface is available for this watch; the app does not write guessed commands to it.",
        "寻找指引": "Finding guide",
        "这次信号：{0}": "Signal time: {0}",
        "将十字中心对齐这次信号发生时，手机实际所在的位置。可先搜索地点，再拖动微调；不要把现在的位置误当成历史位置。": "Move the crosshair to where the phone actually was at the shown signal time. Search, then drag to refine. Do not confuse your current location with a historical one.",
        "搜索地点或地址（发送给 Apple 地图）": "Search place or address (sent to Apple Maps)",
        "搜索": "Search",
        "地图地点": "Map location",
        "位置备注，例如公司三楼会议室": "Location note, e.g. office meeting room",
        "我确认此处对应上述信号发生时的手机位置": "I confirm this was the phone's location at the shown signal time",
        "保留原始定位；有对应手机定位时，同时校正附近后续自动记录的地图显示。仅有历史手动点时需重新取得定位再对齐。": "Raw evidence is retained. With a corresponding phone fix, nearby future map records can also be corrected. A manual-only historical point needs a fresh fix before realignment.",
        "手动对齐／确认位置": "Align / Confirm location",
        "保存参考": "Save reference",
        "搜索中…": "Searching…",
        "未找到地点，请换一个更具体的地址": "No places found. Try a more specific address.",
        "选择结果后仍需拖动地图并亲自确认": "Select a result, then refine the map and confirm the location yourself.",
        "地图搜索暂不可用，仍可手动拖动地图": "Map search is unavailable. You can still drag the map manually.",
        "自动记录位置": "Automatic location record",
        "随手寻 · V0.13（开发版）": "Nearby Finder · V0.13 Preview",
        "语言": "Language",
        "切换语言": "Change language",
        "中文": "Chinese",
        "英文": "English"
    ]
    private struct Template {
        let key: String
        let expression: NSRegularExpression
        let value: String
        let localizedValues: Bool
    }
    private static let slot = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
    private static let templates: [Template] = english.compactMap { key, value in
        let range = NSRange(key.startIndex..., in: key)
        let slots = slot.matches(in: key, range: range)
        guard !slots.isEmpty else { return nil }
        var pattern = "^", cursor = key.startIndex
        for match in slots {
            guard let token = Range(match.range, in: key) else { return nil }
            pattern += NSRegularExpression.escapedPattern(for: String(key[cursor..<token.lowerBound])) + "(.*?)"
            cursor = token.upperBound
        }
        pattern += NSRegularExpression.escapedPattern(for: String(key[cursor...])) + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let localValues = key == "记录{0}采样点" || key == "{0}路线采样信号最强，优先回到该采样点附近响铃确认" || key == "通知提醒：{0}"
        return Template(key: key, expression: expression, value: value, localizedValues: localValues)
    }.sorted { $0.key.count > $1.key.count }

    static func text(_ source: String, language: AppLanguage) -> String {
        guard language == .english else { return source }
        if let direct = english[source] { return direct }
        for template in templates {
            guard let match = template.expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { continue }
            var result = template.value
            // Replace slots back to front so user text containing a slot token is never reinterpreted.
            for token in slot.matches(in: template.value, range: NSRange(template.value.startIndex..., in: template.value)).reversed() {
                guard let numberRange = Range(token.range(at: 1), in: template.value),
                      let index = Int(template.value[numberRange]), index + 1 < match.numberOfRanges,
                      let capturedRange = Range(match.range(at: index + 1), in: source),
                      let destination = Range(token.range, in: result) else { continue }
                let captured = String(source[capturedRange])
                result.replaceSubrange(destination, with: template.localizedValues ? english[captured] ?? captured : captured)
            }
            return result
        }
        // User-supplied names, notes and unknown device strings must not be modified.
        return source
    }
}
