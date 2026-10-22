# Location references in V0.10 / 位置参考

A Bluetooth device does not provide its coordinates here. Every automatic point is the **phone's** position around a valid signal. Indoor GPS can be systematically wrong even when reported uncertainty looks small. We cannot guarantee an exact last device location.

## Changes

- Manual map confirmation is visible directly, not hidden behind live-scan or GPS-quality requirements. A current or historical signal context is required; there is no fabricated location for a never-observed item.
- Manual confirmation saves a separate historical point, note and timestamps. It does not silently expire, overwrite raw GPS or get replaced by automatic updates. If you move the item, update or remove the old reference.
- Automatic recording requires fresh fixes from this sampling session, reported uncertainty ≤20m, at least five samples over six stable seconds and location/signal association within three seconds. Gaps and jumps restart the window. Large quick changes wait longer.
- Mark a wrong automatic point to pause updates; explicitly retry collection to resume. User-confirmed references remain available.
- Existing automatic records are labeled as older evidence. A legacy alignment is migrated only when it can be associated with the saved evidence; no local offset is applied to arbitrary future fixes.
- No guessed WGS84/GCJ02 conversion is added. [Apple coordinates](https://developer.apple.com/documentation/corelocation/cllocationcoordinate2d) use WGS84; blind conversion may add another error. [horizontalAccuracy](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy) is reported uncertainty, not an accuracy guarantee.

## Physical-device checklist

1. At a known real place, compare timestamps and the app's automatic phone reference with Apple Maps; two map displays sharing a wrong system fix are not proof of accuracy.
2. Open manual confirmation, search or pan to the known phone position for the shown signal time, add a room/floor note, confirm and save. Restart and recheck the next day. No GPS uncertainty circle is shown for a manual point.
3. Receive new signals elsewhere: automatic history may update, but manual history must keep its own original time and note. Never treat an old manual point as the live item location.
4. Mark an automatic record wrong; ensure it pauses rather than immediately replacing the warning. Retry collection and wait for new stable samples.
5. Switch two owned devices, verify independent records and remove one; no records or settings may leak across identities.
6. With no prior signal, or when automatic sampling fails, no accurate-looking automatic point should be invented. After a valid signal, manual confirmation can still be used without a qualifying GPS fix.

手动点与自动点分别保存并显示历史时间。新增类别不会提供 Apple Find My 网络数据、室内房间或楼层定位。已确认的软件入口及记录问题已改进；用户报告的大偏移尚需真机重现，不能声称其根因已被完全定位或 GPS 已达到绝对准确。
