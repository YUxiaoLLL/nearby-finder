# Category research / 扩展品类调研

2026-10-22. Qualitative research, not a market-size or revenue forecast. / 定性调研，不是规模或收入预测。

| Category | Demand / competition | Opportunity and constraints |
|---|---|---|
| Sports watches | The project started with an actual Suunto owner's need | Highest priority: finish V0.10 regression on the tested 9 Peak Pro |
| Apple Pencil / styluses | Existing locator apps target this problem; Pencil Pro already has Find My | Test older generations / third-party styluses; sleep and iPad pairing may block iPhone discovery. No model compatibility claimed |
| Headphones | Established locator competitors; AirPods have a strong native alternative | Test non-Apple models, signal workflow and storage notes; closed cases, power-off and sleep may hide signals |
| Bluetooth mice / keyboards | Mobile-workspace storage is a hypothesis to validate | Lower priority; sleeping or host-connected peripherals and proprietary 2.4 GHz receivers may be invisible. No universal ringing |

V0.10 adds these organizational categories, capability notes and official-guidance links. It does not add Apple Find My network access, guaranteed BLE discovery, classic Bluetooth enumeration or a universal alert command. Only the author's Suunto 9 Peak Pro has prior hardware results.

## Evidence / 证据

- [Apple Pencil Pro specs](https://support.apple.com/en-euro/120123) and [Find My feature list](https://support.apple.com/en-ca/126302): Pro has native finding; exact availability depends on system/device/region.
- [Apple AirPods finding guide](https://support.apple.com/en-gb/109020): prefer native tools on supported models. Their existence is competition, not proof our app is compatible.
- [Wunderfind](https://apps.apple.com/us/app/wunderfind-find-lost-device/id1458601441) markets finding headphones and Apple Pencil. Its [reviews](https://apps.apple.com/us/app/wunderfind-find-lost-device/id1458601441?see-all=reviews) include both successes and discovery failures: useful leads, not a reliable success-rate estimate.
- [Logitech product overview](https://www.logitech.com/content/dam/logitech/en/business/landing/workspace-wins-brochure-full.pdf): Bluetooth, proprietary receivers and power-saving sleep differ across products.

## Location reference / 位置参考

A last record is the phone's position at a valid signal, not the item's GPS. Automatic samples must be recent and stable; system-reported uncertainty cannot guarantee real-world accuracy. Manual map references are explicit historical user confirmations, saved separately and never silently expired or overwritten. Room/floor notes help silent items, but do not constitute automatic room-level positioning.

本版增加六类的分类管理，不代表所有型号可被 iPhone 发现。无声物品可结合常放位置、稳定信号和已记录的手机位置参考；无法补回从未记录的历史。手动点由用户确认，不能作为 GPS 已准确的证明。

## Next evidence to collect / 下一步

Borrow one exact Pencil generation, one non-Apple headset, one BLE mouse and one BLE keyboard. Test while awake, after five minutes idle, connected to the normal host and after reconnection. Record sustained RSSI and independent finding success; do not infer support from the Bluetooth version or device name. No need to purchase a full set before testing demand.
