# Phishing Detection App - Setup Guide

## Current Features

✅ **Read SMS Messages** - Display all SMS messages with read/unread status
✅ **Read WhatsApp Messages** - See WhatsApp notifications via Notification Listener  
✅ **Background Service** - Listen for incoming SMS even when app is closed
✅ **Read/Unread Status** - Know which messages are already read vs unread
✅ **User Consent** - Start/stop background service with user permission

## Setup Instructions

### 1. Install Dependencies

```bash
cd d:\my project\my_app
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

### 3. Grant Permissions

When the app first runs, grant these permissions:
- **SMS Permission** - To read SMS messages
- **Notification Listener** - To see WhatsApp/other app notifications
- **Internet** - For future backend integration

### 4. Enable Notification Listener (for WhatsApp)

The app will prompt you to enable Notification Listener Service:
- Go to Settings → Notifications → Notification access/Notification listener
- Enable "Phishing Detector"

### 5. Managing Background Service

**Start Background Listener:**
- User clicks "Start Background Service" button in the app
- Service runs even when app is closed
- Listens for all incoming SMS messages

**Stop Background Listener:**
- User clicks "Stop Background Service" button
- Service stops listening

## Features Explained

### 1. SMS Read/Unread Status
The app reads from Android's SMS Provider and gets:
- Message sender
- Message body
- Date/time
- **Read status** - Whether user has already read the message from default SMS app

This is displayed with a visual indicator (✓ for read, ○ for unread)

### 2. WhatsApp Messages
Via Notification Listener Service:
- Shows WhatsApp message notifications captured from the system
- Displays sender name and message preview
- Works for incoming messages while app is active

### 3. Background Service
- **SmsListenerService** - Runs in the background continuously
- **SmsReceiver** - BroadcastReceiver that triggers when new SMS arrives
- **Automatic Refresh** - App can fetch messages periodically
- **Persistent** - Service keeps running even if app is closed or device is locked

## Future: Add AI Backend Logic

When ready to add backend analysis, follow these steps:

### 1. Uncomment HTTP dependency in pubspec.yaml:
```yaml
dependencies:
  http: ^1.1.0  # Uncomment this
```

### 2. Restore the AI Backend Service:
- The `ai_backend_service.dart` has a placeholder
- Add HTTP calls to your Python backend
- Backend should accept: sender, message, timestamp
- Backend should return: risk_score, classification

### 3. Python Backend Example (optional):
```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    # Your AI logic here
    return jsonify({
        'risk_score': 0.5,
        'classification': 'suspicious'
    })
```

### 4. Call AI Service in Flutter:
```dart
// In your message loading code:
final result = await AiBackendService.analyzeSms(
  sender: message.address,
  message: message.body,
);
```

## File Structure

```
android/app/src/main/
├── kotlin/com/example/my_app/
│   ├── MainActivity.kt - Handles SMS reading with read/unread status
│   ├── NotificationListenerService.kt - Captures WhatsApp notifications
│   └── SmsListenerService.kt - Background SMS listener
└── AndroidManifest.xml - Permissions and service registration

lib/src/
├── services/
│   ├── platform_service.dart - Calls Android native code
│   ├── background_listener_service.dart - Manages background service
│   ├── ai_backend_service.dart - (Placeholder for future AI backend)
│   └── prefs_service.dart - Shared preferences helper
├── models/
│   └── message.dart - Message data model (with read/unread status)
└── main.dart - Main UI
```

## Technical Details

### Android Permissions Used

```xml
<!-- Read SMS -->
<uses-permission android:name="android.permission.READ_SMS" />

<!-- Receive incoming SMS (background service) -->
<uses-permission android:name="android.permission.RECEIVE_SMS" />

<!-- Send SMS if needed -->
<uses-permission android:name="android.permission.SEND_SMS" />

<!-- WhatsApp notifications -->
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />

<!-- Network for future backend -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Background Service Lifecycle

1. **Start Service** (from Flutter UI)
   - SmsListenerService is started
   - BroadcastReceiver registers for SMS_RECEIVED_ACTION
   - Service runs with START_STICKY (survives app kill)

2. **SMS Arrives**
   - SmsReceiver.onReceive() is triggered
   - Message data is logged
   - (In future: Could send to backend for analysis)

3. **Stop Service** (from Flutter UI)
   - SmsListenerService is stopped
   - BroadcastReceiver is unregistered

## Troubleshooting

**Background service not starting?**
- Check if SMS permission is granted
- Try restarting the app
- Check Android device battery optimization settings

**SMS not showing read/unread status?**
- Android SMS ContentProvider might have restrictions on some devices
- Fallback: Mark messages as read when user opens them in your app

**WhatsApp messages not appearing?**
- Make sure Notification Listener is enabled in Settings
- Some devices restrict notification access for privacy
- Option: Implement AccessibilityService for better capture (requires more permissions)

## Support for Future Enhancements

When adding AI backend:
1. Configure backend URL in settings
2. Send messages for analysis when they arrive (background)
3. Create UI to show phishing risk score
4. Add notifications for high-risk messages
5. Implement local caching of analysis results

---

**All code is ready - just add your backend logic when needed!**
