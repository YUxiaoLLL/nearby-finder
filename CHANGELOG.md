# Changelog

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
