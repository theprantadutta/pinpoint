# Pinpoint - Payment & Backend Integration Summary

## Overview

This document provides a comprehensive overview of the backend authentication and Google Play subscription system integration into the Pinpoint Flutter app.

## Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Pinpoint)     │
└────────┬────────┘
         │
         ├─── Provider (State Management)
         │    └─── BackendAuthService
         │
         ├─── Services Layer
         │    ├─── ApiService (HTTP Client)
         │    └─── SubscriptionService (Google Play)
         │
         ├─── Screens
         │    ├─── SplashScreen
         │    ├─── OnboardingScreen
         │    ├─── LoginScreen
         │    ├─── RegisterScreen
         │    ├─── SubscriptionScreen
         │    └─── AccountScreen (Premium Status)
         │
         └─── HTTP Requests
              │
              ▼
     ┌─────────────────┐
     │  FastAPI Backend│
     │  (Python)       │
     └────────┬────────┘
              │
              ├─── Authentication (JWT)
              ├─── Note Sync (E2E Encrypted)
              ├─── Subscription Verification
              └─── Push Notifications
              │
              ▼
     ┌─────────────────┐
     │   PostgreSQL    │
     │   Database      │
     └─────────────────┘
              │
              ▼
     ┌─────────────────┐
     │  Google Play    │
     │  API (Verify)   │
     └─────────────────┘
```

## Implementation Details

### 1. Authentication Flow

#### User Registration
1. User fills registration form (`RegisterScreen`)
2. App calls `BackendAuthService.register(email, password)`
3. Service calls `ApiService.register()` → POST `/api/v1/auth/register`
4. Backend creates user in database
5. Returns JWT access token
6. Token stored in `FlutterSecureStorage`
7. App navigates to `HomeScreen`

#### User Login
1. User fills login form (`LoginScreen`)
2. App calls `BackendAuthService.login(email, password)`
3. Service calls `ApiService.login()` → POST `/api/v1/auth/login`
4. Backend validates credentials
5. Returns JWT access token + user data
6. Token stored, user data cached
7. App navigates to `HomeScreen`

#### Session Persistence
- On app launch, `SplashScreen` checks:
  1. Has user completed onboarding? → If no, go to `OnboardingScreen`
  2. Is user authenticated? → If no, go to `LoginScreen`
  3. If yes to both → go to `HomeScreen`
- `BackendAuthService.initialize()` attempts to restore session from stored token

### 2. Subscription System

#### Product Setup (Google Play Console)

Three subscription products defined in `GOOGLE_PLAY_SUBSCRIPTIONS.md`:

| Product ID | Type | Price | Billing Period | Trial |
|------------|------|-------|----------------|-------|
| `pinpoint_premium_monthly` | Auto-renewable | $4.99 | 1 month | 14 days |
| `pinpoint_premium_yearly` | Auto-renewable | $39.99 | 12 months | 14 days |
| `pinpoint_premium_lifetime` | Non-consumable | $99.99 | One-time | None |

#### Purchase Flow

1. **User initiates purchase** from `SubscriptionScreen`
   ```dart
   _subscriptionService.purchase('pinpoint_premium_monthly')
   ```

2. **SubscriptionService handles Google Play**
   - Initiates purchase via `InAppPurchase` plugin
   - Google Play shows payment dialog
   - User completes payment
   - Returns `PurchaseDetails` with `purchaseToken`

3. **Client sends verification request**
   ```dart
   BackendAuthService.verifyPurchase(
     purchaseToken: details.verificationData.serverVerificationData,
     productId: details.productID
   )
   ```

4. **Backend verifies with Google Play**
   - POST `/api/v1/subscription/verify`
   - Backend calls Google Play API to verify token
   - Checks subscription validity, expiry date
   - Updates user record in database:
     ```python
     user.subscription_tier = "premium"
     user.subscription_product_id = "pinpoint_premium_monthly"
     user.subscription_expires_at = datetime(...)
     ```

5. **Client updates UI**
   - `BackendAuthService` updates `isPremium` property
   - `notifyListeners()` triggers UI rebuild
   - Account screen shows premium badge
   - Premium features unlocked

#### Subscription Status Display

In `AccountScreen`, subscription section shows:

**For Premium Users:**
```
┌─────────────────────────────────────┐
│ 👑 Premium Active                   │
│ Thank you for your support!         │
│                    [PREMIUM Badge]  │
└─────────────────────────────────────┘
```

**For Free Users:**
```
┌─────────────────────────────────────┐
│ ⭐ Upgrade to Premium                │
│ Unlock all features                 │
│                              →      │
└─────────────────────────────────────┘
```

### 3. Premium Features

Features available only to premium subscribers:

1. **Cloud Sync** - Sync notes across devices
2. **Advanced Encryption** - Additional security layers
3. **Unlimited Notes** - Free tier limited to 100 notes
4. **Priority Sync** - Faster sync operations
5. **Custom Themes** - Additional theme options
6. **Export Options** - PDF, Markdown export
7. **Voice Notes** - Extended recording time
8. **OCR** - Text recognition from images
9. **Priority Support** - Email support access

### 4. State Management

**BackendAuthService** (ChangeNotifier):
```dart
class BackendAuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isPremium = false;
  String _subscriptionTier = 'free';

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isPremium => _isPremium;
  String get subscriptionTier => _subscriptionTier;

  // Actions
  Future<void> login(String email, String password) async { ... }
  Future<void> register(String email, String password) async { ... }
  Future<void> verifyPurchase(...) async { ... }
  Future<void> refreshSubscriptionStatus() async { ... }
  Future<void> logout() async { ... }
}
```

Used throughout app with Provider:
```dart
// In widget
Consumer<BackendAuthService>(
  builder: (context, authService, child) {
    if (authService.isPremium) {
      return PremiumFeatureWidget();
    }
    return FreeFeatureWidget();
  }
)
```

### 5. API Endpoints

#### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login existing user
- `GET /api/v1/auth/me` - Get current user info

#### Subscription
- `POST /api/v1/subscription/verify` - Verify Google Play purchase
- `GET /api/v1/subscription/status` - Get subscription status

#### Notes (Premium)
- `GET /api/v1/notes/sync` - Get all notes for sync
- `POST /api/v1/notes/sync` - Upload notes to cloud
- `PUT /api/v1/notes/{note_id}` - Update specific note
- `DELETE /api/v1/notes/{note_id}` - Delete specific note

#### Notifications (Premium)
- `POST /api/v1/notifications/register` - Register FCM token
- `POST /api/v1/notifications/send` - Send notification

### 6. Security Measures

#### Password Security
- Passwords hashed with bcrypt (12 rounds)
- Never stored in plaintext
- Transmitted only over HTTPS

#### Token Management
- JWT tokens with 7-day expiry
- Stored in `FlutterSecureStorage` (encrypted)
- Included in Authorization header: `Bearer <token>`

#### End-to-End Encryption
- Notes encrypted client-side before upload
- Server stores only encrypted data
- Encryption key derived from user password
- Uses AES-256-CBC encryption

#### Purchase Verification
- All purchases verified server-side
- Prevents client-side manipulation
- Google Play API validates tokens
- Subscription status cached for 1 hour

## File Structure

### Flutter App (G:\MyProjects\pinpoint\)

```
lib/
├── services/
│   ├── api_service.dart              # HTTP client for backend
│   ├── backend_auth_service.dart     # Auth state management
│   └── subscription_service.dart     # Google Play integration
├── screens/
│   ├── splash_screen.dart            # Entry point with auth check
│   ├── onboarding_screen.dart        # First-time user flow
│   ├── login_screen.dart             # User login
│   ├── register_screen.dart          # User registration
│   ├── subscription_screen.dart      # Paywall/pricing
│   └── account_screen.dart           # Settings with premium status
├── navigation/
│   └── app_navigation.dart           # GoRouter config
└── main.dart                         # App entry with Provider

GOOGLE_PLAY_SUBSCRIPTIONS.md          # Product definitions
INTEGRATION_SUMMARY.md                # This file
```

### Backend (G:\MyProjects\pinpoint_backend\)

```
app/
├── api/
│   └── v1/
│       ├── auth.py                   # Auth endpoints
│       ├── subscription.py           # Subscription endpoints
│       ├── notes.py                  # Note sync endpoints
│       └── notifications.py          # FCM endpoints
├── models/
│   ├── user.py                       # User model
│   └── note.py                       # Note model
├── services/
│   ├── auth_service.py               # JWT handling
│   ├── payment_service.py            # Google Play verification
│   └── encryption_service.py         # E2E encryption helpers
├── config.py                         # Configuration
└── main.py                           # FastAPI app

alembic/                              # Database migrations
requirements.txt                      # Python dependencies
docker-compose.yml                    # Docker deployment
.env                                  # Environment variables
```

## Testing Checklist

### Frontend Testing

- [ ] **Registration Flow**
  - [ ] Open app, complete onboarding
  - [ ] Navigate to Register screen
  - [ ] Enter email and password
  - [ ] Verify successful registration
  - [ ] Check navigation to HomeScreen

- [ ] **Login Flow**
  - [ ] Close and reopen app
  - [ ] Navigate to Login screen
  - [ ] Enter credentials
  - [ ] Verify successful login
  - [ ] Check session persistence

- [ ] **Subscription Flow**
  - [ ] Navigate to Account → Subscription
  - [ ] View subscription options
  - [ ] Initiate test purchase
  - [ ] Complete Google Play payment
  - [ ] Verify premium status updates
  - [ ] Check premium badge in Account screen

- [ ] **Premium Features**
  - [ ] Verify premium features unlock
  - [ ] Test cloud sync functionality
  - [ ] Check subscription status display

### Backend Testing

- [ ] **Server Startup**
  - [ ] Start PostgreSQL database
  - [ ] Run backend server
  - [ ] Verify API is accessible

- [ ] **Authentication Endpoints**
  - [ ] Test POST /api/v1/auth/register
  - [ ] Test POST /api/v1/auth/login
  - [ ] Test GET /api/v1/auth/me with token

- [ ] **Subscription Endpoints**
  - [ ] Test POST /api/v1/subscription/verify
  - [ ] Verify Google Play API integration
  - [ ] Check database updates

## Deployment Steps

### 1. Backend Deployment

```bash
cd G:\MyProjects\pinpoint_backend

# Set environment variables
cp .env.example .env
# Edit .env with production values

# Using Docker
docker-compose up -d

# Or manual deployment
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 2. Frontend Configuration

Update `ApiService.baseUrl` to production backend URL:
```dart
// lib/services/api_service.dart
static const String baseUrl = 'https://api.pinpoint.app';  // Production
```

### 3. Google Play Console Setup

1. **Create App** in Google Play Console
2. **Set up In-App Products**:
   - Go to Monetization → Products → Subscriptions
   - Create three products using IDs from `GOOGLE_PLAY_SUBSCRIPTIONS.md`
   - Copy product details from markdown file
   - Set pricing for each product
3. **Add Service Account** for backend verification:
   - Create service account in Google Cloud Console
   - Download JSON key
   - Add to backend `.env` as `GOOGLE_APPLICATION_CREDENTIALS`
4. **Enable Real-time Developer Notifications**:
   - Set webhook URL to `https://api.pinpoint.app/api/v1/subscription/webhook`

### 4. Firebase Setup (for Push Notifications)

1. Create Firebase project
2. Add Android app with package name
3. Download `google-services.json`
4. Add to `android/app/` directory
5. Get Server Key from Firebase Console
6. Add to backend `.env` as `FCM_SERVER_KEY`

## Configuration Variables

### Backend (.env)

```bash
# Database
DATABASE_HOST=pranta.vps.webdock.cloud
DATABASE_PORT=5432
DATABASE_NAME=pinpoint
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_secure_database_password_here
DATABASE_SSL=false

# JWT
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080  # 7 days

# Google Play
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
GOOGLE_PLAY_PACKAGE_NAME=com.example.pinpoint

# Firebase
FCM_SERVER_KEY=<your-fcm-server-key>

# CORS
ALLOWED_ORIGINS=https://pinpoint.app,http://localhost:*
```

### Frontend (api_service.dart)

```dart
class ApiService {
  static const String baseUrl = 'https://api.pinpoint.app';  // Production URL

  // or for development:
  // static const String baseUrl = 'http://10.0.2.2:8000';  // Android Emulator
  // static const String baseUrl = 'http://localhost:8000';  // iOS Simulator
}
```

## Troubleshooting

### Issue: "Purchase not verified"
**Solution:**
- Check backend logs for Google Play API errors
- Verify service account has proper permissions
- Ensure product IDs match exactly
- Test purchases require test user added in Play Console

### Issue: "Authentication failed"
**Solution:**
- Check backend is running and accessible
- Verify database connection
- Check JWT secret key is set
- Ensure CORS is properly configured

### Issue: "Session not persisting"
**Solution:**
- Check `FlutterSecureStorage` permissions
- Verify token is being saved
- Check `BackendAuthService.initialize()` is called

### Issue: "Premium status not updating"
**Solution:**
- Check subscription verification completed successfully
- Call `BackendAuthService.refreshSubscriptionStatus()`
- Verify database has updated subscription_tier
- Check token includes updated user data

## Next Steps

1. **Testing**
   - Test all flows thoroughly
   - Use Google Play test tracks for purchase testing
   - Verify subscription renewals work

2. **Production Prep**
   - Deploy backend to production server
   - Update API URLs in Flutter app
   - Configure Google Play Console
   - Set up Firebase

3. **Launch**
   - Submit app to Google Play
   - Monitor backend logs
   - Track subscription conversions
   - Gather user feedback

## Support

For issues or questions:
- Backend issues: Check `pinpoint_backend/logs/`
- Flutter issues: Run `flutter doctor` and check console
- Purchase issues: Check Google Play Console → Order Management
- Database issues: Check PostgreSQL logs

## Changelog

**2025-01-08** - Initial integration complete
- Implemented backend authentication system
- Added Google Play subscription verification
- Created login/register flows
- Integrated subscription/paywall screen
- Added premium status display in account screen
