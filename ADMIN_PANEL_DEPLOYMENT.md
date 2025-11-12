# Admin Panel Deployment Guide

## Overview

This guide will help you deploy the secure admin panel for PinPoint. The admin panel allows `prantadutta1997@gmail.com` to view user data, notes, encryption keys, and sync history for debugging purposes.

---

## Backend Deployment

### Step 1: Install Dependencies

```bash
cd G:\MyProjects\pinpoint_backend
pip install -r requirements.txt
```

This will install `slowapi` for rate limiting and all other dependencies.

### Step 2: Configure Environment Variables

Add the following to your `.env` file:

```bash
# Admin Panel Configuration
ADMIN_EMAIL=prantadutta1997@gmail.com
ADMIN_PASSWORD=FuckThatAremisFowlMovie007
ADMIN_JWT_EXPIRE_MINUTES=60
```

**IMPORTANT SECURITY NOTES:**
- Keep the ADMIN_PASSWORD extremely secure
- Never commit `.env` to version control
- Change the password in production
- Admin sessions expire after 1 hour for security

### Step 3: Run Database Migrations

```bash
cd G:\MyProjects\pinpoint_backend
./venv/Scripts/python.exe -m alembic upgrade head
```

This will create:
1. The `admin_audit_logs` table for tracking all admin actions
2. The unique constraint on `(user_id, client_note_id)` (from previous fix)

### Step 4: Verify Migration

```bash
./venv/Scripts/python.exe -m alembic current
```

Should show: `20251112_0100 (head)`

### Step 5: Restart Backend Server

```bash
cd G:\MyProjects\pinpoint_backend
./venv/Scripts/python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Step 6: Test Admin Authentication

Test the admin login endpoint:

```bash
curl -X POST http://localhost:8000/api/v1/admin/auth \
  -H "Content-Type: application/json" \
  -d '{"email":"prantadutta1997@gmail.com","password":"FuckThatAremisFowlMovie007"}'
```

Expected response:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

---

## Frontend Deployment

### Step 1: No additional dependencies needed

All Flutter dependencies are already in `pubspec.yaml`.

### Step 2: Run the App

```bash
cd G:\MyProjects\pinpoint
flutter run
```

### Step 3: Test Admin Panel Access

1. Login with `prantadutta1997@gmail.com`
2. Go to Settings/Account screen
3. You should see "Admin Panel" button
4. Click it and enter password: `FuckThatAremisFowlMovie007`
5. Admin panel should open

---

## Admin Panel Features

### User List View
- **Path:** `/admin-panel`
- **Features:**
  - Paginated list of all users
  - Search by email or name
  - View user subscription status
  - Click user to see details

### User Details View
- **Path:** `/admin-panel/user/{userId}`
- **Tabs:**
  1. **Overview** - User info, stats, subscription details
  2. **Notes** - All encrypted notes with metadata
  3. **Encryption** - User's encryption key (HIGHLY SENSITIVE)
  4. **Sync** - Sync event history
  5. **Subscription** - Subscription event history

### Key Features:
- Copy to clipboard functionality
- Show/hide encryption key
- Include deleted notes toggle
- Real-time data from database

---

## Security Features

### Backend Security:
✅ **Multi-layer Authentication:**
- JWT token verification
- Email verification (must match ADMIN_EMAIL)
- Rate limiting (5 login attempts per minute)
- Token expiration (1 hour)

✅ **Comprehensive Audit Logging:**
- All admin actions logged to `admin_audit_logs` table
- Includes: action, timestamp, IP address, user agent
- Immutable audit trail for compliance

✅ **Endpoint Protection:**
- All admin endpoints require valid admin JWT
- Automatic token expiration handling
- No bypassing authentication

### Frontend Security:
✅ **Visibility Control:**
- Admin button only visible to `prantadutta1997@gmail.com`
- Not visible to other users

✅ **Password Protection:**
- Password required every time
- Admin token stored in memory only (not persisted)
- Token cleared on logout

✅ **Sensitive Data Protection:**
- Encryption keys hidden by default
- Show/hide toggle for viewing
- Warning messages for critical data

---

## Testing the Admin Panel

### Test 1: Admin Authentication

1. Open app and login as `prantadutta1997@gmail.com`
2. Go to Settings
3. Click "Admin Panel"
4. Enter correct password → Should grant access
5. Enter wrong password → Should show error
6. Try 6 times quickly → Should hit rate limit

### Test 2: View User List

1. Access admin panel
2. Should see list of all users
3. Try search functionality
4. Test pagination if more than 20 users

### Test 3: View User Details

1. Click on a user from list
2. Should show user details
3. Navigate through all 5 tabs
4. Verify all data loads correctly

### Test 4: View Encryption Key

1. Go to user details → Encryption tab
2. Should see hidden key (••••••)
3. Click show → Should reveal actual key
4. Click copy → Should copy to clipboard

### Test 5: Check Audit Logging

Query the database to verify logging:

```sql
SELECT * FROM admin_audit_logs
ORDER BY timestamp DESC
LIMIT 10;
```

Should see entries for:
- Login attempts
- User list views
- User detail views
- Encryption key views

---

## Debugging Sync Issues (Primary Use Case)

### Scenario: User can't see synced notes on new device

1. **Access Admin Panel**
   - Login as admin
   - Go to Admin Panel
   - Search for user by email

2. **Check User Details**
   - Click on user
   - Check "Statistics" section:
     - Total Notes
     - Synced Notes
     - Last Sync timestamp

3. **Check Notes Tab**
   - See all notes in database
   - Check client_note_id values
   - Check encrypted_data is present
   - Check metadata

4. **Check Encryption Tab**
   - Verify encryption key exists
   - Copy key for testing (if needed)

5. **Check Sync Tab**
   - Look at sync event history
   - Check for failed syncs
   - Check device_id
   - Check notes_synced count

6. **Common Issues:**
   - **No notes in database** → Upload failed
   - **Notes exist but Last Sync is old** → Download not triggering
   - **No encryption key** → Key not uploaded
   - **Different encryption keys** → Key mismatch between devices

---

## Quick Start

1. **Backend:**
```bash
cd G:\MyProjects\pinpoint_backend
pip install -r requirements.txt
# Add admin credentials to .env
./venv/Scripts/python.exe -m alembic upgrade head
./venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

2. **Frontend:**
```bash
cd G:\MyProjects\pinpoint
flutter run
```

3. **Access Admin Panel:**
   - Login as `prantadutta1997@gmail.com`
   - Go to Settings → Admin Panel
   - Enter password: `FuckThatAremisFowlMovie007`

---

## File Structure Reference

### Backend Files Created:
```
pinpoint_backend\
├── app\
│   ├── models\admin.py (NEW)
│   ├── schemas\admin.py (NEW)
│   ├── core\admin_dependencies.py (NEW)
│   ├── services\admin_service.py (NEW)
│   └── api\v1\admin.py (NEW)
└── alembic\versions\20251112_0100_add_admin_audit_logs.py (NEW)
```

### Frontend Files Created:
```
pinpoint\
├── lib\
│   ├── services\admin_api_service.dart (NEW)
│   ├── widgets\admin_password_dialog.dart (NEW)
│   └── screens\
│       ├── admin_panel_screen.dart (NEW)
│       └── admin_user_details_screen.dart (NEW)
```

---

## Security Disclaimer

**CRITICAL:** This admin panel provides access to EXTREMELY SENSITIVE user data including:
- Personal information (emails, names)
- Encrypted notes (can be decrypted with encryption key)
- Encryption keys (allows decrypting ALL user notes)
- Sync history
- Subscription information

**IMPORTANT REMINDERS:**
1. Only use for debugging legitimate issues
2. Never share admin credentials
3. Don't leave admin panel open unattended
4. Logout when done
5. All access is logged and auditable
6. Handle encryption keys with extreme care

Use responsibly and in compliance with your privacy policy!

---

**Admin Panel Version:** 1.0
**Last Updated:** 2025-11-12
