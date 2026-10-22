# Location references in V0.11

The default flow is **automatic phone location → map → manual alignment if incorrect**. Pairing does not supply the watch's coordinates. Location records belong to the phone around a valid Bluetooth sighting; they are search references, not live item tracking.

## Recording

An explicit foreground search requests location permission if needed. An explicit recording-off preference remains respected. Fresh full-accuracy fixes from this session with reported uncertainty ≤20m may be recorded immediately when associated with a current signal within three seconds. This fixes V0.10's dependence on five rapid callbacks. Invalid, stale, after-signal and coarse fixes are rejected. A detected cluster jump waits for stable evidence; a large quick change from the saved record waits longer. Indoor fixes can still be wrong despite a small reported uncertainty.

## Manual alignment

Use “位置不准？手动对齐” and confirm the actual phone position for the shown signal time. A matching raw phone fix establishes a persistent display correction for this device within 500m of that raw anchor. Subsequent automatic records retain their motion relative to that anchor; they are not frozen at the manually selected point. Outside that area the app explicitly uses system coordinates. Corrections greater than 2km are not applied automatically. Raw GPS remains unchanged; reset is under location details.

A manual-only historical point remains available, but cannot define an offset without a corresponding real phone fix. V0.10 confirmations migrate to correction only when their signal time matches the saved raw evidence within three seconds. Otherwise obtain a fresh signal and location and align again. We do not assume two positions taken many minutes apart describe the same place.

No guessed country-wide datum conversion is applied. Map alignment changes display, not GPS accuracy, and cannot establish room/floor or the item's own position.

## Device testing

1. Allow precise location, start searching and verify a new map timestamp at a known place.
2. Align the shown phone position, then walk nearby: new automatic records should retain the correction while moving.
3. Restart, switch between devices, reset alignment and leave the 500m region; verify state labels and isolation.
4. Deny permission / disable recording / stop searching: no new location should be invented; historical references remain.
5. Retest signal trends and the four notification reminders at 5/10/15/20 seconds.

Policy regression checks and unsigned generic iOS builds pass. Actual GPS accuracy and notification delivery must be tested on a physical phone/watch.
