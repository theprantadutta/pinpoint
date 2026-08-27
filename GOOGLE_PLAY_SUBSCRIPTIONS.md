# Pinpoint - Google Play Subscription Products

## Product Configuration for Google Play Console

Use these details when creating subscription products in Google Play Console.

> **Accuracy rule for this file:** every feature listed below must be something the
> shipped app actually does today. Do not copy a bullet in here because it is on a
> roadmap — Play listing copy that describes unshipped functionality is a policy risk.
> Product IDs must stay byte-identical to `SubscriptionService.premiumMonthly` /
> `premiumYearly` / `premiumLifetime` in `lib/services/subscription_service.dart`.

---

## 📦 Subscription Products

### 1. Premium Monthly Subscription

**Product ID**: `pinpoint_premium_monthly`

**Title**: Pinpoint Premium - Monthly

**Description**:
```
Unlock all premium features with Pinpoint Premium:

✓ Unlimited cloud sync (free accounts sync up to 50 notes)
✓ Unlimited folders (free accounts get 5)
✓ Unlimited OCR text scanning (free accounts get 20 scans a month)
✓ Unlimited PDF & Markdown export (free accounts get 10 exports a month)
✓ Unlimited voice recording length (free recordings stop at 2 minutes)
✓ Every accent color (free accounts get 2 of 5)

Cancel anytime. Your notes are encrypted on your device before they sync; turn on zero-knowledge mode and only your passphrase can unlock them.
```

**Price**: $4.99 USD/month

**Billing Period**: 1 month

**Free Trial**: 3 days (base-plan offer)

**Grace Period**: 3 days

---

### 2. Premium Yearly Subscription (Best Value)

**Product ID**: `pinpoint_premium_yearly`

**Title**: Pinpoint Premium - Yearly (Save 33%)

**Description**:
```
Get Pinpoint Premium for a full year and save 33%!

✓ Unlimited cloud sync (free accounts sync up to 50 notes)
✓ Unlimited folders (free accounts get 5)
✓ Unlimited OCR text scanning (free accounts get 20 scans a month)
✓ Unlimited PDF & Markdown export (free accounts get 10 exports a month)
✓ Unlimited voice recording length (free recordings stop at 2 minutes)
✓ Every accent color (free accounts get 2 of 5)

Best value - only $3.33/month when billed annually!

Cancel anytime. Your notes are encrypted on your device before they sync; turn on zero-knowledge mode and only your passphrase can unlock them.
```

**Price**: $39.99 USD/year (equivalent to $3.33/month)

**Billing Period**: 1 year

**Free Trial**: 7 days (base-plan offer)

**Grace Period**: 3 days

---

### 3. Premium Lifetime (One-Time Purchase)

**Product ID**: `pinpoint_premium_lifetime`

**Title**: Pinpoint Premium - Lifetime

**Description**:
```
Get Pinpoint Premium for life with a one-time payment!

✓ All premium features forever
✓ Unlimited cloud sync
✓ All future updates included
✓ No recurring payments
✓ Best value for long-term users

One payment. Lifetime access. Your privacy protected forever.
```

**Price**: $99.99 USD (one-time payment)

**Billing Period**: Non-renewing

**Free Trial**: None (one-time purchase)

---

## 🆓 Free trial policy

**Monthly carries a 3-day free trial; yearly carries 7 days.** Lifetime is a one-time
purchase and can never have one.

Both are configured as Google Play **base-plan offers**, not in the app. The client reads
the length from the live offer — `SubscriptionService.getTrialDays()` takes the
zero-priced pricing phase's `billingPeriod` (`P3D`, `P7D`) — and renders it through the
`subTrialCta` / `subTrialThenPrice` ARB plurals.

> **Never hardcode "3-day" or "7-day" into app copy or into the product descriptions
> below.** An offer can be shortened, lengthened or withdrawn in the Console with no app
> release, and Play withholds it from a user who has already used one. Copy that names a
> fixed length promises a trial some users will not be granted. If you change the offer,
> nothing in the app needs to change — but re-check this file and the store listing.

**This file covers Google Play only.** The App Store equivalent is an *introductory
offer*, configured per subscription in App Store Connect — set it up there separately.
The iOS paywall does display it: the client reads the introductory offer out of StoreKit 2
and then confirms this user's eligibility before showing any trial copy.

> **Both stores grant a trial only to a user who has not already used one** in that
> subscription group. So the paywall can show trial copy to one user and not another, by
> design. That is also why the length must never be served from our backend: a server
> reading the store catalogue knows what offers exist, never who gets one.

---

## 🎯 Feature Comparison

Everything in the free column is genuinely enforced in `lib/services/premium_service.dart`
against the limits in `lib/constants/premium_limits.dart`. Premium is the unlimited
version of each of those, and nothing else.

### Free Tier
- ✅ Note-taking (text, checklists, voice memos, reminders)
- ✅ Notes encrypted on device before sync; optional zero-knowledge mode
- ✅ Biometric lock
- ✅ Cloud sync (up to 50 notes)
- ✅ Up to 5 folders
- ✅ OCR text scanning (20 scans/month)
- ✅ PDF & Markdown export (10 exports/month)
- ✅ 2 accent colors (Neon Mint, Blue Ocean)
- ✅ Light, dark and system themes
- ✅ All bundled fonts
- ❌ Unlimited sync, folders, OCR, exports or voice-recording length
- ❌ The other 3 accent colors

### Premium Tier (All Plans)
- ✅ Everything in Free
- ✅ **Unlimited cloud sync**
- ✅ **Unlimited folders**
- ✅ **Unlimited OCR** text scanning
- ✅ **Unlimited PDF & Markdown export**
- ✅ **Unlimited voice recording length** (free stops at 2 minutes)
- ✅ **All 5 accent colors**

> Themes (light/dark/system) and the bundled fonts are free for everyone — do **not**
> list them as premium. Drawing, encrypted note sharing, templates, advanced search,
> smart folders, DOCX/HTML export, version history and any AI feature are **not
> implemented**; do not list them until they ship. The per-note **attachment** limit is
> still not enforced anywhere in the shipping editor (there is no attachment picker), so
> it is not a free/premium difference — do not list it. The 2-minute voice cap *is*
> enforced, in `create_note_screen_v2.dart`.

---

## 💳 Pricing Strategy

| Plan | Price | Per Month | Savings | Best For |
|------|-------|-----------|---------|----------|
| **Monthly** | $4.99/month | $4.99 | - | Try premium features |
| **Yearly** | $39.99/year | $3.33 | 33% | Regular users |
| **Lifetime** | $99.99 once | - | Best value | Power users |

---

## 🔄 Subscription Configuration

### Subscription Benefits
- ✅ Automatic renewal
- ✅ Free trial: 3 days monthly, 7 days yearly (configured as Play offers)
- ✅ Cancel anytime
- ✅ Grace period for failed payments

### Renewal Settings
- **Auto-renew**: Yes (Monthly & Yearly)
- **Notification**: 3 days before renewal
- **Grace period**: 3 days (Monthly & Yearly)
- **Account hold**: 30 days

---

## 📝 Google Play Console Setup Steps

### 1. Create Subscriptions

1. Go to **Google Play Console** → Your App → **Monetize** → **Subscriptions**
2. Click **Create subscription**
3. Enter Product ID (exactly as shown above)
4. Add Title and Description
5. Set Base plan (Monthly/Yearly)
6. Configure pricing
7. Add the free-trial offer on the base plan (3 days monthly / 7 days yearly). The app
   reads the length from the offer, so no app change is needed to adjust it.
8. Save and activate

### 2. Create One-Time Product (Lifetime)

1. Go to **In-app products**
2. Create **Non-consumable** product
3. Use Product ID: `pinpoint_premium_lifetime`
4. Set price: $99.99
5. Activate

### 3. Set Up Pricing by Country

**Suggested pricing by region:**

| Region | Monthly | Yearly | Lifetime |
|--------|---------|--------|----------|
| **US** | $4.99 | $39.99 | $99.99 |
| **UK** | £4.49 | £34.99 | £89.99 |
| **EU** | €4.99 | €39.99 | €99.99 |
| **India** | ₹349 | ₹2,999 | ₹7,499 |
| **Canada** | CA$6.49 | CA$49.99 | CA$129.99 |
| **Australia** | AU$7.49 | AU$59.99 | AU$149.99 |

---

## 🎁 Promotional Offers

**None configured.** The client only ever queries the three product IDs above
(`SubscriptionService.productIds`), so any promotional product created in the Console
would be invisible to the app. If a promo offer is wanted, add it as an *offer on an
existing base plan* rather than as a new product ID, and confirm the entitlement still
verifies against the same product ID before announcing it.

---

## 🔐 Server-Side Verification

The backend verifies every purchase with Google Play before granting an entitlement.
The client posts the purchase to:

```
POST /api/v1/subscription/verify-device
{
  "device_id": "...",
  "purchase_token": "...",
  "product_id": "pinpoint_premium_monthly",
  "platform": "android",
  "user_id": "..."          // optional, sent when signed in
}
```

This ensures:
- ✅ Valid purchases only
- ✅ Entitlements survive reinstall (device-scoped) and follow the account when signed in
- ✅ Subscription status is refreshed from the server, not trusted from the store client

---

## 📊 Analytics & Metrics

Track these metrics in Google Play Console:

1. **Conversion Rate**: Free → Premium
2. **Churn Rate**: Cancellations
3. **ARPU**: Average Revenue Per User
4. **LTV**: Lifetime Value

**Target metrics:**
- Free → Premium conversion: >5%
- Monthly churn: <5%
- Yearly churn: <10%

---

## 🚀 Marketing Copy

### App Store Description

**Free features:**
Create notes, checklists, voice memos, and reminders. Note text is encrypted on your device before it syncs, with an optional zero-knowledge mode.
Sync up to 50 notes to the cloud, keep up to 5 folders, scan 20 images with OCR a month,
export 10 notes a month to PDF or Markdown, and record voice notes up to 2 minutes each.

**Premium features:**
Unlock unlimited cloud sync, unlimited folders, unlimited OCR, unlimited PDF and Markdown
export, unlimited voice recording length, and every accent color.

**Pricing:**
- Monthly: $4.99/month
- Yearly: $39.99/year (save 33%)
- Lifetime: $99.99 (best value)

---

## ✅ Checklist

Before launching subscriptions:

- [ ] Create all 3 products in Google Play Console
- [ ] Set up pricing for all countries
- [ ] Confirm the free-trial offers are active (3 days monthly, 7 days yearly) in every
      intended country — the paywall shows trial copy only when Play reports the offer
- [ ] Confirm the Console descriptions match the "Feature Comparison" section above
- [ ] Test purchase flow
- [ ] Verify backend integration
- [ ] Test subscription status checking
- [ ] Test cancellation flow
- [ ] Set up grace periods
- [ ] Configure notifications
- [ ] Set a real support contact in the Play listing (see below)
- [ ] Submit for review

---

## 📞 Support

Support runs through the web page the backend serves at **`/support`**
(`pinpoint-backend/src/Pinpoint.Api/wwwroot/support.html`), which lists the developer's
email and a 1-2 day response target. Put that URL in the Play Console listing's support
fields.

**Open items:** there is no in-app help/contact entry point (nothing in `lib/` links to
`/support`), and there is no priority queue for paying users — so do **not** advertise
"priority support" as a Premium benefit anywhere.

**Refund policy:**
Google Play's standard refund terms apply. Do not promise a custom refund window in the
listing unless there is a process behind it.

---

**Privacy Promise — state it exactly like this:**
All subscriptions are processed securely through Google Play. Note text, checklists,
colors and labels are encrypted on your device before they sync.

Be precise about the key, because the two modes are genuinely different:

- **Standard mode (default):** a recovery copy of your encryption key is stored on our
  server so you can get your notes back on a new device — which means we hold a key that
  can decrypt them.
- **Zero-knowledge mode (opt-in):** your key is wrapped with your passphrase, so only your
  passphrase unlocks your notes and we cannot read them. Lose the passphrase and the
  recovery code, and neither can we.

Two things are **not** end-to-end encrypted, and the listing must not imply otherwise:
voice recordings synced to the cloud, and reminder title/body/schedule (our server needs
to read those to send the notification).

Pinpoint also uses Firebase Analytics and Crashlytics for diagnostics and product usage.
When a user is signed in these are tied to their account ID, so do **not** describe them
as anonymous. Note content, titles, search terms, transcripts, purchase tokens,
passphrases, recovery codes and encryption keys are never sent to them.
See `assets/legal/privacy.md`.

---

Copy these details directly into Google Play Console when setting up your subscription products!
