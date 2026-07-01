# PinPoint — Apple App Store Setup & Submission Checklist

Everything you need to do **outside the code** to ship PinPoint on the App Store.
All code changes (iOS config, Sign in with Apple, StoreKit IAP + backend, account
deletion, legal/paywall, safety gates) are already done. This is the console /
deploy / submission runbook.

- **Bundle ID:** `com.pranta.pinpoint`
- **App version:** `2.2.0 (22)`  ← from `pubspec.yaml` (`version: 2.2.0+22`)
- **Backend:** `https://pinpoint.pranta.dev`
- **Firebase project:** `pinpoint-8f6e5`

Legend: ✅ done · ⬜ to do

---

## 1. Apple Developer Portal (certificates, identifiers & keys)

- ✅ **App ID** `com.pranta.pinpoint` created (explicit), with **Push Notifications**
  and **Sign in with Apple** enabled. (In-App Purchase is automatic.)
- ✅ **APNs Authentication Key** (`.p8`) created and uploaded to Firebase.
- ⬜ (Optional, Phase 3 reconciliation only) **App Store Server API key**:
  Users and Access → Integrations → In-App Purchase → generate a key. Note the
  `.p8`, **Key ID**, and **Issuer ID**. Not required for basic verification.

## 2. Firebase Console

- ✅ **Apple** enabled under Authentication → Sign-in method (native iOS only —
  Services ID / return URL not required).
- ✅ APNs key uploaded under Project Settings → Cloud Messaging → Apple app config.
- ⬜ Confirm the iOS app (`com.pranta.pinpoint`) is registered in this Firebase
  project and `GoogleService-Info.plist` matches (it does in the repo).

## 3. App Store Connect

### 3a. App record
- ✅ App created with SKU + name (`PinPoint: Notes & Reminders` or your chosen name).
- ⬜ Copy the app's numeric **Apple ID** (App Information → General → "Apple ID").
  → put it in the backend `.env` as `APPLE_APP_APPLE_ID` (see §4).

### 3b. In-App Purchases  (Monetization → In-App Purchases / Subscriptions)
Create these with **the same product IDs as Google Play** so the app code stays unified:

| Product ID | Type | Notes |
|---|---|---|
| `pinpoint_premium_monthly` | Auto-Renewable Subscription | Put in a subscription group (e.g. "PinPoint Premium") |
| `pinpoint_premium_yearly`  | Auto-Renewable Subscription | Same subscription group |
| `pinpoint_premium_lifetime`| Non-Consumable | One-time purchase |

- ⬜ Set prices, localized display name + description for each.
- ⬜ Add a **review screenshot** for each IAP (required to submit).
- ⬜ First submission: attach the IAPs to the app version (they review together).

### 3c. App Store Server Notifications  (App Information → App Store Server Notifications)
- ⬜ Set **Version 2**, and for **both Production and Sandbox** URLs:
  `https://pinpoint.pranta.dev/api/v1/webhooks/app-store`
- ⚠️ Do this **after** the backend is deployed (§4) — Apple sends a test ping
  expecting HTTP 200.

### 3d. App Privacy ("nutrition label" — App Information → App Privacy)
Answers derived from `ios/Runner/PrivacyInfo.xcprivacy`. Declare data collected,
**linked to identity**, **not used for tracking**:

| Data type | Purpose | Linked | Tracking |
|---|---|---|---|
| Email address | App Functionality | Yes | No |
| Name | App Functionality | Yes | No |
| User content (notes/images/audio) | App Functionality | Yes | No |
| Device ID | App Functionality | Yes | No |
| Purchase history | App Functionality | Yes | No |
| Crash data | App Functionality | No | No |
| Product interaction / usage | Analytics | No | No |

- ⬜ Answer "Do you or your partners use data for tracking?" → **No** (matches
  `NSPrivacyTracking = false`).

### 3e. Legal URLs (App Information)
- ⬜ **Privacy Policy URL** (required): host `assets/legal/privacy_policy.md` (see §5).
- ⬜ **License Agreement**: default Apple EULA is fine (Terms already reference it),
  or paste custom terms.

### 3f. Encryption / export compliance
- ✅ `ITSAppUsesNonExemptEncryption = false` is set in `Info.plist`, so App Store
  Connect won't prompt for export docs on each build.

## 4. Backend deploy (`pinpoint.pranta.dev`)

- ⬜ **Apple root certs**: download **Apple Root CA - G3** (`.cer`) from
  <https://www.apple.com/certificateauthority/> into `pinpoint_backend/apple-root-certs/`
  (see the README there). Public/safe to commit.
- ⬜ **`.env`** on the server — set:
  ```
  APPLE_BUNDLE_ID=com.pranta.pinpoint
  APPLE_APP_APPLE_ID=<numeric Apple ID from §3a>
  APPLE_ROOT_CERTS_DIR=apple-root-certs
  APPLE_ENABLE_ONLINE_CHECKS=true
  # optional (status reconciliation only):
  APPLE_ISSUER_ID=
  APPLE_KEY_ID=
  APPLE_PRIVATE_KEY_PATH=
  ```
  Without `APPLE_APP_APPLE_ID`, only **Sandbox** purchases verify (fine for
  TestFlight/review; set it before Production launch).
- ⬜ `pip install -r requirements.txt` (adds `app-store-server-library==3.1.2`).
- ⬜ **No DB migration required** — Apple purchases reuse existing columns
  (`SubscriptionEvent.platform`, `Device.last_purchase_token`).
- ⬜ Redeploy, then set the server-notification URL (§3c).

## 5. Host the legal documents

App Store Connect needs a public **Privacy Policy URL** (and auto-renewable
subscriptions need Terms/EULA reachable). Easiest: serve the two files on your
domain, e.g.:
- `https://pinpoint.pranta.dev/privacy` ← `assets/legal/privacy_policy.md`
- `https://pinpoint.pranta.dev/terms`   ← `assets/legal/terms_of_service.md`

(The in-app paywall + Settings already show the bundled copies; these URLs are
just for the store listing.)

## 6. Build, sign & upload

- ⬜ Open `ios/Runner.xcworkspace` in Xcode → **Runner target → Signing &
  Capabilities**: select your **Team**, confirm automatic signing, and that
  **Push Notifications** + **Sign in with Apple** capabilities appear (they read
  from `Runner.entitlements`).
- ⬜ Set the build to Release, then:
  ```
  flutter build ipa --release
  ```
  (or Archive in Xcode). Upload via **Xcode Organizer** or **Transporter**.
- ⬜ App uses **iOS 15.5+**, universal (iPhone + iPad).

## 7. Screenshots (Media Manager)

Universal app → you need both:
- ⬜ **iPhone 6.7"** (e.g. 15/16 Pro Max) — required
- ⬜ **iPhone 6.5"** (or 6.9") set
- ⬜ **iPad 12.9"** (Pro) — required because you ship iPad support
- Note: ML Kit OCR has no arm64 **simulator** slice — capture screenshots on a
  **physical device** or use screens that don't invoke OCR.

## 8. App Review notes + demo account

- ⬜ Provide a **demo account** (email + password) so review can sign in.
- ⬜ Review notes, suggested text:
  > PinPoint is a note-taking app. Sign in with the provided demo account (or use
  > Sign in with Apple / Google). Premium unlocks unlimited cloud sync and is sold
  > via auto-renewable subscriptions and a one-time lifetime purchase (StoreKit).
  > Account deletion: Settings → Delete Account.

## 9. Final pre-submit checklist

- ⬜ IAP products created + attached to the version (§3b)
- ⬜ Server notification URL saved & test ping returned 200 (§3c)
- ⬜ App Privacy answers submitted (§3d)
- ⬜ Privacy Policy URL set (§3e/§5)
- ⬜ Backend deployed with Apple certs + env (§4)
- ⬜ Screenshots for iPhone + iPad (§7)
- ⬜ Demo account + review notes (§8)
- ⬜ Build uploaded and selected for the version (§6)

---

## Play Store safety note

Every change in this effort was **additive or iOS-only**:
- `platform` defaults to `android` on the backend, so shipped Android clients are unaffected.
- Sign in with Apple button renders only `if (Platform.isIOS)`.
- Account deletion works on both platforms (Google Play also requires it).
- `flutter_exit_app` was removed (Google discourages it too); `in_app_update`
  remains Android-gated and unchanged.

Nothing here should require a coordinated Play Store release, but bumping the
shared version to `2.2.0+22` means your next Play upload should use build ≥ 22.
