# Analytics events

Events go through `AnalyticsFacade` (`lib/services/analytics/`) to Firebase (release builds) and the
debug logger. Parameters are closed sets of codes, never note content, queries, tokens or error text;
see `analytics_client.dart`. `test/analytics_wire_shape_test.dart` pins names and parameter keys.

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
