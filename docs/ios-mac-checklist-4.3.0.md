# 4.3.0 on a Mac: what still needs doing for iOS

All of 4.3.0 was built and tested on Windows with an Android phone. **Nothing below has run on iOS.**
Work top to bottom and tick items here as they land. Do not submit to the App Store until part 1
passes.

## Setup

```sh
git pull origin master
flutter pub get
cd ios && pod install --repo-update && cd ..   # skip if the project resolves through Swift Package Manager
flutter test                                   # 453 passed on Windows
flutter analyze                                # 2 infos expected: getToken, onTokenRefresh
xcrun simctl list devices available
flutter run -d <simulator id> --dart-define=API_BASE_URL=<API_BASE_URL_PROD from .env, without /api>
```

The simulator cannot do real push or real App Store purchases. Purchases can use
`ios/Products.storekit`; push and the real purchase flow need a physical iPhone.

## 1. Does it still build? (highest risk)

The upgrades below were only compiled for Android.

- [ ] `flutter build ios --simulator --no-codesign` succeeds
- [ ] `flutter build ipa` succeeds with the release certificate
- [ ] App starts with no crash on launch. Firebase moved to majors (`firebase_core` 5, `firebase_auth` 7,
      `firebase_messaging` 17, `firebase_crashlytics` 6, `firebase_analytics` 13), which means **Firebase
      iOS SDK 13**. Check the deployment target if the build complains
- [ ] Crashlytics dSYM upload still runs in the Xcode build phase
- [ ] `flutter_inapp_purchase` went from 10 to 11: paywall shows prices, and `purchase_mapping.dart`
      still derives the trial (`iosConfiguredTrialDays`, `isEligibleForIntroOfferIOS`). Make one
      sandbox purchase and one restore on a real iPhone
- [ ] Push: a reminder arrives on a real iPhone. `firebase_notification_service.dart` still uses
      `getToken` / `onTokenRefresh`, deprecated in 17 but working. Moving to `register()` /
      `onRegistered` was skipped on purpose, because it can change device registration on the backend

## 2. Check these changes on iOS

A fresh simulator is the right place for the first-run items: nothing needs wiping.

| Change | What to do | Expected |
|---|---|---|
| Paste crash | Long note, long-press, Copy, then Paste | No error. Caret stays visible |
| Toolbar | Type past the keyboard in a long note | Current line stays above the floating toolbar |
| Folder cards | Note with no title, in a folder | Card shows its text, never `[{"insert"` |
| Onboarding | Fresh install, also with Reduce Motion on | One screen, with the encryption limits line |
| First note | Get started, sign in, reach home | Blank note opens, once. Notification sheet comes after leaving it |
| Returning user | Sign in to an account with notes | Straight to home, no blank note. **Never verified on a device** |
| Guest mode | Sign-in screen, Continue without an account | Home with a Sign in card. Note saves. No API calls |
| Guest restart | Kill and reopen as a guest | Back to home, not the sign-in screen |
| Guest to account | Write as guest, sign in (Apple too) | Note stays and syncs. See warning below |
| Nudge | Turn the switch on, then Turn on notifications | One pending notification, two days out at 10:00 |
| Nudge cancels | Reopen 12+ hours later | Pending notification is gone |
| Shortcuts | Long-press the app icon | New note, Checklist, Voice each open correctly, closed and open |
| Lock | Shortcut while zero-knowledge unlock is showing | Opens only after unlock |

**Guest sign-in warning.** On Android this was tested only with a temporary build, signing in to the
same account whose notes were already on the phone. A genuinely new guest signing in to a **new**
account, and to an **existing account with other notes**, is covered by unit tests only
(`test/account_key_recovery_test.dart`). Test both for real, on iOS or Android, and confirm the guest's
notes appear on a second device.

Check iOS shortcut icons: `CaptureInbox.setShortcuts` passes none on iOS, so they show the default.

Analytics: run with `-FIRDebugEnabled` in the Xcode scheme and open Firebase DebugView. Expect real
names (`Home`, `Notes`, `Create Note`), never `FlutterViewController`, because of
`FirebaseAutomaticScreenReportingEnabled = false` in `Info.plist`. Also expect `first_note_created`,
`guest_started`, `capture_opened`, `sync_started` and `sync_completed`.

## 3. Not built for iOS yet

- [ ] **Share to Pinpoint.** Needs a Share Extension target and an App Group in Xcode, following the
      iOS section of the `receive_sharing_intent` README. Then remove the Android-only early return
      in `CaptureInbox.start` (`lib/services/capture/capture_inbox.dart`), and check it survives a
      killed app. Android needed a fix for exactly that; see `MainActivity.kt`
- [ ] **Home screen widget.** Android only (`QuickCaptureWidget.kt`). iOS needs a WidgetKit extension
      with deep links into `CaptureInbox`. Show no note text: it would sit outside the encrypted database

## 4. App Store Connect (the user submits; never submit for them)

- [ ] Use the iOS copy in `docs/store-listing-4.3.0.md`. It leaves out sharing and the widget
- [ ] Privacy labels, still open from the 1 Nov review: analytics linked to the account, audio, photos
- [ ] Do not change store screenshots unless the user asks. Onboarding is now one screen
- [ ] "Add for Review" only queues. The final submission is the user's

## Android items that also need a person

- Long-press the real icon to try the shortcuts (only opened by command so far)
- Leave a purchase and a Google sign-in halfway, return from the app icon, and confirm neither is
  cancelled. `singleTask` launch mode is new in 4.3.0 and could affect both
- Reboot and timezone-change reminder checks (1 Nov review, Phase 3)
