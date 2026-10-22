# Privacy / 隐私

Current source preview / 当前源码预览，2026-10-21。This describes the current code, not a hosted App Store policy. / 此文描述当前代码，不是已发布商店隐私政策。

- No account, ads, analytics SDK or application-operated backend. / 无账号、广告、分析 SDK 或自建服务端。
- Names, identifiers, nicknames, categories, storage notes, alert test results, signal timestamps and optional phone location records are stored locally. iOS backups follow the user's settings. / 收藏、标识、备注和可选手机位置本机保存；系统备份服从 iOS 设置。
- Bluetooth is used for discovery, connection and signal readings. Location is optional, foreground-only and records the phone's position. Notifications assist user-triggered alerts. System maps use Apple's map services. / 蓝牙用于发现连接和信号；定位按需前台使用，记录手机位置；地图使用系统服务。
- Diagnostic events stay on-device unless the user explicitly shares them. They can contain device names, Bluetooth identifiers and advertising data; inspect and redact before sharing. Raw location coordinates are not written to diagnostic events. / 日志可能包含设备信息，分享前检查并脱敏；不向事件日志写入原始定位坐标。
- Removing a device deletes its saved entry and device-specific location/alert settings. Current session logs are not immediately removed; restarting clears the in-memory event list. Exported files and previously shared copies require separate deletion. System Bluetooth pairing is managed in iOS Settings. / 移出收藏不立即清除会话日志或已导出的副本，也不解除系统配对。
- Removing the app clears its local app data; manage backups separately in iOS. / 删除 App 清除本机 App 数据，备份另行管理。

Please do not put private diagnostics in public GitHub Issues. / 请勿在公开 Issue 发布私人诊断数据。

V0.10: Manual reference coordinates, corresponding signal timestamps and room/floor notes are stored separately on the device. A manual map/address search sends the entered query to Apple Maps; this app does not send it to an app-operated server. Removing a device clears automatic, manual, legacy alignment and paused-recording preferences. / 手动参考独立本机保存；地图搜索将输入内容发送给 Apple 地图；移出收藏删除该件物品的全部位置参考与设置。
