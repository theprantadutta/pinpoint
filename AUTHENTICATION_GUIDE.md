# Authentication System Guide

## ✅ Implementation Status: COMPLETE

The Firebase Authentication with Google Sign-In is **fully implemented** and ready to use!

## 🔍 Where to Find It

### **Automatic Prompt on First Launch**

When you first complete the onboarding process, the app will automatically show a welcome dialog asking if you want to sign in. This happens only once:

- **"Welcome to Pinpoint!"** dialog
- Message: "Sign in to sync your notes across devices and keep them safe in the cloud."
- Options:
  - **"Sign In"** - Takes you directly to the authentication screen
  - **"Skip for now"** - Continue to the app (you can sign in later from the Account screen)

### **Account Screen** (Bottom Navigation → Settings/Account Tab)

The Account screen shows:

1. **When NOT logged in:**
   - A "Sign In" button under the "Account" section
   - Subtitle: "Sign in to sync your notes"
   - Tap this to open the authentication screen

2. **When logged in:**
   - Your email address
   - Google account status (Linked/Not Linked)
   - Options to link/unlink Google account

## 🚀 How to Use

### First Time Setup

1. **Start the Backend Server:**
   ```bash
   cd G:\MyProjects\pinpoint_backend
   python -m uvicorn app.main:app --reload
   ```
   Backend will run at: http://localhost:8000

2. **Run the Flutter App:**
   ```bash
   cd G:\MyProjects\pinpoint
   flutter run
   ```

3. **Sign In:**
   - Open the app
   - Go to Account screen (bottom nav, 4th tab)
   - Scroll down to "Account" section
   - Tap "Sign In"

### Authentication Screen Features

The `/auth` screen provides:

#### **Primary Method: Google Sign-In** (Large button at top)
- One-tap authentication with your Google account
- Automatic account creation if new user
- Account linking if email already exists

#### **Secondary Method: Email/Password** (Form below)
- Toggle between Login and Sign Up
- Manual email/password registration
- Works independently of Google

### Account Linking Flow

If you:
1. Create account with email: `test@example.com`
2. Try to sign in with Google using same email

The app will:
- Detect the conflict
- Navigate to Account Linking screen
- Ask for your password to verify ownership
- Link both methods to same account

## 📱 Available Routes

```dart
/auth                  // Main authentication screen
/account-linking       // Account linking screen (automatic)
/account              // Account settings (shows auth status)
```

## 🎯 Current Status

✅ **Backend:**
- Firebase Admin SDK initialized
- Auth endpoints implemented
- JWT token generation
- Account linking logic

✅ **Flutter:**
- Google Sign-In service
- Auth screens with UI
- Account management
- Providers configured
- Routes registered

✅ **UI Integration:**
- Sign In button in Account screen
- Linked accounts display
- Link/Unlink functionality
- Error handling

## 🔧 Backend Configuration

Already configured in `.env`:
```
FIREBASE_PROJECT_ID=pinpoint-8f6e5
GOOGLE_WEB_CLIENT_ID=627112690345-71dbomndudu8plt93p2jirbb3pfv3uuv.apps.googleusercontent.com
```

## ⚠️ Important Notes

### Backend Must Be Running
The app REQUIRES the backend server to be running for authentication to work:
```bash
cd G:\MyProjects\pinpoint_backend
python -m uvicorn app.main:app --reload
```

### iOS Configuration Needed
For iOS, you still need to:
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place in `ios/Runner/`
3. Update `Info.plist:65` with actual REVERSED_CLIENT_ID

### Android SHA-1 Needed
For Android Google Sign-In:
```bash
cd android
./gradlew signingReport
# Add SHA-1 to Firebase Console
```

## 🧪 Testing Checklist

### First Launch Experience
- [ ] Start backend server
- [ ] Run Flutter app for the first time (or clear app data)
- [ ] Complete onboarding
- [ ] See "Welcome to Pinpoint!" authentication prompt
- [ ] Test "Sign In" button - should navigate to auth screen
- [ ] Test "Skip for now" - should go to home screen

### Account Screen
- [ ] Navigate to Account screen (bottom nav, 4th tab)
- [ ] See "Sign In" button under "Account" section
- [ ] Tap "Sign In"
- [ ] See Auth screen with Google button and email/password form

### Authentication Methods
- [ ] Try Google Sign-In
- [ ] Try email/password registration
- [ ] Check linked accounts display after successful login
- [ ] Verify email is shown in Account section

## 🐛 Troubleshooting

**"I didn't see the authentication prompt on first launch"**
- The prompt only appears once after completing onboarding
- If you skipped it, you can still sign in from the Account screen
- To see it again: Clear app data or set `kHasSeenAuthPromptKey` to false in SharedPreferences

**"Sign In button not showing in Account screen"**
- Make sure you're scrolled down to "Account" section
- Check if BackendAuthService is initialized (should be automatic)
- Verify you're not already signed in (button only shows when not authenticated)

**"Google Sign-In fails"**
- Ensure backend server is running
- Check `.env` file has GOOGLE_WEB_CLIENT_ID
- Verify google-services.json exists in android/app/

**"Authentication succeeds but API calls fail"**
- Check backend URL in `lib/services/api_service.dart` (currently localhost:8000)
- Verify JWT token is saved (should happen automatically)

## 📝 Code Locations

- Splash Screen (Auth Prompt): `lib/screens/splash_screen.dart` (lines 29-102)
- Auth Screen: `lib/screens/auth_screen.dart`
- Account Screen: `lib/screens/account_screen.dart` (lines 260-279, 815-1110)
- Backend Auth Service: `lib/services/backend_auth_service.dart`
- Google Sign-In Service: `lib/services/google_sign_in_service.dart`
- Shared Preference Keys: `lib/constants/shared_preference_keys.dart` (line 22)
- Backend Auth Endpoints: `G:\MyProjects\pinpoint_backend\app\api\v1\auth_firebase.py`
