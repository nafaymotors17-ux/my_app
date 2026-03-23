# Gmail OAuth Setup Guide

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown and select "NEW PROJECT"
3. Enter project name: `Phishing Detector`
4. Click CREATE

## Step 2: Enable Gmail API

1. In the Cloud Console, search for "Gmail API"
2. Click on "Gmail API"
3. Click the ENABLE button
4. Wait for the API to be enabled

## Step 3: Create OAuth 2.0 Credentials

### For Android:

1. Go to "Credentials" in the left menu
2. Click CREATE CREDENTIALS > OAuth 2.0 Client ID
3. If prompted, click "Configure Consent Screen" first:
   - Select "External" for User Type
   - Fill in the required fields:
     - App name: `Phishing Detector`
     - User support email: (your email)
     - Developer contact info: (your email)
   - Scopes: Add these scopes:
     - `https://www.googleapis.com/auth/gmail.readonly`
     - `https://www.googleapis.com/auth/gmail.modify`
   - **Test users** (if app is in Testing): Add your Gmail address under "Test users" – only these accounts can sign in while in Testing mode
   - Save and Continue, then go back to credentials

4. Now create OAuth 2.0 Client ID:
   - Application type: "Android"
   - Name: `Android Client`
5. You'll need your app's SHA-1 fingerprint:
   ```bash
   # Run this command from your project directory:
   cd android
   ./gradlew signingReport  # On Windows: gradlew.bat signingReport
   ```
6. Copy the SHA-1 from `Variant: debug` output
7. Paste it into the Cloud Console's "SHA-1 certificate fingerprint" field
8. Enter Package name: `com.example.my_app`
9. Click CREATE

## Step 4: Create Web OAuth Client (REQUIRED for Gmail API)

**⚠️ This step is required.** The Android client alone is not enough for Gmail API.

1. Go to Credentials again
2. Click CREATE CREDENTIALS > OAuth 2.0 Client ID
3. Application type: **Web application**
4. Name: `Web Client (for Gmail API)`
5. Authorized redirect URIs: `http://localhost` or `http://localhost:8080/`
6. Click CREATE
7. **Copy the Client ID** – this goes into `gmail_auth_service.dart` as `serverClientId`
8. Update `lib/src/services/gmail_auth_service.dart` and replace the `serverClientId` value with your Web client ID

## Step 5: Update Flutter Project

The necessary dependencies have been added to `pubspec.yaml`:

- `google_sign_in: ^6.2.1`
- `googleapis: ^11.4.0`
- `http: ^1.1.0`

Run: `flutter pub get`

## Step 6: Configure Google Sign-In for Flutter

### For Android:

No additional configuration needed! The `google_sign_in` package automatically handles Android setup.

### For iOS (if needed):

1. Edit `ios/Runner/Info.plist`:

```xml
<key>GIDClientID</key>
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## Usage Example

```dart
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/gmail_service.dart';

// Sign in to Google
final user = await GmailAuthService.signIn();
if (user != null) {
  print('Signed in as: ${user.email}');

  // Fetch unread emails
  final emails = await GmailService.fetchEmails(maxResults: 20);
  for (var email in emails) {
    print('From: ${email.from}');
    print('Subject: ${email.subject}');
    print('Body: ${email.body}');
  }

  // Search for specific emails
  final phishingEmails = await GmailService.searchEmails('phishing');

  // Mark email as read
  await GmailService.markAsRead(emails[0].id);

  // Mark email as spam
  await GmailService.markAsSpam(emails[0].id);
}

// Sign out
await GmailAuthService.signOut();
```

## Scopes Explained

- `gmail.readonly`: Read emails only (what we're using)
- `gmail.modify`: Can read, mark as read, and trash emails
- `gmail.send`: Can send emails
- `gmail.labels`: Can manage labels

## Testing

1. Build and run the app: `flutter run`
2. The first time, you'll see a Google Sign-In dialog
3. Select your Google account
4. Grant permissions when prompted
5. The app will fetch your Gmail emails

## Troubleshooting

### ⚠️ CRITICAL: You need TWO OAuth clients

1. **Android OAuth client** (Application type: Android)
   - Uses SHA-1 + package name `com.example.my_app`
   - Used for the sign-in flow on your device
2. **Web OAuth client** (Application type: Web application)
   - Used as `serverClientId` in your code
   - **Without the Web client, Gmail API will NOT work** – you’ll sign in but can’t read emails

**Steps:**
- Credentials → Create Credentials → OAuth 2.0 Client ID
- Create an Android client (SHA-1, package name)
- Create a **Web** client (leave Authorized redirect URIs empty or add `http://localhost`)
- Copy the **Web** client’s Client ID into `gmail_auth_service.dart` → `serverClientId`

### "Sign-in failed" or "Sign-in cancelled" immediately:

1. **Testing mode – add your account as test user**
   - OAuth consent screen → Test users → Add users
   - Add the exact Gmail address you’re signing in with
   - In Testing, only listed users can sign in

2. **SHA-1**
   - Use the SHA-1 from the **debug** keystore when running `flutter run`
   - Run: `cd android && .\gradlew signingReport` (Windows) or `./gradlew signingReport`
   - Copy SHA-1 from `Variant: debug`
   - Credentials → your Android OAuth client → ensure this SHA-1 is correct

3. **Package name**
   - Must be exactly `com.example.my_app` (as in `build.gradle.kts`)

### "Permission denied" or sign-in works but no emails:

1. **Consent screen scopes**
   - OAuth consent screen → Edit app → Scopes → Add:
     - `https://www.googleapis.com/auth/gmail.readonly`
     - `https://www.googleapis.com/auth/gmail.modify`
   - Save

2. **Gmail API**
   - APIs & Services → Enable APIs → search “Gmail API” → Enable

3. **Web client ID (`serverClientId`)**
   - Must be the **Web** client ID, not the Android client ID
   - If you only have an Android client, create a Web client and use its Client ID

### No emails fetching (sign-in succeeds):

- Gmail API must be enabled in your project
- `serverClientId` must be the Web client ID
- Run `flutter logs` or Android logcat to see error messages

## Security Notes

⚠️ **Important:**

- Never commit Google Cloud credentials to version control
- Use environment variables for sensitive data in production
- The access token is automatically refreshed by `google_sign_in`
- User can revoke access at any time in Google Account settings

## Next Steps

After implementation, you can:

1. Display emails in a ListView
2. Integrate with your phishing detection ML model
3. Auto-analyze email content for phishing markers
4. Store flagged emails for user review
