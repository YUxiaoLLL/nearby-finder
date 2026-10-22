# Validation / 验证范围

V0.10 source preview, 2026-10-22.

Logic checks cover signal filtering, stale signal, source isolation, trigger dwell, four-notification timing, route comparison, collection migration and UUID isolation, plus:

- Location fixes must be from the current sampling session, no more than three seconds old, finite and within the strict reported uncertainty limit.
- At least five samples over six seconds; bursts, gaps and coordinate jumps restart or reject the location window. A longer stable window is available for rapid large changes.
- No system-uncertainty improvement is claimed through smoothing.
- Manual references encode/decode with the original signal time, confirmation time and notes; identity is checked against the selected device. They have no expiration rule.
- Existing categories still decode; new stylus/mouse/keyboard categories round-trip correctly.

Public source copy: run `bash Check.command` for logic checks and an unsigned generic iOS build. Prior hardware results apply only to the author's Suunto 9 Peak Pro setup. Tests cannot prove real-world location accuracy, notification delivery or audibility.

V0.10 hardware regression remains pending: category layout, manual map searching/panning, persistence after restarting and waiting a day, GPS drift indoors, per-device isolation, blocked permissions and notification regression. No signed installation or firmware changes are claimed.

本版必须真机核对：自动记录的历史时间、手动对齐保存与重启保留、独立设备隔离和实际地点。不能把系统报告的不确定范围当作真实误差保证。
