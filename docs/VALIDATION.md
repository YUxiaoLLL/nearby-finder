# Validation / 验证范围

V0.9 source preview, 2026-10-21.

Logic checks cover invalid RSSI, filtering and trends, stale signal, source isolation, threshold dwell/hysteresis, four-notification timing contract, location quality/time association, local map alignment limits, route sampling, library migration/persistence/removal and UUID matching.

逻辑检查不能证明通知真的送达或响铃，也不能证明地图位置准确。Tests do not prove notification delivery, audible sound or location accuracy.

The original development build passed unsigned generic iOS compilation. The sanitized public source copy also passed all logic checks and an unsigned generic iOS build. / 已脱敏的公开源码副本也已独立通过全部逻辑检查与未签名 iOS 构建。

Hardware regression pending for V0.9 UI centering, multi-device switching, iPad layout, Bluetooth restoration and lock-screen notification behavior. Simulator services were unavailable in the preparation environment; no simulator screenshot or hardware success is claimed. / V0.9 界面与蓝牙真机回归待完成。
