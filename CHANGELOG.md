# Changelog

## V0.13 — English / Simplified Chinese

- Add a top-left globe menu with English and Simplified Chinese choices, applied immediately and remembered across launches. Initial language follows supported iOS language preferences.
- Translate live signal/connection states, device categories, watch alert controls, location details, guides and newly scheduled notifications. Format in-app dates using the selected locale.
- Preserve device identities, categories in storage, user nicknames/notes and raw diagnostic evidence. Existing scheduled notifications retain their original text; system dialogs and map labels follow iOS/provider settings.
- Keep the finder model alive across language changes and prevent a language change from restarting a paused search.
- Add regression coverage for saved-language resolution, dynamic values, localized enum labels, translation placeholder parity and user-text preservation.


## V0.12 — verified system-map coordinate pipeline

- A physical iPhone investigation found a roughly 626m difference between Core Location and MapKit location coordinates in the tested map environment. Raw callback values were preserved; plotting them directly mixed coordinate spaces.
- Match public same-phone Core Location and MapKit samples with bounded time/accuracy checks; preserve raw and map coordinates separately. No guessed global coordinate conversion or location upload is used.
- Queue slightly predictive MapKit timestamps for up to two seconds, but pair them only after their timestamp has arrived. Signal/location timing checks remain unchanged.
- Retire unverified V0.11 manual offsets without deleting historical confirmations; do not stack manual and system map corrections.
- Add local coordinate and actual annotation checks, replacing the misleading second raw-coordinate map.
- Verified on a physical iPhone in the normal UI: matching samples, automatic map-coordinate persistence, and zero stored-map-to-annotation coordinate difference. This verifies software consistency, not absolute GPS accuracy.


## V0.11 — automatic location and local alignment

- Show one primary location map; keep raw evidence and controls in details.
- Start location permission flow during an explicit search unless recording was disabled.
- Save fresh qualifying system fixes without requiring five rapid callbacks. Keep freshness, signal timing, accuracy and jump checks.
- Apply device-local manual map alignment to subsequent automatic records within 500m of its raw anchor; preserve raw GPS and provide reset. Reject mismatched historical evidence and corrections over 2km.
- Resume old per-device paused sampling states; explicit global off remains respected.
- Add regression checks for first-fix recording, jump protection and persistent, device-isolated local correction.
- Generic iOS build and policy checks passed; physical-device location accuracy still requires testing.


## 0.10.0 — Categories and location references

- Add stylus / Apple Pencil, mouse and keyboard categories, grouped collections and capability notes. New categories are not hardware compatibility claims.
- Make manual map confirmation visible without requiring a live GPS fix or active scan when signal history exists.
- Save manual historical references separately, with timestamps and room/floor notes; no silent expiration or automatic overwrite.
- Reject stale / coarse / jumping phone fixes, require stable samples and tight signal association. Mark questionable automatic records and pause updates until explicitly retried.
- Preserve original automatic records; do not apply guessed datum conversions or claim accurate item coordinates.
- Add category research and location regression guidance. Physical-device verification remains pending.


## 0.9.0 — Source preview

- Center the signal ring within its container.
- Add a local multi-device library with nicknames, categories, storage notes and user-recorded alert test status.
- Match saved targets by Bluetooth UUID, keep per-device last-signal metadata and restore the selected record on launch.
- Preserve smoothed signal trends, route sampling, optional phone last location and finite notification assistance.
- No physical meter estimates, measured bearing, universal ringing or offline tracking claims.
- Add bilingual documentation, compatibility reports and a source build workflow.

V0.9 physical-device regression remains pending. Prior Suunto 9 Peak Pro tests do not certify the new multi-device flows or other models.

Validation: public source copy passed `bash Check.command` (logic checks and unsigned generic iOS build). Personal signing Team, build logs and private development backups are excluded from publication.
