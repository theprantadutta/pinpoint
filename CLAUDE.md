# Pinpoint — Project Guide for Claude

> The same file is committed to both repos, `pinpoint/` (Flutter app) and `pinpoint-backend/`
> (.NET API), which sit side by side in `G:\Personal\MyProjects\pinpoint\`. Paths below are
> relative to that parent folder unless they start with `lib/`, `test/` or `assets/` (app repo).
> When you change it, copy it to the other repo too so the two stay identical.

## What Pinpoint is

Pinpoint is a **100% Google Keep _feature_ clone** with **end-to-end encryption**.

"Clone" means **feature parity, not pixel parity**. Match how Keep _behaves_ (notes, checklists,
labels, colors, pins, archive, trash, reminders, search, masonry grid, drawer navigation), but the
**UI should be cleaner, borderless, and better than real Keep** — a refined, flat, dark-first design
with a matched light theme. When a feature decision is ambiguous, ask: "what would Google Keep do?"
and then make it look nicer.

Stack: **Flutter** client (`pinpoint/`) + **.NET (ASP.NET Core, net10.0) + PostgreSQL** backend
(`pinpoint-backend/`, solution `pinpoint-backend.sln`, layered Domain / Application / Infrastructure /
Api). Note the hyphen — there is no `pinpoint_backend/` directory, and the backend is **not** Python.

---

## Encryption (authoritative — read before touching notes or sync)

Pinpoint is **client-side / end-to-end encrypted**. This is the single most important architectural
fact and it shapes everything about how features are built.

- **Algorithm:** AES-256-GCM (authenticated; 96-bit random nonce, 128-bit tag) in a versioned
  envelope (`{v: 2, iv, data}`). A legacy AES-CBC read-path exists for old (v1) notes.
- **Where it happens:** entirely on the **client**. The note JSON is serialized and encrypted in
  `lib/sync/api_sync_service.dart`; the cipher lives in `lib/services/encryption_service.dart`.
- **Keys:** a 256-bit data key in `flutter_secure_storage` (iOS Keychain / Android Keystore).
  - **Standard mode (default):** data key also stored on the server so the user can recover it on a
    new device.
  - **Zero-knowledge mode (opt-in):** the data key is **wrapped** with an Argon2id-derived master key
    (from a passphrase) and a recovery-code key; the server stores only the wrapped blobs and can
    never decrypt. See `lib/services/key_wrapping_service.dart` and
    `lib/services/zero_knowledge_service.dart`.
- **At rest on device:** the local SQLite (Drift) DB is encrypted via sqlite3mc.
- **The note table is blind — the system as a whole is not.** `EncryptedNote.EncryptedData`
  (`pinpoint-backend/src/Pinpoint.Domain/Entities/Notes.cs`) holds only ciphertext, plus minimal sync
  metadata (type, `UpdatedAt`, `IsDeleted`): no titles, bodies, checklist items, colors, labels, or
  pin/archive state. But **do not describe the backend as blind in user-facing copy**, because three
  things qualify it:
  1. **Standard mode stores the data key server-side**, so the server *can* decrypt standard-mode
     notes. Only **zero-knowledge mode** — where the key is wrapped by the user's passphrase — makes
     the "we cannot read your notes" claim true.
  2. **Voice recordings synced before June 2026 may be stored unencrypted.** Since then
     (`e9e82ad`) each recording is encrypted on the device with the data key
     (`ApiService.uploadAudioFile` → `encryptBytes`), so it has the same protection as notes in
     each key mode. The download path still accepts unencrypted blobs for those older uploads.
  3. **Reminder title, body and schedule are stored in readable form**, because the server renders and
     sends the push notification.

  Customer-facing copy must say this plainly; see `README.md`, `assets/legal/privacy.md`,
  `GOOGLE_PLAY_SUBSCRIPTIONS.md`, and the backend's `support.html` / `marketing.html`, which are all
  written to match. Analytics are **not anonymous** either — Firebase receives the account ID when the
  user is signed in.

### THE RULE

> **Never move note content or note attributes to the server in plaintext.**
> Title, body, checklist items, **color, labels, pin, archive, reminder linkage** — all of it is
> serialized into the **encrypted payload** and synced as an opaque blob. New note features are added
> by extending the client-side serializer/deserializer in `api_sync_service.dart`, **not** by adding
> queryable columns to the backend note model.

Server-side, only **folders** and **reminders** exist as note-adjacent entities (reminders need
server scheduling for push notifications). Everything else is client-only inside the ciphertext.

When adding a field to the encrypted payload, keep **backward-compatible deserialization** for older
payloads and bump/track a format marker so old and new notes coexist.

---

## The note model (Keep-style, unified)

A note is **one flexible thing**, like Keep — a single note can have a **title**, **body text**, and a
**checklist**, plus attributes: **color**, **labels**, **pin**, **archive**, **trash**, **reminder**.
`Notes.noteType` is a **display hint**, not a rigid type. (`voice`/`reminder` remain special-cased.)
Do not reintroduce rigid, mutually-exclusive note types.

**Subscription model — freemium with limits** (single source of truth: `lib/constants/premium_limits.dart`,
enforced via `lib/services/premium_service.dart`):

- **Free, but capped:** cloud sync (50 notes), folders (5), attachments per note (3, images or any file), voice
  recording (2 min), OCR (20/mo), PDF export (10/mo), accent colors (2). Hitting a cap shows the
  matching `PremiumGateDialog`.
- **Premium = unlimited** versions of the capped features above.

Do **not** re-lock images/voice/OCR/export as fully premium — they are free-with-limits.

> **A `PremiumService` method is not evidence a feature ships.** Audited 2026-08-25: `canUseTemplates`,
> `canUseAdvancedSearch`, `canShareEncrypted` and `canExportMarkdown` all have **zero call sites**.
> Templates, advanced search and encrypted sharing are **not implemented** (the editor's *Share
> Encrypted* item is deliberately disabled and labelled SOON). **Markdown export ships free**, under the
> shared 10/month `canExport()` quota. **Drawing** is unreachable: `DrawingScreen` exists, but its only
> entry point is inside `NoteInputField`, which nothing instantiates — the home FAB still shows a locked
> Drawing entry that leads nowhere, which is an open product decision.
>
> `maxAttachmentsPerNoteForFree` (3) **is enforced** since 4.2.0 (Nov 2026): the editor's attach
> flow (`_addAttachments` in `create_note_screen_v2.dart`) checks it and shows the gate.
> `note_input_field.dart` is still dead code. (`maxVoiceRecordingDurationForFree`, 2 min, *is* now enforced: the
> recorder in `create_note_screen_v2.dart` stops a free user at the cap and shows the gate. The old
> `record_type_content.dart` check is still dead code.) Before describing anything as a paid benefit,
> grep for a live call site — see `pinpoint/docs/premium-conversion-fixes-2026-08-25.md`.

**Prices (1 Nov 2026):** $1.99 monthly, $14.99 yearly, $34.99 lifetime (Play and App Store, all
regions converted from USD). On Play the yearly product's live base plan is **`yearly-p1y`**
(billing period: Yearly, offer `yearly-7-day-free-trial`). The original `pinpoint-premium-yearly`
base plan was created with billing period **Monthly** — the Play form's default — so "Yearly"
charged the yearly price every month; it is deactivated (no paid users were affected). When adding
a base plan, check the billing period. The app picks whichever base plan Play returns.

**Trials exist, and are read from the store — never hardcoded.** The Play Console offers a **7-day**
trial on monthly and on yearly. Those numbers live in the Console, not in the code: an offer
can be changed or withdrawn with no app release, and Play withholds it from anyone who has already used
one. `androidTrialDays()` in `lib/services/purchases/purchase_mapping.dart` derives the length from the
selected offer's zero-priced, non-infinite pricing phase (`billingPeriod`, e.g. `P3D`), and the paywall
renders it through the `subTrialCta` / `subTrialThenPrice` ARB plurals. Never reintroduce a
`getTrialDays()` constant or write "3-day" into copy — the paywall would then promise a trial the user
may not be granted.

**iOS is supported too, and reads per-user eligibility.** `ProductSubscriptionIOS.subscriptionOffers`
carries *every* offer (win-back, promotional **and introductory**), and `SubscriptionOffer.type`
separates them; filter on `type == DiscountOfferType.Introductory && paymentMode ==
PaymentMode.FreeTrial`, then multiply `period.value × unit × periodCount`
(`iosConfiguredTrialDays()`).

Then confirm entitlement with `isEligibleForIntroOfferIOS(subscriptionGroupIdIOS)` — eligibility is per
subscription GROUP, not per product, because using one trial in the group spends it for every plan in
it. This step is not optional: both stores grant a trial only to a user who has not already used one in
that group, so a *configured* offer is not a *granted* one. Play handles this for us by omitting the
offer from the queried product for an ineligible user; StoreKit returns the offer regardless and
answers eligibility separately. `iosTrialDaysIfEligible()` is where the two are combined, kept pure so
the arithmetic is testable.

That per-user fact is also why trial length must **never** come from our backend. A server reading the
store catalogue (App Store Connect API or otherwise) learns what offers exist, never who gets one — it
would promise a free trial to returning subscribers who are charged immediately. Resolution is async
because of the StoreKit call, so the paywall resolves it once on product load rather than during build.

Gating/status is driven by `subscription_tier` on the backend (`free` / `premium` / `premium_yearly` /
`lifetime`, with grace-period handling) and the client `SubscriptionManager`.

**Purchase lifecycle (do not regress this).** `SubscriptionService` is a process-wide singleton that
owns the `purchaseStream` listener for the **lifetime of the app**. It has no public `dispose()` on
purpose — a screen tearing it down used to kill every subsequent purchase in the session. `initialize()`
is idempotent and concurrency-safe; exactly one listener is ever created.
`SubscriptionManager.verifyPurchase()` returns a `PurchaseVerificationResult`, **not** a bool, so a
backend-confirmed sale is distinguishable from a provisional grant. The one conversion event is
`purchase_verified`; it fires only on a confirmed outcome. Guard tests live in
`test/purchase_analytics_test.dart` and `test/subscription_screen_purchase_listener_test.dart`.

**Analytics carry no content.** Search telemetry sends a coarse length bucket, never the query (not
raw, not truncated, not hashed — a search term is note content on an E2EE app). Purchase events carry
`product_id`/`platform` and closed-set reason codes, never tokens, verification data, or exception
strings. See `lib/services/analytics/analytics_client.dart` for the rules.

---

## Architecture pointers

- **Local DB is the source of truth.** Drift (SQLite, encrypted). Schema/entities in `lib/entities/`,
  services in `lib/services/` (`drift_note_service.dart` is the main note CRUD).
- **State:** Provider / `ChangeNotifier`. **Routing:** GoRouter (`lib/navigation/app_navigation.dart`).
- **Sync:** `lib/sync/` (offline-first; encrypt-then-upload, download-then-decrypt).
- **Theme:** `lib/design_system/` (`colors.dart`, `typography.dart`, `theme.dart`, `spacing.dart`,
  `elevations.dart`, `animations.dart`). Theme mode (light/dark/system), accent, font and the
  "Background doodles" toggle live in `ThemeController` and sync across devices
  (`lib/sync/preferences_sync_service.dart`). **Read colours from `context.sketch`
  (`SketchColors`) and text styles from `context.type` (`SketchText`) — never hardcode a hex or a
  brightness.** Anything drawn on a pastel uses `SketchPastels.onPastel` in both themes.
- **Design language: "Sketchbook"** (Oct 2026, see `REDESIGN_NOTES.md`): cream paper / warm black,
  1.5px ink outlines, five flat pastels (yellow, lavender, mint, sky, pink), tilted stickers, a
  floating inverse dock, marker highlights, doodle swooshes. Plus Jakarta Sans (+ Caveat for
  handwriting accents). Flat: the only shadows are `SketchShadows.dock` and `.sticker`. No glass,
  gradients or blur. Build screens from `lib/design_system/components/sketch/` (SketchScaffold,
  SketchCard, SketchChip, PillButton, CircleIconButton, SketchSheet, SketchGroup/SketchRow, …).
  Note colours are the 5 pastels (`NoteSwatch`); Keep-era names map to them at display time.
- **App updates (4.0.0, ported from Snake Classic):** Android uses Play in-app updates via
  `lib/services/update/in_app_update_service.dart` — **flexible by default**, blocking only for a
  release published with update priority ≥ 4, a declined offer snoozed 24h, and an
  "Update downloaded · Restart" pill above the dock. iOS reads `GET /app-release/ios` from the
  backend (`app_release_service.dart`) and shows an optional sheet, or a sheet with no way out
  below `minimum_supported_version`. Every unknown (offline, unparseable) resolves to no prompt.
  Never reintroduce a forced update for every release.
- **Note attachments (4.2.0):** images and any file on text and checklist notes, table
  `NoteAttachmentsV2` (schema v13) keyed by note uuid, files under `<app docs>/attachments/`.
  Offline first: added locally, then `AttachmentSync.pushPending()` (before note sync) encrypts with
  the account data key and uploads via `POST /api/v1/attachments/upload`; `pullMissing()` (after)
  downloads. The payload lists them under `attachments` by FileRunner id; a payload **without** the
  key leaves local attachments alone (older clients). The backend relays ciphertext to FileRunner
  (`filerunner.pranta.dev`, folder `attachments/<userId>`, file `<userId>.ppa`, ownership checked
  from that name) with `FILERUNNER_UPLOAD_KEY`, which must never ship in the app. 50 MB per file.
  Production sets `FILERUNNER_URL=http://filerunner-backend:8000/api` (shared `proxy` network, no
  Cloudflare/Traefik hop); local dev uses the public `https://filerunner.pranta.dev/api`.
  `HANGFIRE_SERVER=off` runs an API-only instance (used to test against production data).
- **Google Drive backups** (all signed-in accounts, free and premium; ported from The Accountant):
  `lib/services/backup/`. A backup is a zip of a plaintext manifest, every note and folder in the
  **sync payload format** (`ApiSyncService.exportAllNotesForBackup` / `importNoteFromBackup`) as one
  encrypted blob, and each voice recording encrypted on its own — all with the **account data key**,
  so only the same account can restore it (the screen says so; signed-out users cannot back up, as
  their key would die with the phone). Restore **merges** (newer wins, nothing deleted) and marks what
  it takes for upload. Drive scope is `drive.file` only; uploads are resumable and streamed from disk.
  Sign-out revokes the Drive grant. Needs the Drive API enabled in the Google Cloud project.
- **Outside capture (4.3.0):** shares, app shortcuts and the Android widget all land in
  `CaptureInbox` (`lib/services/capture/`), which only the home shell empties, so none gets past
  sign-in or unlock. `MainActivity` drops an old intent on a rebuild of a killed app and holds a new
  one until Dart sends `ready` on `com.pranta.pinpoint/capture`. Test with `am kill`, not `force-stop`.
- **Guest mode (4.3.0):** `lib/services/guest_mode.dart`. No sync, no backups. Sign-in needs no key
  migration: notes are protected in the database by its at-rest key, and the data key only applies
  as they leave for the server. Sign-in adopts the account key, or registers the guest key if new.
- **Admin dashboard:** Next.js app in `pinpoint-backend/dashboard/` at
  `pinpoint-dashboard.pranta.dev`, signing in with `ADMIN_EMAIL`/`ADMIN_PASSWORD` like Snake
  Classic's. The app sends `X-Client-Platform` / `X-App-Version` so the backend can record
  `user_activity_days` for it (disclosed in `assets/legal/privacy.md`).
- **Entitlement:** `SubscriptionManager` reads the device record, then (signed in, not premium)
  the account's `/subscription/status`, so Pro follows the account. Android device ids were the
  firmware `Build.ID` until Oct 2026 (shared across phones); new installs use a random id.
  Never grant premium on a device row — use the backend's `grant-premium` tool (account only).
- **First run (4.4.0, write first):** one onboarding page; its two buttons sit above "By continuing
  you agree to the Terms and Privacy Policy" (links open the view-only `TermsAcceptanceScreen`;
  there is no checkbox screen any more). **Get started** records the agreement, starts guest mode
  and opens a blank note; **Log in** goes to sign-in. Logic in `lib/services/first_run.dart`. Sign-in
  is still required to buy Premium, sync or back up.
- **Prompts after a success, never on arrival (4.4.0):** the notification sheet shows once the
  person has 2+ notes, right after a new note is saved and the full-screen editor has closed
  (`NoteSavedMoment`, signalled from the editor's `dispose`: the router notifies while the closing
  editor is still on top). Dismissible, one re-ask after 7 days. Picking a reminder time asks the
  system directly. The review prompt needs 5+ notes, 3+ days since first use and a 90-day cooldown.
- **Session expiry needs a session:** `ApiService` only reports an expired session when a token
  existed, and the redirect (`lib/navigation/session_expiry.dart`) skips splash, onboarding, the
  legal reader and sign-in. Without this, a refused startup request on a fresh install sent the
  first tap on onboarding to the sign-in screen.
- **Analytics:** every event and parameter is listed in `pinpoint/docs/analytics-events.md`, with
  the GA4 custom dimensions registered for them (property `p512318286`). A new parameter needs a
  dimension there before it shows in reports.

---

## Internationalization (in progress)

The app ships **9 locales**, chosen from the countries real users are in: `en` (base),
`es`, `pt` (Brazilian), `it`, `fr`, `th`, `bn`, `ar`, `fa`. `ar` and `fa` are **RTL**.

- **Strings** live in `lib/l10n/app_*.arb`; `AppL10n` is generated into
  `lib/generated/l10n/` (config in `l10n.yaml`). Run `flutter gen-l10n` after editing an
  `.arb`. Missing translations are reported to `l10n_untranslated.json`.
- **Every new `en.arb` entry needs a `description`.** A translator sees only the key and
  that description — never the surrounding screen — so say *where it appears and what it
  does*, and call out brand names that must not be translated.
- **Language selection:** `LocaleController` (`lib/services/locale_controller.dart`),
  mirroring `ThemeController`. Null locale = follow the device.
- **Never build a date with a bare `DateFormat`** — a `DateFormat` with no locale
  silently renders English months and Western digits. Use `lib/util/localized_dates.dart`.
- **Never hand-roll pluralization** (`${n > 1 ? 's' : ''}`) — it is wrong in Arabic,
  Persian and Bengali. Use an ARB `plural` block.
- **RTL:** prefer `EdgeInsetsDirectional` / `AlignmentDirectional` /
  `PositionedDirectional` / `BorderRadiusDirectional`. Where an API only accepts the
  non-directional type (`ScaleTransition.alignment`, `tutorial_coach_mark`'s
  `alignSkip`), branch on `Directionality.of(context)`. Gradient `begin:`/`end:`
  deliberately do **not** mirror.
- **Fonts:** all bundled google_fonts faces are **Latin subsets** and runtime fetching is
  off, so non-Latin scripts need the fallback chain. Every style goes through
  `_font()`/`_mono()` in `design_system/typography.dart`; a test enforces that nothing
  bypasses them. Script faces live in `assets/fonts/scripts/` and are declared under
  pubspec `fonts:` (a `fontFamilyFallback` can only name statically registered families).
  **google_fonts asset filenames must contain no spaces** — `SourceSans3-Regular.ttf`,
  not `Source Sans 3-Regular.ttf`.
- **PDF export** embeds fonts via `lib/services/pdf_font_service.dart`; the PDF base-14
  defaults are Latin-only and draw *nothing* for other scripts.
- **Backend errors:** the server returns stable **error codes** and the client maps them
  to ARB strings. Do not add server-side `Accept-Language` translation for API errors —
  server-side i18n is only for emails and push, where the server renders the text.
- Debug screens are deliberately **left in English**. There is **no in-app admin panel**
  (removed in 4.0.0): administration is the web dashboard in `pinpoint-backend/dashboard/`.

Localization guard tests live in `test/material_ui_localizations_test.dart` and
`test/startup_error_apps_test.dart` (which asserts every supported locale resolves the startup strings).
There is no `test/localization_test.dart` — the typography guard described above is not currently
enforced by a test.

## ACTIVE WORK: retention plan (5 Nov 2026; delete this section when every item is done)

Why: in the 28 days to 4 Nov, 543 first opens, 353 finished onboarding, 299 accepted terms, 218 of 965
users created a note, 383 uninstalled. Work in this order, one branch per item, tests first, check on
the A24 (ask the other sessions if it is free), then merge and push. Offline must keep working.

**On a Mac, start with `pinpoint/docs/ios-mac-checklist-4.3.0.md`:** nothing from 4.2.2 or 4.3.0 has run on iOS.

- [x] 1. (AAB built 5 Nov; onboarding with animations off and the first note event covered by tests only, not on a device) Release 4.2.2: A24 check of the merged crash and analytics fixes (paste, editor scrolling and
      selection handles, onboarding with animations off), add `first_note_created`, bump to 4.2.2+41, AAB
- [x] 2. Shorter first run: one onboarding screen, open a blank note straight after sign-in
- [x] 2b. Toolchain: match AGP, Gradle and other build plugins to `G:\Personal\MyProjects\Gridwell\gridwell_flutter_app`, then `flutter pub upgrade` and `flutter pub upgrade --major-versions`
- [x] 3. (iOS share sheet still needs a Share Extension target, built on a Mac) Share to Pinpoint from other apps (text, links, images) and app shortcuts (New note, Checklist, Voice)
- [x] 4. Home screen quick-capture widget (Android; iOS needs WidgetKit). No note text on the widget: it would sit outside encrypted storage
- [x] 5. (Guest mode in 4.3.0; new-account and other-account sign-in tested by unit tests only) Write before signing in (F9): safe guest-to-account key adoption, regression tests first, never
      lose a key or a note
- [x] 6. One opt-in local nudge on day 2 or 3 for people who wrote a note, with no note content
- [~] 7. Store listings lead with encryption, offline and voice (copy in `pinpoint/docs/store-listing-4.3.0.md`).
      English and new es-419 listing are saved as **drafts** in the Play listing editor but were
      never sent for review (24 Nov 2026); the live page still shows the old copy
- [x] 8. Write-first first run, notification and review prompts after a success, analytics events
      and GA4 custom dimensions: 4.4.0+47, sent to Play review 24 Nov 2026
- [ ] 9. Around 8 Dec 2026: compare the 4.4.0 funnel with 4.3.x (first note, D1/D7, guest_converted,
      notification opt-in) before building more. Baseline, 28 days to 23 Nov: 435 first opens →
      314 onboarding → 254 terms → 116 first notes; 317 uninstalls

## ACTIVE WORK: the 1 November 2026 review (delete this section when every item is done)

Full report: `PinPoint-review-2026-11-01.md` in the parent folder (`G:PersonalMyProjectspinpoint`) (evidence in
`D:\Desktop\CodeReviews\PinPoint\evidence`). Its P0s were verified against the code on 1 Nov:
F1, F2, F3, F7 and the 404 legal links are real. **Work in this order**; one branch per phase, tests
first, device-check on the A24 (`RR8W901JDRL`), then merge and push. Tick items here as they land.

Rules for this work: never ship a fix that can *remove* a user's only usable key or note copy;
anything that changes keys or sync needs a regression test reproducing the failure first; any
migration of existing accounts is read-only audit first, repair second, with the user's approval
before touching the 46.62.254.22 database.

**Phase 0 — quick trust fixes (backend)**
- [x] `/privacy` and `/terms` on pinpoint.pranta.dev redirect (301) to `legal.pranta.dev/pinpoint/…`
- [x] F7a: resource APIs reject tokens with `type=refresh` (JwtBearer `OnTokenValidated`)
- [x] F7b: no `admin/admin` Hangfire fallback; refuse to expose the dashboard without real creds
- [x] F7c: Google RTDN webhook fails closed when the Pub/Sub verification token is not configured
- [x] F11: set `_appStoreId = '6786222392'` in `app_review_service.dart`

**Phase 1 — keys can never be replaced or leaked (P0: F2 + F3)**
- [x] Client: `_getOrCreateKey`/`syncKeyFromCloud` generate a key only after the server *confirms*
      the account has none (404/explicit "no key"); a timeout/5xx leaves recovery pending and retries
- [x] Server: `StoreEncryptionKeyCommand` is create-only — an existing key is never overwritten
      (rotation, if ever, becomes an explicit versioned protocol); validate base64 + 32-byte length
- [x] Server: raw-key read and write refused for `zero_knowledge` accounts; mode transitions enforced
- [x] Read-only audit (1 Nov): 3,354 standard keys, none updated after creation (no sign of past
      overwrites); **3 of 4 zero-knowledge accounts hold a raw key** (the app re-uploaded it on every
      start). Server now refuses to serve it.
- [x] Repair (1 Nov, user ran it): `encryption_key` nulled on those 3 ZK rows; 0 ZK rows hold a raw key
- [x] Tests: GET timeout/500 then POST cannot change an existing key; concurrent first registration
      cannot diverge; ZK + legacy client cannot fetch/upload a raw key

**Phase 2 — sync never silently loses a newer note (P0: F1)**
- [x] Payload carries a base revision (server `server_updated_ms` the client last saw); server does
      compare-and-swap and returns a conflict instead of overwriting
- [x] Client keeps the losing side as a visible conflict copy (encrypted, like any note)
- [x] Tests: two devices offline in both orders, delete-vs-edit, stale retry, equal times, clock skew

**Phase 3 — reminders actually remind (F4 + F5)**
- [x] `SendReminderJob`: triggered only when at least one send is accepted; transient failures retry
      with backoff; invalid tokens pruned; atomic claim so sweep + schedule cannot double-send
- [x] Reminders schedule a local notification on the creating device (offline, app killed), with the
      backend push complementary and deduplicated (`local_device_id`, shared tag)
- [x] UI shows scheduled / permission-denied state for a reminder (`ReminderDeliveryStatus`, 4.2.0)
- [x] Migration `AddReminderDeliveryState` applied to production (1 Nov)
- [ ] Device matrix: foreground/background/terminated, airplane mode, reboot, timezone change
      (1 Nov, A24: fired backgrounded, inexact path; airplane-mode attachments verified. Reboot and
      timezone change need system-setting changes on the phone: the user does those)

**Phase 4 — subscription webhooks (F6)**
- [x] Transient failures already answer 500 (store retries); only unprocessable events are acked
- [x] Google already re-reads purchase state after every RTDN (no now+30/365 any more)
- [x] Apple: subscription events applied as the App Store Server API reports them now; redelivered
      if Apple cannot be asked (stale/out-of-order EXPIRED no longer ends a live subscription)

**Phase 5 — sessions and abuse (rest of F7)**
- [x] Login/register/refresh/Google rate-limited (20/min per IP); X-Forwarded-For trusted only from
      private networks (Traefik)
- [x] Revocable sessions (`auth_sessions`): rotating refresh tokens, previous token re-answered,
      older token = replay → session revoked; real sign-out; access tokens carry `sid`; legacy tokens
      migrate on next refresh (no mass sign-out)
- [x] Migration `AddAuthSessions` applied to production (1 Nov); backend redeploy pending

**Phase 6 — content minimisation (F8) and durability (F12)**
- [x] Recent searches out of SharedPreferences (encrypted DB, or not stored)
- [x] No notification title/body in release logs; sync telemetry uses closed reason codes only
- [x] Editor saves on `AppLifecycleState.paused`; test type → background → process death
- [x] OCR copy states Latin-script only (or add script recognizers)

**Phase 7 — honest promises and discoverability (F10, store copy)**
- [x] App: SOON "Share Encrypted" removed; Drawing FAB entry already gone; paywall already honest;
      remaining drawing/attachment/transcription strings live only in unreachable code
- [x] Stores and legal pages: drawing / encrypted sharing / transcription removed; attachments now
      real (4.2.0) and described; privacy policy + terms updated in privacy-project (pushed)
- [x] Visible way to create checklist / voice / reminder besides long-press ("Or start a" chips on a
      blank new note)
- [~] 1 Nov: queued, not submitted — Play: 3 changes in Publishing overview (short + full
      description, category → Productivity). iOS: version 4.2.0 with new description (all 8
      locales), promo text, keywords, release notes in every locale, review notes; "Add for Review"
      only waits for a 4.2.0 build.
      Then (1 Nov): Play tags → Notebook, Productivity, Audio recorder, Privacy & security (live);
      Data safety adds Photos, Videos, App interactions, Other user-generated content (queued).
      Still open: Apple privacy labels (analytics linked to the account, audio, photos). Play
      contact website stays https://pranta.dev. Still open: Play website/tags (publish instantly), Play Data
      safety "App activity", Apple privacy labels (analytics linked to account, audio), screenshots,
      legal-site policy still names Firebase cloud storage
- [ ] Then: Play Store + App Store listings reviewed together (title, category, description,
      screenshots, legal links, privacy labels) — the user edits the consoles, we prepare the copy

**Later, as planned projects (not quick fixes):** health/readiness checks and ops dashboard views;
sync pagination + FTS at 10k notes; CI release gate. (F9 local-first start shipped as guest mode in
4.3.0 and the write-first first run in 4.4.0; funnel events shipped in 4.4.0.)

## Conventions

- Commit messages: **no** "Co-Authored-By", and **no** mention of Claude, the model name (Opus/Sonnet/
  Haiku), or Anthropic. (Per the user's global instruction.)
- Run `flutter analyze` before considering UI work done; run `dart run build_runner build` after any
  Drift schema change.
- Devices: the A24 (`RR8W901JDRL`) and Tab A9 are shared with other Claude sessions. Ask them
  before using one, tell them when it is free, and check a change on the A24 before shipping.
  Release builds silence `debugPrint`; use a debug run to read logs.
- Play: write fresh release notes for all 9 locales each release; send anything for review only
  when the user says so for that release.
