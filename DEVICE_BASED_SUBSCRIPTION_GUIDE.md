# Device-Based Subscription System (No Authentication Required)

## Overview

This guide describes the simplified subscription system that **does not require user login/registration**. Users can purchase premium subscriptions directly through Google Play, and the app verifies purchases using device identification.

## How It Works

```
User Opens App
      │
      ▼
Device ID Generated/Retrieved
      │
      ▼
Check Premium Status (Local Cache)
      │
      ▼
User Purchases via Google Play
      │
      ▼
Purchase Token Sent to Backend
(with Device ID)
      │
      ▼
Backend Verifies with Google Play API
      │
      ▼
Premium Status Saved Locally & on Backend
      │
      ▼
Premium Features Unlocked
```

## Key Components

### 1. SubscriptionManager (`lib/services/subscription_manager.dart`)

**Purpose:** Manages subscription status without requiring user accounts

**Features:**
- Generates and stores unique device ID
- Stores premium status locally (SharedPreferences)
- Verifies purchases with backend using device ID
- Syncs subscription status from backend
- Works offline with local cache

**Device ID Generation:**
- **Android:** Uses Android ID (`androidInfo.id`)
- **iOS:** Uses Identifier for Vendor (`iosInfo.identifierForVendor`)
- **Fallback:** Timestamp + hostname hash

### 2. SubscriptionService (`lib/services/subscription_service.dart`)

**Purpose:** Handles Google Play In-App Purchase flow

**Features:**
- Loads subscription products from Google Play
- Handles purchase flow
- Listens to purchase updates
- Completes purchase after verification

### 3. API Service (`lib/services/api_service.dart`)

**New Device-Based Endpoints:**
```dart
// Verify purchase with device ID
POST /api/v1/subscription/verify-device
{
  "device_id": "abc123",
  "purchase_token": "token_from_google",
  "product_id": "pinpoint_premium_monthly"
}

// Get subscription status by device ID
GET /api/v1/subscription/status/{device_id}
```

## Subscription Products

Configured in `GOOGLE_PLAY_SUBSCRIPTIONS.md`:

| Product ID | Type | Price | Billing |
|-----------|------|-------|---------|
| `pinpoint_premium_monthly` | Subscription | $4.99/month | Auto-renewable |
| `pinpoint_premium_yearly` | Subscription | $39.99/year | Auto-renewable |
| `pinpoint_premium_lifetime` | One-time | $99.99 | Permanent |

## Premium Features

When `SubscriptionManager.isPremium` is `true`:

1. **Cloud Sync** - Sync notes across devices
2. **Unlimited Notes** - No 100-note limit
3. **Advanced Encryption** - Additional security
4. **Priority Sync** - Faster sync operations
5. **Custom Themes** - More theme options
6. **Export Options** - PDF, Markdown export
7. **Extended Voice Notes** - Longer recording time
8. **OCR** - Text recognition
9. **Priority Support** - Email support

## User Flow

### First Launch
1. App generates unique device ID
2. Device ID stored in SharedPreferences
3. Premium status: `free` (default)
4. Shows all features with "Upgrade to Premium" for locked features

### Purchasing Premium
1. User navigates to: **Account → Subscription → Select Plan**
2. Google Play payment dialog appears
3. User completes payment via Google Play
4. App receives purchase token
5. App sends to backend: `{device_id, purchase_token, product_id}`
6. Backend verifies with Google Play API
7. Backend stores: `{device_id → premium, expiry_date}`
8. App updates local status: `isPremium = true`
9. Premium badge appears in Account screen
10. All premium features unlock

### Subsequent Launches
1. App reads device ID from SharedPreferences
2. Loads cached premium status from local storage
3. Background check: Query backend for latest status
4. If subscription expired, reverts to free tier

### Restoring Purchases (New Device)
1. User installs app on new device
2. New device ID generated
3. User taps "Restore Purchases" in subscription screen
4. Google Play returns active subscriptions
5. App verifies with backend using new device ID
6. Backend links new device ID to existing subscription
7. Premium status restored

## Implementation Details

### Device ID Storage
```dart
SharedPreferences:
- Key: 'device_id'
- Value: "abc123xyz789" (unique identifier)
- Persistent across app restarts
```

### Premium Status Storage
```dart
SharedPreferences:
- 'is_premium': bool
- 'subscription_tier': String ('free', 'premium')
- 'subscription_expires_at': String (ISO 8601 date)
```

### Checking Premium Status in UI
```dart
// In any widget
Consumer<SubscriptionManager>(
  builder: (context, subscriptionManager, child) {
    if (subscriptionManager.isPremium) {
      return PremiumFeatureWidget();
    }
    return UpgradePrompt();
  }
)
```

## Backend Requirements

Your FastAPI backend needs these endpoints:

### 1. Verify Purchase with Device
```python
@router.post("/subscription/verify-device")
async def verify_purchase_device(
    device_id: str,
    purchase_token: str,
    product_id: str
):
    # 1. Verify purchase token with Google Play API
    subscription = google_play_service.subscriptions().get(
        packageName="com.example.pinpoint",
        subscriptionId=product_id,
        token=purchase_token
    ).execute()

    # 2. Check if subscription is valid
    if subscription['paymentState'] == 1:  # Payment received
        # 3. Store/update device subscription in database
        db_device = db.query(Device).filter_by(device_id=device_id).first()
        if not db_device:
            db_device = Device(device_id=device_id)
            db.add(db_device)

        db_device.subscription_tier = "premium"
        db_device.subscription_product_id = product_id
        db_device.subscription_expires_at = datetime.fromtimestamp(
            int(subscription['expiryTimeMillis']) / 1000
        )
        db.commit()

        return {
            "success": True,
            "is_premium": True,
            "tier": "premium",
            "expires_at": db_device.subscription_expires_at.isoformat()
        }

    return {"success": False}
```

### 2. Get Subscription Status
```python
@router.get("/subscription/status/{device_id}")
async def get_device_subscription_status(device_id: str):
    device = db.query(Device).filter_by(device_id=device_id).first()

    if not device:
        return {
            "is_premium": False,
            "tier": "free",
            "expires_at": None
        }

    # Check if subscription expired
    if device.subscription_expires_at and device.subscription_expires_at < datetime.now():
        device.subscription_tier = "free"
        db.commit()

    return {
        "is_premium": device.subscription_tier != "free",
        "tier": device.subscription_tier,
        "expires_at": device.subscription_expires_at.isoformat() if device.subscription_expires_at else None
    }
```

### 3. Database Schema
```python
class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True)
    device_id = Column(String(255), unique=True, index=True)
    subscription_tier = Column(String(50), default="free")
    subscription_product_id = Column(String(100), nullable=True)
    subscription_expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

## Testing

### Test Premium Without Purchase (Development Only)
```dart
// In your code
final subscriptionManager = context.read<SubscriptionManager>();

// Grant premium for testing
await subscriptionManager.grantPremium(
  tier: 'premium',
  expiresAt: DateTime.now().add(Duration(days: 30)),
);

// Revoke premium
await subscriptionManager.revokePremium();
```

### Test Purchase Flow
1. Set up Google Play test track
2. Add test user in Google Play Console
3. Run app on physical device (emulator won't work)
4. Make test purchase
5. Verify backend receives purchase token
6. Check premium status updates

## Advantages of Device-Based System

✅ **Simple User Experience**
- No account creation required
- No password to remember
- No email verification

✅ **Privacy-Focused**
- No personal data collected
- No email/password storage
- Only device ID tracked

✅ **Quick Setup**
- Install app → Start using immediately
- Purchase premium → Instant unlock
- No signup friction

✅ **Reliable**
- Works offline with local cache
- Syncs when online
- Google Play handles payment securely

## Limitations

⚠️ **Device-Specific**
- Premium tied to device, not user
- New device = new purchase (unless restored)
- No cross-device sync of subscription status

⚠️ **Restore Purchases Required**
- User must manually restore on new device
- Requires same Google account

## Migration to User Accounts (Future)

If you later want to add user accounts:

1. Keep `SubscriptionManager` as-is
2. Add optional email/password fields to Device table
3. Allow users to "claim" their device ID with account
4. Link multiple devices to one user account
5. Sync subscription across all user's devices

The current system is designed to work independently, so adding accounts later is straightforward.

## Files Created/Modified

### Created:
- `lib/services/subscription_manager.dart` - Device-based subscription management

### Modified:
- `lib/main.dart` - Uses SubscriptionManager instead of BackendAuthService
- `lib/services/api_service.dart` - Added device-based endpoints
- `lib/services/subscription_service.dart` - Uses SubscriptionManager
- `lib/screens/splash_screen.dart` - Removed login check
- `lib/screens/account_screen.dart` - Uses SubscriptionManager
- `lib/screens/subscription_screen.dart` - Uses SubscriptionManager
- `lib/navigation/app_navigation.dart` - Removed login/register routes

### Deleted:
- `lib/screens/login_screen.dart` ❌
- `lib/screens/register_screen.dart` ❌
- `lib/services/backend_auth_service.dart` ❌ (replaced by SubscriptionManager)

## Next Steps

1. **Backend Setup:**
   - Update FastAPI to add device-based endpoints
   - Add Device table to database
   - Test purchase verification

2. **Google Play Console:**
   - Create subscription products
   - Set up test track
   - Add test users

3. **Testing:**
   - Test purchase flow on real device
   - Verify backend verification
   - Test restore purchases

4. **Production:**
   - Deploy backend changes
   - Update API base URL in `api_service.dart`
   - Submit app to Google Play

## Support & Troubleshooting

**Issue:** Premium status not syncing
- Check internet connection
- Verify backend is running
- Check device ID in SharedPreferences

**Issue:** Purchase not completing
- Ensure product IDs match Google Play Console
- Check backend logs for verification errors
- Verify Google Play service account permissions

**Issue:** Premium lost after reinstall
- User must tap "Restore Purchases"
- Requires same Google account
- Backend will link new device ID to existing subscription
