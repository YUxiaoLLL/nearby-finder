# Location coordinate pipeline — V0.12

## What the phone test found

The previous implementation saved Core Location coordinates without changing them, then plotted them on MapKit directly or applied a manual offset. On a physical iPhone in the reported map environment, Core Location and MapKit user-location coordinates differed by about 626m. A reported uncertainty of a few meters did not explain this coordinate-space difference. Requiring better GPS precision or permanently moving a manual pin did not resolve the underlying mismatch.

## Current implementation

1. Receive an owned device's valid Bluetooth signal during foreground searching.
2. Preserve a recent qualifying Core Location fix, timestamp and reported uncertainty as raw phone evidence; it must precede the signal and meet the existing three-second association checks.
3. Also observe MapKit's user location in the active app window. Match it to a phone fix within one second, each reporting uncertainty ≤20m. Only past/current timestamps up to ten seconds old can establish a pair.
4. MapKit was observed to emit slightly predictive timestamps. Retain samples up to two seconds ahead, wait for their time to arrive, then attempt pairing. Do not relabel future samples as current.
5. Use the measured local relation to produce a map coordinate, saved separately from the original raw coordinate. The relation is bounded to 500m around its phone anchor and one hour; fresh pairs keep it updated. This is a local measured relation, not a guessed country-wide datum conversion or a GPS accuracy improvement.
6. Pass that map coordinate to the actual annotation and verify that its coordinate matches the input. If no validated map coordinate is available, explain the waiting state instead of drawing a misleading unverified pin.

Raw coordinates, map coordinates, signal/location timing and the annotation check are available in local location details. Neither coordinates nor device logs are uploaded by the app. Explicit developer audit launch modes keep temporary evidence locally; ordinary launch clears temporary audit keys.

## Manual alignment and migration

Manual confirmation remains available and preserves its historical time/note. New manual alignment directly maps raw phone evidence to a selected map point; it replaces, rather than stacks on, the system-map relation. V0.11 offsets had no verified map-coordinate provenance and no longer apply automatically. Their historical manual references remain accessible. Clearing a device's location data removes its raw/map records and matching cache.

## Validation and limits

- Physical iPhone test in the normal UI produced paired system samples and automatic records with a separate map-coordinate source.
- Final saved map coordinate and actual annotation coordinate matched exactly. Comparison with the latest system-map blue point was within a meter in the stationary test; this is software consistency, not sub-meter real-world positioning.
- Policy checks cover predictive timestamps, future/stale rejection, paired timing/accuracy, raw preservation, identity mapping, regional/age limits, plus existing signal/notification/device-library behavior.
- Different regions, map environments, moving routes, permission changes and background/resume still need broader physical-device coverage. Indoor phone positioning can be wrong and does not establish the item's own location, room or floor.
