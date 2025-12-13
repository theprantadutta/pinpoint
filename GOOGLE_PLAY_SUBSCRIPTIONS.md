# Pinpoint - Google Play Subscription Products

## Product Configuration for Google Play Console

Use these details when creating subscription products in Google Play Console.

---

## 📦 Subscription Products

### 1. Premium Monthly Subscription

**Product ID**: `pinpoint_premium_monthly`

**Title**: Pinpoint Premium - Monthly

**Description**:
```
Unlock all premium features with Pinpoint Premium:

✓ Unlimited cloud sync across all devices
✓ Unlimited audio recording & transcription
✓ Advanced OCR (unlimited text recognition)
✓ All premium themes & fonts
✓ Priority support
✓ Export to multiple formats (PDF, Markdown, DOCX)
✓ Shared encrypted notes
✓ Advanced search & smart folders

Cancel anytime. Your privacy is always protected with end-to-end encryption.
```

**Price**: $4.99 USD/month

**Billing Period**: 1 month

**Free Trial**: 7 days

**Grace Period**: 3 days

---

### 2. Premium Yearly Subscription (Best Value)

**Product ID**: `pinpoint_premium_yearly`

**Title**: Pinpoint Premium - Yearly (Save 33%)

**Description**:
```
Get Pinpoint Premium for a full year and save 33%!

✓ Unlimited cloud sync across all devices
✓ Unlimited audio recording & transcription
✓ Advanced OCR (unlimited text recognition)
✓ All premium themes & fonts (8 Google Fonts)
✓ Priority support
✓ Export to multiple formats (PDF, Markdown, DOCX)
✓ Shared encrypted notes with E2E encryption
✓ Advanced search & smart folders
✓ Auto-backup & version history

Best value - only $3.33/month when billed annually!

Cancel anytime. Your privacy is always protected with end-to-end encryption.
```

**Price**: $39.99 USD/year (equivalent to $3.33/month)

**Billing Period**: 1 year

**Free Trial**: 7 days

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
✓ Unlimited AI features
✓ All future updates included
✓ No recurring payments
✓ Best value for long-term users

One payment. Lifetime access. Your privacy protected forever.
```

**Price**: $99.99 USD (one-time payment)

**Billing Period**: Non-renewing

**Free Trial**: None (one-time purchase)

---

## 🎯 Feature Comparison

### Free Tier
- ✅ Basic note-taking (text, audio, todo, reminders)
- ✅ Local storage with encryption
- ✅ Up to 5 folders
- ✅ Biometric lock
- ✅ 2 color themes (Neon Mint, Blue Ocean)
- ✅ Audio recording (2 min limit)
- ✅ OCR (20 images/month)
- ✅ Cloud sync (up to 50 notes)
- ✅ Exports (10/month)
- ✅ Up to 3 attachments per note
- ✅ Local backup
- ❌ Multi-device unlimited sync
- ❌ Premium themes (3 additional colors)

### Premium Tier (All Plans)
- ✅ Everything in Free
- ✅ **Unlimited cloud sync** across devices
- ✅ **Multi-device support** (phone, tablet, desktop)
- ✅ **Unlimited audio recording** (no time limit)
- ✅ **Unlimited OCR** text recognition
- ✅ **Unlimited voice transcription**
- ✅ **All 8 premium Google Fonts**
- ✅ **5 premium color themes**
- ✅ **Custom gradients**
- ✅ **Unlimited folders** & nested folders
- ✅ **Smart folders** (auto-organize)
- ✅ **Advanced search** with filters
- ✅ **Export to PDF, Markdown, DOCX, HTML**
- ✅ **Batch export**
- ✅ **Encrypted sharing** (share notes securely)
- ✅ **Shared folders** with E2E encryption
- ✅ **Auto-backup** with version history
- ✅ **Priority support**
- ✅ **Early access** to new features

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
- ✅ 7-day free trial (Monthly & Yearly)
- ✅ Cancel anytime
- ✅ Grace period for failed payments
- ✅ Family Library sharing (optional)

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
7. Add free trial period
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

## 🎁 Promotional Offers (Optional)

### Launch Offer
- **50% off first 3 months** (Monthly only)
- Product ID: `pinpoint_premium_monthly_launch`
- Limited time offer

### Annual Discount
- **Free first month** on yearly plan
- Available during holidays

---

## 🔐 Server-Side Verification

Your backend (`pinpoint_backend`) automatically verifies all purchases with Google Play:

```
POST /api/v1/subscription/verify
{
  "purchase_token": "...",
  "product_id": "pinpoint_premium_monthly"
}
```

This ensures:
- ✅ Valid purchases only
- ✅ No fraud
- ✅ Automatic subscription management
- ✅ Real-time status updates

---

## 📊 Analytics & Metrics

Track these metrics in Google Play Console:

1. **Conversion Rate**: Free → Premium
2. **Trial Conversion**: Trial → Paid
3. **Churn Rate**: Cancellations
4. **ARPU**: Average Revenue Per User
5. **LTV**: Lifetime Value

**Target metrics:**
- Trial → Paid conversion: >40%
- Monthly churn: <5%
- Yearly churn: <10%

---

## 🚀 Marketing Copy

### App Store Description

**Free features:**
Create notes, todos, voice memos, and reminders. All data encrypted locally. Sync up to 50 notes to the cloud.

**Premium features:**
Unlock unlimited cloud sync, unlimited OCR, premium themes, and cross-device access. Try 7 days free!

**Pricing:**
- Monthly: $4.99/month
- Yearly: $39.99/year (save 33%)
- Lifetime: $99.99 (best value)

---

## ✅ Checklist

Before launching subscriptions:

- [ ] Create all 3 products in Google Play Console
- [ ] Set up pricing for all countries
- [ ] Enable free trials (Monthly & Yearly)
- [ ] Test purchase flow
- [ ] Verify backend integration
- [ ] Test subscription status checking
- [ ] Test cancellation flow
- [ ] Set up grace periods
- [ ] Configure notifications
- [ ] Add promotional offers (optional)
- [ ] Submit for review

---

## 📞 Support

**For subscription issues:**
- Email: support@pinpoint.app
- In-app: Settings → Help & Support
- Response time: <24 hours

**Refund policy:**
Full refund within 48 hours of purchase, no questions asked.

---

**Privacy Promise:**
All subscriptions are processed securely through Google Play. Your notes remain end-to-end encrypted. We never see your data. Cancel anytime.

---

Copy these details directly into Google Play Console when setting up your subscription products!
