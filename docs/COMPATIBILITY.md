# 兼容性 / Compatibility

Updated / 更新：2026-10-22。This is an evidence log, not a universal support list. / 此表记录证据，不承诺全品牌兼容。

**作者已有真机结果 ≠ 多人认证；文档候选 ≠ 已支持。Prior author testing is not broad certification; a research candidate is not supported hardware.**

| Device / 型号 | Signal / 信号 | Alerts / 提醒 | Evidence & status / 证据与状态 |
|---|---|---|---|
| Suunto 9 Peak Pro | 作者已测试 / Author tested | 前台和锁屏下通知转发曾发声 / Forwarded notifications sounded in foreground and locked-phone tests | 唯一已有实际结果的型号；V0.9 仍需回归 / Only model with prior hardware results; V0.10 regression pending |
| Fitbit Inspire 3, Charge 5 / 6 | 未测试 / Untested | 未测试 / Untested | 官方失物帮助推荐蓝牙定位工具；具体型号能力待核实 / Official lost-device guidance suggests Bluetooth locators; model-specific behavior unverified |
| Polar Pacer / Pacer Pro, Vantage M2 | 未测试 / Untested | 不承诺声音；文档描述通知振动 / No sound claim; documented notification vibration | 文档候选 / Research candidates |
| Casio G-SHOCK GBD-200 | 未测试 / Untested | 不承诺声音；文档有通知振动 / No sound claim; notification vibration documented | 广播与连接条件待测试 / Advertising and connection conditions untested |
| Apple Pencil / styluses · 触控笔 | Untested; generation, host and sleep state matter / 未验证，受代际、主机与休眠影响 | No ringing support / 无发声控制 | Pencil Pro: use Apple Find My first / Pro 优先官方查找 |
| Headphones · 耳机 | Untested; case and sleep may hide the signal / 未验证，盒内可能不可见 | No universal ring command / 无通用响铃 | Supported AirPods: use Find My first / 支持的 AirPods 优先查找 |
| Bluetooth mice · 蓝牙鼠标 | Untested; BLE visibility required / 未验证，需 BLE 可见 | None / 无 | Sleeping / host-connected / proprietary receiver may be invisible / 休眠、连接主机、专用接收器可能不可见 |
| Bluetooth keyboards · 蓝牙键盘 | Untested; BLE visibility required / 未验证，需 BLE 可见 | None / 无 | Category support is organizational, not hardware certification / 类别仅为分类管理 |
| Other BLE devices · 其他物品 | Untested / 未验证 | No universal ringing / 无通用响铃 | Experimental only / 实验性流程 |

## 官方资料 / Official sources

- [Fitbit lost-device help](https://support.google.com/googlehealth/answer/14236530?hl=en-AO): recommends trying a Bluetooth locator. Does not prove every listed model works here. / 不证明本项目兼容每个型号。
- [Polar Pacer Pro notifications](https://support.polar.com/e_manuals/pacer-pro/polar-pacer-pro-user-manual-english/phone-notifications.htm), [Vantage M2 settings](https://support.polar.com/e_manuals/vantage-m2/polar-vantage-m2-user-manual-english/general-settings.htm).
- [Casio GBD-200](https://gshock.casio.com/us/products/gshock-move/gbd-200/), [manual 3506](https://www.casio.com/content/dam/casio/global/support/manuals/watches/pdf/35/3506/qw3506_EN.pdf). Phone Finder is watch-to-phone; it is not evidence of phone-to-watch finding. / 手表找手机不等于手机找手表。

Not finding a reverse-finder feature in inspected documents does **not** establish its absence. / 未在查阅资料中找到反向找表入口，不等于证明不存在。

## 已有其他找回方式 / Existing alternatives

- [COROS Find My Watch](https://support.coros.com/hc/en-us/articles/6174368045588-Find-My-Phone-Find-My-Watch): many models already support finding from the official app.
- [Fitbit Inspire 2 with Tile](https://blog.google/products-and-platforms/devices/fitbit/inspire-2-findable-with-tile/): existing finding integration.
- [Apple Watch Find My](https://support.apple.com/en-ie/101558): built-in alternative.

不将这些设备宣传为“没有找回功能”。This project does not claim these devices lack finding features.

## 提交实测结果 / Submit a test report

Use the compatibility Issue template. Include model, firmware, iOS, app version, discovery conditions, sustained RSSI, foreground/locked alerts, sound versus vibration, official-app coexistence and whether this was a controlled or real search. Hardware reports require actual testing, not inferred Bluetooth-version support.

请隐藏序列号、蓝牙标识、坐标与通知内容。Redact serials, Bluetooth identifiers, coordinates and notification contents.
