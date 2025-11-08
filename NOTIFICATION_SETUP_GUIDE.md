# 🔔 Pinpoint Notification System - Setup & Testing Guide

## Overview

Your Pinpoint app now has a complete push notification system using Firebase Cloud Messaging (FCM). This guide explains how everything works and how to test it.

## ✅ What's Already Implemented

### Flutter App (Frontend)
- ✅ **firebase_messaging** package installed
- ✅ **FirebaseNotificationService** created and initialized
- ✅ Notification permissions handling
- ✅ FCM token generation and registration
- ✅ Foreground notification handling
- ✅ Background notification handling
- ✅ Notification tap handling
- ✅ Test button in Account screen
- ✅ Firebase configured for Android, iOS, Web, Windows

### Backend (FastAPI)
- ✅ Notification endpoints created
- ✅ FCM token storage in database
- ✅ Test notification endpoint (`/api/v1/notifications/test`)
- ✅ Send notification endpoint (`/api/v1/notifications/send`)

## 🚀 How to Test Notifications

### Method 1: Test Button in App (Easiest)

1. **Run the Flutter app:**
   ```bash
   flutter run
   ```

2. **Navigate to:**
   - Account Screen (Settings icon in bottom navigation)
   - Scroll down to "General" section
   - Click on "Test Notification" 🔔

3. **See the notification:**
   - You should see a toast: "🔔 Test Notification Sent!"
   - Check your notification tray for the test notification

### Method 2: Test via Backend API

1. **Make sure backend is running:**
   ```bash
   cd G:\MyProjects\pinpoint_backend
   uvicorn app.main:app --reload
   ```

2. **Open test HTML file in browser:**
   ```
   G:\MyProjects\pinpoint_backend\test_notification.html
   ```

3. **Click "Test Notification System"**

4. **Or use cURL:**
   ```bash
   curl -X POST http://localhost:8000/api/v1/notifications/test
   ```

## 📱 How It Works

### Notification Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      NOTIFICATION FLOW                       │
└─────────────────────────────────────────────────────────────┘

1. App Initialization
   ├── Firebase initializes
   ├── Requests notification permissions
   │   ├── Android 13+: POST_NOTIFICATIONS permission
   │   ├── iOS: Alert, Badge, Sound permissions
   │   └── Creates notification channels (Android 8+)
   ├── Gets FCM token from Firebase
   ├── Sends token to backend
   └── Backend stores token in database

2. Sending Notification
   ├── Backend receives send request
   ├── Gets FCM tokens for user/device
   ├── Calls Firebase Cloud Messaging API
   └── Firebase sends to device(s)

3. Receiving Notification
   ├── FOREGROUND: Shows local notification via flutter_local_notifications
   ├── BACKGROUND: Android/iOS handles display
   ├── TERMINATED: Firebase wakes app
   └── TAP: Opens app and navigates
```

### Notification States

| App State | Handled By | Display |
|-----------|------------|---------|
| **Foreground** | FlutterLocalNotifications | Custom notification |
| **Background** | Firebase + OS | System notification |
| **Terminated** | Firebase + OS | System notification |

## 🔧 Setup for Real Notifications

### Already Configured ✅

Your Firebase project and native configurations are already set up:
- **Project ID:** `pinpoint-8f6e5`
- **Android configured** ✅
  - ✅ Java 11 compatibility in build.gradle
  - ✅ Notification permissions in AndroidManifest.xml
  - ✅ Notification receivers configured
  - ✅ Android 13+ permission handling in code
  - ✅ Notification channels created
- **iOS configured** ✅
  - ✅ UNUserNotificationCenter delegate in AppDelegate
  - ✅ UserNotifications framework imported
  - ✅ Foreground presentation configured
- **Web configured** ✅
- **Windows configured** ✅

### What You Need to Do

1. **Get Firebase Admin SDK Credentials**

   Follow the guide in `G:\MyProjects\pinpoint_backend\CREDENTIALS_SETUP_GUIDE.md`

   Quick steps:
   - Go to Firebase Console: https://console.firebase.google.com/
   - Select project: `pinpoint-8f6e5`
   - Settings → Service accounts
   - Generate new private key
   - Save as: `firebase-admin-sdk.json`
   - Place in: `G:\MyProjects\pinpoint_backend\`

2. **For Android: Add google-services.json**

   ```
   G:\MyProjects\pinpoint\android\app\google-services.json
   ```

   Get it from:
   - Firebase Console → Project Settings → Your Android app
   - Download `google-services.json`

3. **For iOS: Add GoogleService-Info.plist**

   ```
   G:\MyProjects\pinpoint\ios\Runner\GoogleService-Info.plist
   ```

   Get it from:
   - Firebase Console → Project Settings → Your iOS app
   - Download `GoogleService-Info.plist`

### Native Configuration Details ✅

The following native configurations have been properly set up per flutter_local_notifications documentation:

**Android:**
- ✅ Java 11 compatibility (`android/app/build.gradle`)
- ✅ Core library desugaring enabled
- ✅ Notification permissions in `AndroidManifest.xml`:
  - `POST_NOTIFICATIONS` (Android 13+)
  - `VIBRATE`
  - `RECEIVE_BOOT_COMPLETED`
- ✅ Notification receivers configured for scheduled notifications
- ✅ Android 13+ runtime permission handling in `FirebaseNotificationService`
- ✅ Notification channels created programmatically

**iOS:**
- ✅ `UNUserNotificationCenter` delegate configured in `AppDelegate.swift`
- ✅ `UserNotifications` framework imported
- ✅ Foreground notification presentation configured

## 📲 Testing on Real Devices

### Android

1. **Connect Android device or start emulator**

2. **Run app:**
   ```bash
   flutter run
   ```

3. **When app launches:**
   - Permission dialog appears
   - Tap "Allow" for notifications

4. **Test notification:**
   - Go to Account screen
   - Tap "Test Notification"
   - See notification in tray

### iOS

1. **Connect iOS device** (Simulator won't receive real notifications)

2. **Run app:**
   ```bash
   flutter run
   ```

3. **Permission dialog:**
   - Tap "Allow"

4. **Test notification:**
   - Same as Android

## 🛠️ Troubleshooting

### "Firebase not initialized" Error

**Solution:**
```bash
# Make sure you have the Firebase credentials
cd G:\MyProjects\pinpoint
flutter clean
flutter pub get
flutter run
```

### Notifications Not Appearing

**Check:**
1. ✅ Notification permissions granted
2. ✅ Firebase initialized successfully (check logs)
3. ✅ FCM token generated (check logs)
4. ✅ Device not in Do Not Disturb mode

**Debug logs:**
```dart
// Check console for these messages:
🔔 Initializing Firebase Notifications...
✅ Firebase initialized
📋 Notification permission status: authorized
📱 FCM Token: [your-token]
✅ FCM token registered with backend
```

### "FCM token is null"

**Reasons:**
- Firebase not initialized
- Permissions denied
- Network issues

**Fix:**
```bash
# Restart app
flutter run
```

### Backend Can't Send Notifications

**Check:**
1. ✅ `firebase-admin-sdk.json` exists in backend root
2. ✅ Backend is running
3. ✅ FCM tokens are stored in database

**Test backend:**
```bash
cd G:\MyProjects\pinpoint_backend
python test_notification.py
```

## 📝 Sending Custom Notifications

### From Backend (Python)

```python
from firebase_admin import messaging

# Send to specific device
message = messaging.Message(
    notification=messaging.Notification(
        title='📝 New Note Reminder',
        body='Remember to review your notes!',
    ),
    data={
        'type': 'note_reminder',
        'note_id': '12345',
    },
    token=fcm_token  # User's FCM token
)

response = messaging.send(message)
print(f'Successfully sent: {response}')
```

### From Backend API (REST)

```bash
curl -X POST http://localhost:8000/api/v1/notifications/send \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Notification",
    "body": "This is a test notification",
    "data": {
      "type": "test",
      "action": "open_app"
    }
  }'
```

## 🎯 Notification Types

You can implement different notification types:

| Type | Title | Action |
|------|-------|--------|
| **Note Reminder** | "📝 Note Reminder" | Open specific note |
| **Sync Complete** | "✅ Sync Complete" | Show sync status |
| **Premium Upgrade** | "🎉 Welcome to Premium" | Open subscription screen |
| **Daily Summary** | "📊 Your Daily Summary" | Open home screen |

## 🔐 Security

### FCM Token Protection

- ✅ Tokens stored securely in database
- ✅ Tokens tied to device ID
- ✅ Tokens auto-refresh when expired
- ✅ Tokens removed on logout

### Notification Data

- ✅ All data encrypted in transit (HTTPS)
- ✅ No sensitive data in notification payload
- ✅ Authentication required for sending
- ✅ Device-specific tokens

## 📊 Monitoring

### Check Notification Status

```dart
// In your Flutter app
final notificationService = FirebaseNotificationService();

print('Firebase initialized: ${notificationService.isInitialized}');
print('FCM Token: ${notificationService.fcmToken}');
```

### Backend Logs

```python
# Check backend logs for:
- "FCM token registered for device: {device_id}"
- "Notification sent successfully"
- "Error sending notification: {error}"
```

## 🎉 Testing Checklist

- [ ] Flutter app runs without errors
- [ ] Firebase initializes successfully
- [ ] Permission dialog appears
- [ ] FCM token generated
- [ ] Token registered with backend
- [ ] Test button sends notification
- [ ] Notification appears in foreground
- [ ] Notification appears in background
- [ ] Tapping notification opens app
- [ ] Backend can send notifications
- [ ] Notifications work on real device

## 📚 Next Steps

1. **Implement Scheduled Notifications**
   - Note reminders at specific times
   - Daily summaries

2. **Notification Categories**
   - Different channels for different types
   - User can customize per category

3. **Rich Notifications**
   - Images in notifications
   - Action buttons
   - Expandable content

4. **Analytics**
   - Track notification open rates
   - Monitor delivery success

## 🆘 Getting Help

**Common Issues:**

1. **"Notification not showing"**
   - Check permissions
   - Check Firebase initialization
   - Check backend logs

2. **"Token not registered"**
   - Check internet connection
   - Check backend is running
   - Check API endpoints

3. **"Firebase error"**
   - Check `firebase-admin-sdk.json` exists
   - Check credentials are valid
   - Check project ID matches

**Debug Mode:**

Enable verbose logging:
```dart
// In firebase_notification_service.dart
debugPrint('🔔 [DEBUG] Full message: ${message.toString()}');
```

---

**Ready to test!** Go to Account Screen → Test Notification 🔔
