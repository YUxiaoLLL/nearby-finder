# Testing / 测试

No public TestFlight link yet. The repository currently requires a source build. / 暂无公开 TestFlight，当前需要自行构建。

1. Test a device you own while you still know where it is. Keep a way to recover it. / 先用位置已知的自有设备测试。
2. Record model, firmware, iOS and app version. Allow Bluetooth; verify continuous samples before attempting a search. / 记录版本并先验证连续信号。
3. Try a controlled hiding test in the same room. Move slowly, pause, compare trends; the ring is not meters or bearing. / 房间内受控藏放，缓慢移动停顿观察；圆环不是距离或方向。
4. For a watch with working system notification forwarding, allow app notifications, check watch tones/vibration/DND and test both foreground and locked phone. Stop alerts after finding it. / 已能转发通知的手表分别测试前台与锁屏。
5. Record signal success separately from sound/vibration success. Other paired accessories may also alert. / 信号、声音和振动分开记录。
6. Location is optional and is the phone's location. Test locally, do not share a map of your home. / 手机位置仅为参考，不分享住址地图。
7. Submit a compatibility report without private identifiers. Label real recovery and controlled tests separately. / 脱敏反馈，区分真实找回与受控实验。

V0.9 library checks: add two items, rename, switch, restart, confirm each retains its own signal history metadata/location, then remove one. Test permission denial, Bluetooth off, unavailable device and stale readings. / 多件收藏需验证切换、冷启动、隔离与删除，以及拒绝权限、关闭蓝牙及信号过期。
