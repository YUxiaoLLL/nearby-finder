# V0.12 validation

Policy regression checks and unsigned generic iOS builds pass. A signed build was installed on the connected physical iPhone without changing the app identifier or signing team.

Actual-device checks confirmed a Core Location / MapKit coordinate-space difference of roughly 626m in the tested environment; the new pipeline generated contemporaneously paired samples in the normal UI, preserved raw phone data, stored separate map coordinates, and passed the actual map-annotation coordinate check with zero difference. Near agreement with the latest system blue point is a data-consistency measurement, not an absolute location-accuracy guarantee.

Existing Bluetooth signal, four-reminder timing and device-library policy checks pass; sound delivery and all supported hardware have not been revalidated in this location session. See LOCATION_FIXES.md for limits and wider testing needs.

## V0.13 language update

Native and public-source checks and generic iOS builds pass. Tests cover saved/default language resolution, Chinese/English labels, dynamic countdown and coordinate values, enum labels, placeholder parity and unchanged user notes. Stored device/source identities remain unchanged. The signed update retains the existing app identity. Physical globe-menu tapping and full layout coverage on all screen sizes still need wider testing.
