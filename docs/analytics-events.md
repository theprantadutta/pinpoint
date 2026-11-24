# Analytics events

Events go through `AnalyticsFacade` to both `FirebaseAnalyticsClient` and
`LoggerAnalyticsClient` (debug console), which must emit the same names and
parameter keys (`test/analytics_wire_shape_test.dart`). Parameter values are a
closed set. Nothing carries note content. Booleans are sent as the strings
`'true'` / `'false'`, since Firebase accepts only strings and numbers.

## Notifications and rating

Added Nov 2026 (4.3.x), when the notification ask moved from the first visit
home to after the second note, and the review prompt moved from cold start to
after a saved note.

| Event | Parameters | When |
| --- | --- | --- |
| `notification_prompt_shown` | `attempt`: `first` \| `reask`; `trigger`: `note_saved` | The notification sheet opens. It is due once the person has 2+ notes, right after a new note is saved in the full-screen editor and they are back on the home shell. `reask` is the single second ask, 7+ days after a first "not now". |
| `notification_permission_result` | `outcome`: `enabled` \| `not_now` \| `dismissed`; `granted`: `true` \| `false` | The sheet closes. `dismissed` is a drag or a tap outside, `not_now` the button. `granted` is the system dialog's answer, `false` when it was not shown. **Changed:** before this release `granted` meant "tapped Turn on" and there was no `outcome`. |
| `reminder_permission_requested` | `granted`: `true` \| `false` | Picking a reminder time found notifications off and asked the system. Not sent when notifications are already on. |
| `review_prompt_requested` | `notes_bucket`: `5-9` \| `10-24` \| `25+` | The review gate passed (5+ notes, 3+ days since first use, 90 days since the last request) and `requestReview()` was called. The OS may still show nothing. |
| `nudge_scheduled` | none | The opt-in come-back nudge (one local notification two days later, 10:00) was scheduled from the notification sheet. |

Useful funnels: `first_note_created` → `notification_prompt_shown` →
`notification_permission_result{outcome=enabled, granted=true}` →
`nudge_scheduled`. Compare D1 and D7 retention before and after this release.
