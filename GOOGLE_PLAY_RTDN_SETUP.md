# Google Play RTDN (Real-Time Developer Notifications) Setup Guide

This guide explains how to set up Google Play RTDN to receive real-time subscription events (purchases, renewals, cancellations, grace periods, etc.)

---

## Part 1: Google Cloud Console Setup

### 1.1 Create a Pub/Sub Topic

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Search for **Pub/Sub** in the search bar
4. Go to **Topics**
5. Click **CREATE TOPIC**
6. Enter Topic ID: `play-billing-notifications`
7. Click **CREATE**

Your full topic name will be:
```
projects/YOUR_PROJECT_ID/topics/play-billing-notifications
```

### 1.2 Grant Google Play Publisher Access

1. Click on the topic you just created
2. Go to the **PERMISSIONS** tab
3. Click **ADD PRINCIPAL**
4. In "New principals" enter:
   ```
   google-play-developer-notifications@system.gserviceaccount.com
   ```
5. In "Role" select: **Pub/Sub Publisher**
6. Click **SAVE**

### 1.3 Create a Push Subscription

1. In the same topic, click **CREATE SUBSCRIPTION**
2. Subscription ID: `play-billing-push`
3. Delivery type: **Push**
4. Endpoint URL:
   ```
   https://YOUR_BACKEND_DOMAIN/api/v1/webhooks/google-play?token=YOUR_SECRET_TOKEN
   ```

   Replace:
   - `YOUR_BACKEND_DOMAIN` = your backend URL (e.g., api.yourapp.com)
   - `YOUR_SECRET_TOKEN` = a random secure string you create

5. Click **CREATE**

---

## Part 2: Google Play Console Setup

1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app
3. Navigate to: **Monetization** > **Monetization setup**
4. Scroll to **Real-time developer notifications**
5. Enter your topic name:
   ```
   projects/YOUR_PROJECT_ID/topics/play-billing-notifications
   ```
6. Click **Save changes**

---

## Part 3: Backend Configuration

### 3.1 Update Environment Variables

Add to your `.env` file:

```env
GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN=YOUR_SECRET_TOKEN
```

Use the SAME token you used in the Push subscription URL.

### 3.2 Run Database Migration

```bash
cd F:\Personal\MyProjects\pinpoint_backend
.\venv\Scripts\python.exe -m alembic upgrade head
```

---

## Part 4: Testing

### 4.1 Check Webhook Health

After deploying, visit:
```
https://YOUR_BACKEND_DOMAIN/api/v1/webhooks/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "webhooks",
  "google_play_configured": true
}
```

### 4.2 Send Test Notification

1. In Google Play Console, go to **Monetization** > **Monetization setup**
2. Click **Send test notification**
3. Check your backend logs for the test notification

---

## Webhook Events Handled

The webhook automatically handles these subscription events:

| Event | What Happens |
|-------|--------------|
| SUBSCRIPTION_PURCHASED | Marks device/user as premium |
| SUBSCRIPTION_RENEWED | Updates expiration date |
| SUBSCRIPTION_CANCELED | Logs cancellation (access until expiry) |
| SUBSCRIPTION_IN_GRACE_PERIOD | Starts 3-day grace period |
| SUBSCRIPTION_ON_HOLD | Starts grace period, sends push notification |
| SUBSCRIPTION_EXPIRED | Reverts to free tier |
| SUBSCRIPTION_REVOKED | Immediately reverts to free tier |
| SUBSCRIPTION_RECOVERED | Clears grace period, restores premium |

---

## Troubleshooting

### Webhook not receiving notifications
- Ensure your backend is deployed and accessible via HTTPS
- Verify the topic name matches exactly in both consoles
- Check that the service account has Publisher permissions

### Invalid token errors
- Make sure `GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN` in .env matches the token in your Push subscription URL

### Grace period not working
- Run the Alembic migration to add the `grace_period_ends_at` column
- Check backend logs for webhook processing errors

---

## Quick Reference

| Item | Value |
|------|-------|
| Pub/Sub Topic | `projects/YOUR_PROJECT_ID/topics/play-billing-notifications` |
| Service Account | `google-play-developer-notifications@system.gserviceaccount.com` |
| Webhook Endpoint | `/api/v1/webhooks/google-play` |
| Grace Period | 3 days (configurable in settings) |
