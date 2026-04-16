# Phishing Detection App - Implementation Guide

## Overview
This Flutter app is designed to detect phishing messages in SMS and WhatsApp notifications using machine learning via a Python backend. The app runs as a background service to continuously monitor incoming messages.

## Features Implemented

### 1. **SMS Read/Unread Status Detection** ✅
- The app now reads the `read` field from Android SMS content provider
- Each message includes:
  - `id`: Message identifier
  - `address`: Sender's phone number
  - `body`: Message content
  - `date`: Timestamp
  - `isRead`: Boolean indicating if message was read in SMS app
  - `type`: Message type (1=received, 2=sent)
  - `source`: "sms"

### 2. **Background SMS Listener Service** ✅
- **SmsListenerService**: Runs in background continuously
- **SmsReceiver**: BroadcastReceiver for incoming SMS
- Automatically captures all SMS messages
- Can process messages without user interaction

### 3. **WhatsApp Notification Monitoring** ✅
- Uses NotificationListenerService to capture WhatsApp notifications
- Monitors notification text in real-time

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                              │
│  - Message Display UI                                       │
│  - Background Service Manager                               │
│  - AI Analysis Integration                                  │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   ┌─────────────┐    ┌──────────────────────┐
   │  Android    │    │  NotificationListener│
   │  SMS API    │    │  Service             │
   └─────────────┘    └──────────────────────┘
        │                     │
        └──────────┬──────────┘
                   ▼
   ┌─────────────────────────────────┐
   │   SmsListenerService            │
   │   - Continuous Monitoring        │
   │   - Pattern Detection            │
   │   - Backend Communication        │
   └──────────────┬────────────────────┘
                  ▼
   ┌──────────────────────────────────────┐
   │  Python AI Backend (ML Model)    │
   │  - Phishing Detection                │
   │  - Risk Scoring                      │
   │  - Pattern Analysis                  │
   └──────────────────────────────────────┘
```

## Implementation Details

### A. Flutter Side Implementation

#### 1. Platform Service Methods
```dart
// Get SMS with read/unread status
getSmsMessagesWithReadStatus()

// Background service control
startBackgroundService()
stopBackgroundService()
isBackgroundServiceRunning()

// AI Analysis
analyzeMessageWithAI(String message)
```

#### 2. Message Model Updated
```dart
class Message {
  final String id;
  final String address;
  final String body;
  final DateTime date;
  final String source; // 'sms' or 'whatsapp'
  final bool isRead; // NEW: read/unread status
  final String? phishingScore; // NEW: AI analysis score
  final String? phishingStatus; // NEW: safe/suspicious/phishing
}
```

### B. Android Side Implementation

#### 1. MainActivity.kt Enhancements
```kotlin
// New methods added:
- getSmsMessagesWithReadStatus()  // Reads SMS with read field
- startBackgroundSmsService()      // Starts background listener
- stopBackgroundSmsService()       // Stops background listener
- isBackgroundServiceRunning()     // Check service status
- sendToAIBackend()                // Forward to Python backend
```

#### 2. New SmsListenerService.kt
- **SmsListenerService**: Service class for background listening
- **SmsReceiver**: Broadcast receiver for SMS events
- Features:
  - Captures all incoming SMS
  - Client-side phishing pattern detection
  - Forwards to Python backend
  - Stores pending analysis in SharedPreferences

#### 3. AndroidManifest.xml Updates
```xml
<!-- New Permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- New Service Registration -->
<service android:name=".SmsListenerService" ... />

<!-- SMS Broadcast Receiver -->
<receiver android:name=".SmsReceiver" ... />
```

## Python Backend Setup

### Quick Start with Flask

Create a `phishing_detector_backend.py`:

```python
from flask import Flask, request, jsonify
from sklearn.ensemble import RandomForestClassifier
import numpy as np
import re

app = Flask(__name__)

# Load or train your phishing detection model
# model = load_trained_model()

class PhishingDetector:
    def __init__(self):
        # Initialize your ML model here
        pass
    
    def analyze_text(self, text):
        """Analyze text for phishing indicators"""
        risk_score = 0.0
        patterns = []
        
        # Example phishing indicators
        phishing_keywords = {
            'verify|confirm|urgent|action required': 0.3,
            'click here|update now|verify account': 0.4,
            'banking|payment|credit card': 0.2,
            'suspicious activity|unusual login': 0.25,
        }
        
        for pattern, score in phishing_keywords.items():
            if re.search(pattern, text, re.IGNORECASE):
                risk_score += score
                patterns.append(pattern)
        
        # Use ML model for deeper analysis
        # risk_score = model.predict([text])[0]
        
        risk_score = min(1.0, risk_score)  # Cap at 1.0
        
        if risk_score > 0.7:
            classification = 'phishing'
        elif risk_score > 0.4:
            classification = 'suspicious'
        else:
            classification = 'safe'
        
        return {
            'risk_score': risk_score,
            'classification': classification,
            'detected_patterns': patterns
        }

detector = PhishingDetector()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

@app.route('/analyze/sms', methods=['POST'])
def analyze_sms():
    """Analyze SMS message"""
    data = request.json
    message = data.get('message', '')
    sender = data.get('sender', '')
    
    analysis = detector.analyze_text(message)
    
    return jsonify({
        'message_id': data.get('timestamp', ''),
        'risk_score': analysis['risk_score'],
        'classification': analysis['classification'],
        'details': {
            'message_length': len(message),
            'has_urls': 'http' in message,
            'sender': sender
        },
        'detected_patterns': analysis['detected_patterns']
    })

@app.route('/analyze/whatsapp', methods=['POST'])
def analyze_whatsapp():
    """Analyze WhatsApp message"""
    data = request.json
    message = data.get('message', '')
    
    analysis = detector.analyze_text(message)
    
    return jsonify({
        'message_id': data.get('timestamp', ''),
        'risk_score': analysis['risk_score'],
        'classification': analysis['classification'],
        'details': {
            'app': 'whatsapp',
            'message_length': len(message),
        },
        'detected_patterns': analysis['detected_patterns']
    })

@app.route('/analyze/batch', methods=['POST'])
def batch_analyze():
    """Batch analyze multiple messages"""
    data = request.json
    messages = data.get('messages', [])
    
    results = []
    for msg in messages:
        analysis = detector.analyze_text(msg.get('message', ''))
        results.append({
            'message_id': msg.get('id', ''),
            'risk_score': analysis['risk_score'],
            'classification': analysis['classification'],
            'detected_patterns': analysis['detected_patterns']
        })
    
    return jsonify({'results': results})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

### Production Deployment

**Using Docker:**
```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "phishing_detector_backend:app"]
```

**requirements.txt:**
```
Flask==2.3.0
scikit-learn==1.2.0
numpy==1.24.0
gunicorn==20.1.0
requests==2.31.0
```

## Configuration

### 1. Update Backend URL in Flutter
Edit [ai_backend_service.dart](lib/src/services/ai_backend_service.dart):
```dart
static const String baseUrl = 'http://your-python-backend-url:5000';
```

### 2. Required Permissions (Already Added)
- `READ_SMS` - Read SMS messages
- `RECEIVE_SMS` - Listen for new SMS
- `BIND_NOTIFICATION_LISTENER_SERVICE` - Monitor notifications
- `INTERNET` - Communication with backend
- `POST_NOTIFICATIONS` - Show alerts

### 3. Background Service Setup
```dart
// In your app settings page or initialization:
await BackgroundListenerService.start();
```

## Usage Examples

### Reading SMS with Read/Unread Status
```dart
final messages = await PlatformService.getSmsMessagesWithReadStatus();

for (var msg in messages) {
  print('From: ${msg['address']}');
  print('Read: ${msg['isRead']}');
  print('Content: ${msg['body']}');
}
```

### Analyzing Messages with AI
```dart
import 'package:my_app/src/services/ai_backend_service.dart';

final result = await AiBackendService.analyzeSms(
  sender: '+1234567890',
  message: 'Click here to verify your account...',
);

if (result != null) {
  print('Risk Score: ${result.getRiskPercentage()}%');
  print('Status: ${result.classification}');
  
  if (result.isPhishing()) {
    // Show warning to user
  }
}
```

### Managing Background Service
```dart
import 'package:my_app/src/services/background_listener_service.dart';

// Start monitoring
await BackgroundListenerService.start();

// Check if running
final isRunning = await BackgroundListenerService.isRunning();

// Stop monitoring
await BackgroundListenerService.stop();
```

## Security Considerations

1. **Data Privacy**
   - Never store raw message content on device
   - Use HTTPS for backend communication
   - Implement authentication tokens

2. **Backend Security**
   - Use API key/token authentication
   - Rate limit API endpoints
   - Validate input on backend
   - Use HTTPS only

3. **On-Device Processing**
   - Keep local pattern database updated
   - Clean up old messages regularly

## Performance Optimization

1. **Batch Processing**
```dart
final results = await AiBackendService.batchAnalyze(messages);
```

2. **Caching**
- Cache analysis results
- Avoid re-analyzing same messages

3. **Network Efficiency**
- Use connection pooling
- Implement retry logic
- Compress data if needed

## Troubleshooting

### Background Service Not Working
1. Check permissions in Settings > Apps > Permissions
2. Ensure SMS permission is granted
3. Check if app is in battery saver mode
4. Review logs: `adb logcat | grep SmsListenerService`

### AI Backend Not Responding
1. Check backend is running: `curl http://your-backend:5000/health`
2. Verify network connectivity from device
3. Check backend firewall rules
4. Review application logs

### Messages Not Being Detected
1. Verify READ_SMS permission
2. Check if SMS Receiver priority is set to 999
3. Ensure SmsListenerService started
4. Review Android logs for errors

## Future Enhancements

1. **Advanced ML Models**
   - Train on labeled phishing dataset
   - Use deep learning (LSTM, BERT)
   - Implement federated learning

2. **Real-time Alerting**
   - Push notifications for phishing
   - SMS/Call spoofing detection
   - Blockchain verification

3. **User Feedback Loop**
   - Allow users to report false positives/negatives
   - Improve model with feedback
   - Community threat intelligence

4. **Multi-language Support**
   - Detect phishing in multiple languages
   - Localized pattern detection

## API Reference

### Flutter Methods

#### `getSmsMessagesWithReadStatus()`
Returns list of SMS messages with read/unread status.

**Returns:**
```dart
List<Map<String, dynamic>> [
  {
    'id': 'sms_1',
    'address': '+1234567890',
    'body': 'Message content',
    'date': 1234567890000,
    'isRead': true,
    'type': 1,
    'source': 'sms'
  }
]
```

#### `startBackgroundService()`
Starts the SMS listener service.

**Returns:** `bool - true if successful`

#### `isBackgroundServiceRunning()`
Checks if background service is running.

**Returns:** `bool - true if running`

### Python Backend Endpoints

#### `GET /health`
Check backend availability.

**Response:**
```json
{"status": "healthy"}
```

#### `POST /analyze/sms`
Analyze SMS message.

**Request:**
```json
{
  "sender": "+1234567890",
  "message": "Message content",
  "phone_number": "+9876543210",
  "timestamp": "2024-02-13T10:30:00Z"
}
```

**Response:**
```json
{
  "message_id": "2024-02-13T10:30:00Z",
  "risk_score": 0.85,
  "classification": "phishing",
  "details": {
    "message_length": 120,
    "has_urls": true,
    "sender": "+1234567890"
  },
  "detected_patterns": ["urgent", "verify account"]
}
```

#### `POST /analyze/batch`
Analyze multiple messages.

**Request:**
```json
{
  "messages": [
    {
      "id": "msg_1",
      "message": "Content 1"
    },
    {
      "id": "msg_2",
      "message": "Content 2"
    }
  ],
  "timestamp": "2024-02-13T10:30:00Z"
}
```

**Response:**
```json
{
  "results": [
    {
      "message_id": "msg_1",
      "risk_score": 0.75,
      "classification": "suspicious"
    }
  ]
}
```

## Support & Documentation

- Flutter Documentation: https://flutter.dev/docs
- Android SMS API: https://developer.android.com/guide/topics/providers/sms-mms
- Flask Documentation: https://flask.palletsprojects.com
- scikit-learn: https://scikit-learn.org

---

**Last Updated:** February 13, 2026
**Version:** 1.0.0
