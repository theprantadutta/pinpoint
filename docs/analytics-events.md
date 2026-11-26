# Analytics events

Events go through `AnalyticsFacade` (`lib/services/analytics/`) to Firebase (release builds) and the
debug logger. Parameters are closed sets of codes, never note content, queries, tokens or error text;
see `analytics_client.dart`. Booleans are sent as the strings
`'true'` / `'false'`, since Firebase accepts only strings and numbers. `test/analytics_wire_shape_test.dart` pins names and parameter keys.

## First run

The write-first first run (Nov 2026): one onboarding page whose two buttons sit above "By continuing
you agree to the Terms and Privacy Policy". **Get started** agrees, starts guest mode and opens a
blank note; **Log in** agrees and opens the sign-in screen. There is no terms checkbox screen any
more. Code: `lib/screens/onboarding_screen.dart`, `lib/services/first_run.dart`.

Funnel, in order:

| Event | Parameters | Meaning |
| --- | --- | --- |
| `first_open` | (Firebase automatic) | App opened for the first time after install. |
| `onboarding_choice` | `choice`: `get_started` \| `log_in` | An onboarding button was tapped. Fires before anything else in the flow. |
| `onboarding_complete` | none | Onboarding finished for the first time on this install. Not repeated for an older install sent back to the page because it never agreed to the terms. |
| `terms_accepted` | `method`: `inline` | Agreement recorded by tapping either onboarding button under the consent line. (Before Nov 2026 it came from the checkbox screen and had no parameter.) |
| `guest_started` | `source`: `onboarding` \| `auth_screen` | Guest mode began, from Get started or from "Continue without account" on the sign-in screen. |
| `first_note_created` | `note_type` | The first note saved after onboarding (armed by onboarding, reported once). |
| `guest_converted` | `method`: `google` \| `apple` \| `email`; `entry`: see below | Someone who was a guest signed in or signed up. Fires once, right after the backend accepts the sign-in (also for zero-knowledge accounts that go on to the unlock screen). Not fired for account-linking flows. |
| `sign_up` / `login` | `method` | Existing auth events, fired for every sign-in, guest or not. |

`guest_converted` `entry` (where the sign-in screen was opened from, carried as `/auth?from=…`;
`AuthEntry` in `analytics_client.dart`):

- `home_banner`: the guest banner on the home screen
- `paywall`: "Sign in to buy" on the subscription screen
- `settings`: the sign-in card at the top of Settings
- `backup_screen`: the signed-out Backups screen
- `onboarding_log_in`: onboarding's Log in. That person is not a guest, so `guest_converted` does
  not fire for them; the value exists so every route into sign-in is named
- `other`: anything else, including an unknown value

The sync screen has no sign-in entry point today; add a value to `AuthEntry` if one is added.

User property:

- `first_run_flow` = `write_first`: set when someone goes through this onboarding (either button).
  Installs from before Nov 2026 never have it, so cohorts can be compared.

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

## Sync

| Event | Parameters | When |
| --- | --- | --- |
| `sync_started` | none | `SyncManager` began a sync (note save, reconnect, sign-in, sync screen). |
| `sync_completed` | none | The sync succeeded. |
| `sync_failed` | `reason`: see below | The sync failed, or the account key was not ready. |

`reason` comes from `syncFailureReasons` in `lib/sync/sync_failure_reason.dart`, classified from
the error's type and HTTP status, never from its text when an error object exists:

- `offline`: no route to the server (no network, DNS failure, connection refused or dropped)
- `timeout`: connecting, sending or waiting for the answer took too long
- `unauthorized`: 401
- `limit`: a plan limit stopped the sync
- `rate_limited`: 429
- `encryption_key`: the account's key is not on this device yet
- `rejected`: any other 4xx
- `server_error`: a 5xx from the API, or from Cloudflare in front of it (52x)
- `unknown`: anything else, such as a local database or decryption error

**Changed 26 Nov 2026 (after 4.4.0):** the reason used to be read from the error text, and
ApiService's no-network message "Unable to connect to server." contained "server". Up to and
including 4.4.0, `server_error` therefore means mostly *offline* (or a slow answer), and real 500s
were reported as `unknown`; `timeout`, `rate_limited` and `rejected` did not exist. Production
logs for 28 Oct to 26 Nov showed no 5xx on any sync endpoint.

## GA4 custom dimensions

Registered on 24 Nov 2026 in GA4 property `p512318286` (Admin → Custom definitions), so these
parameters can be used in reports and explorations. Data exists only from that date on.

| Dimension | Scope | Parameter / property |
| --- | --- | --- |
| Onboarding choice | Event | `choice` |
| Source | Event | `source` |
| Sign in method | Event | `method` |
| Auth entry | Event | `entry` |
| Prompt attempt | Event | `attempt` |
| Prompt trigger | Event | `trigger` |
| Prompt outcome | Event | `outcome` |
| Permission granted | Event | `granted` |
| Notes bucket | Event | `notes_bucket` |
| Reason | Event | `reason` |
| Note type | Event | `note_type` |
| First run flow | User | `first_run_flow` |

A new parameter needs its own dimension here before it shows up in reports.
