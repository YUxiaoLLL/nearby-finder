# Nearby Finder

**Find your nearby Bluetooth belongings, one step at a time.**

**Your watch is still connected, but you cannot find where it is hiding?**

An experimental native iOS app that uses Bluetooth signal trends to narrow your search, with notification-assisted alerts on tested compatible watches. Started as a tool to find the author's Suunto 9 Peak Pro.

[简体中文](README.zh-CN.md) · [Compatibility](docs/COMPATIBILITY.md) · [Privacy](docs/PRIVACY.md) · [Testing](docs/TESTING.md)

> **Status: V0.13 development preview. Source builds only; no public TestFlight or App Store download yet.**
> Documentation is bilingual. The app UI supports English and Simplified Chinese. Use the globe icon at the top left to switch; your choice is remembered. [Watch the 37-second edited demo](https://github.com/YUxiaoLLL/nearby-finder/releases/tag/v0.13.0-demo).

## Why I built this

I started this project after I couldn't find my own **Suunto 9 Peak Pro**. I wanted a practical way to narrow the search with my phone, then try an audible reminder on the watch.

That became Nearby Finder: a small, independent tool built around a real frustration. It started with one watch and is growing through actual device testing—not promises that every Bluetooth device will work.

## Features

- Switch between English and Simplified Chinese with the top-left globe. Live status, guides, categories, date formatting and newly scheduled watch notifications follow the selection. User names and notes are preserved.

- Organize watches, headphones, Apple Pencil / styluses, Bluetooth mice, keyboards and other BLE belongings with nicknames and usual storage places. Categories are organizational labels, not model compatibility guarantees.
- Search one device at a time, only when this app can actually discover or connect to it.
- Observe smoothed signal strength and increasing/decreasing trends.
- Manually compare samples taken along routes you actually walk.
- Try notification-assisted watch alerts at 5, 10, 15 and 20 seconds on compatible setups.
- Automatically record a fresh **phone** location around a valid signal while searching, with location permission. Preserve raw Core Location coordinates and separately match the coordinate space used by the system map from contemporaneous same-phone samples.
- Optional manual alignment remains available. Manual and measured system-map corrections never stack. Unverified legacy offsets are retired while historical confirmations stay accessible. See [location details](docs/LOCATION_FIXES.md).
- Local device and location records, no account, ads or analytics SDK.

## Limitations

- **No precision ranging or bearing.** No meter estimates or measured left/right arrows. The ring represents signal strength only.
- **Not every Bluetooth device works.** It must be powered and discoverable or connectable within range. Sleeping devices, stopped advertising and changing identifiers may prevent finding.
- **No remote or crowdsourced tracking.** Last location is the phone's position, not the watch's GPS. A powered-off or out-of-range device cannot be tracked live.
- **Alerts are not a universal ring command.** iOS notification forwarding depends on pairing, permissions and watch settings, may notify other accessories, and cannot be addressed to a saved UUID. Remote volume control is unavailable.
- Only add and search devices you own.

## Categories and existing alternatives

Apple Pencil Pro and supported AirPods already have Apple Find My features; use those first. Older styluses and other Bluetooth devices may sleep or stop advertising. Mice and keyboards connected to another host, classic Bluetooth devices and proprietary 2.4 GHz receivers may be invisible here. New category names do not mean these models are supported. See [category research](docs/CATEGORY_RESEARCH.md) and [location changes / test checklist](docs/LOCATION_FIXES.md).

## Tested hardware

Only the author's **Suunto 9 Peak Pro** has prior signal and notification-assistance results, including foreground and locked-phone alerts. **V0.13 category and location changes still require full hardware regression.** Other models are research candidates, not supported-device claims. See the [compatibility matrix](docs/COMPATIBILITY.md).

## Build from source

Requires a Mac, full Xcode and a physical iPhone. Project deployment target: iOS 16. A simulator cannot validate Bluetooth behavior.

1. Clone/download this repository and open `SuuntoFinder.xcodeproj`.
2. In Target → Signing & Capabilities, select your own Team and a unique Bundle Identifier. The author's Team has been removed; `org.example.nearbyfinder` is a sample identifier.
3. Select your iPhone and Run, completing normal development setup as required.
4. Allow Bluetooth. Open “添加附近设备” (add nearby device), confirm ownership and save your device, then start searching.
5. Alerts require notification permission and an existing working watch/system notification-forwarding setup. Location permission is optional.

Free personal signing has time and other limitations; it is not a convenient permanent distribution channel. Do not share your Apple ID password or install untrusted profiles.

```sh
bash Check.command
```

Runs logic checks for signal filtering, stale state, routes, trigger conditions, location policies, library migration and identity matching, then an unsigned iOS build. Generated logs are ignored. See [validation scope](docs/VALIDATION.md).

## Feedback and roadmap

Use the Issue templates to report watch model, firmware, iOS and separate signal/alert outcomes. Distinguish a controlled hiding test from a real recovery. Never post coordinates, home addresses, full serial numbers, Bluetooth UUIDs or unreviewed diagnostic logs. See [contributing](CONTRIBUTING.md).

Next: hardware regression → real demo → a small TestFlight group → model-by-model validation → evaluate an App Store release. No release date promised.

## License and brands

[MIT License](LICENSE). Product names identify test hardware only. This independent project is not affiliated with or endorsed by Suunto or other device manufacturers. “Nearby Finder / 随手寻” is a working name.
