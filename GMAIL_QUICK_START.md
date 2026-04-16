# Gmail Integration - Quick Start

## What's Been Added

You now have complete Gmail OAuth integration with the ability to:
- ✅ Sign in with Google account
- ✅ Read full email content (body, subject, sender)
- ✅ Fetch unread emails
- ✅ Search emails
- ✅ Mark emails as read
- ✅ Mark emails as spam
- ✅ Cache emails locally

## Services Added

### 1. **GmailAuthService** (`lib/src/services/gmail_auth_service.dart`)
Handles all authentication with Google
```dart
// Sign in
final user = await GmailAuthService.signIn();

// Sign out
await GmailAuthService.signOut();

// Get current user
final user = GmailAuthService.getCurrentUser();
```

### 2. **GmailService** (`lib/src/services/gmail_service.dart`)
Handles all email operations
```dart
// Fetch unread emails
final emails = await GmailService.fetchEmails(maxResults: 20);

// Fetch all emails (paginated)
final allEmails = await GmailService.fetchAllEmails(pageSize: 20);

// Get single email
final email = await GmailService.getEmailById('emailId');

// Search emails
final results = await GmailService.searchEmails('from:phishing');

// Mark as read
await GmailService.markAsRead(emailId);

// Mark as spam
await GmailService.markAsSpam(emailId);
```

### 3. **GmailIntegrationWidget** (`lib/src/widgets/gmail_integration_widget.dart`)
Pre-built UI component for Gmail integration

## Email Object Structure

```dart
class Email {
  final String id;           // Gmail message ID
  final String subject;      // Email subject
  final String from;         // Sender email/name
  final String snippet;      // Preview text
  final String body;         // Full email body
  final DateTime date;       // Received date
  final bool isPhishing;     // Phishing flag (for ML integration)
}
```

## Setup Steps

1. **Add Dependencies** ✅ (Already done)
   - `google_sign_in`
   - `googleapis`
   - `http`

2. **Create Google Cloud Project** 
   - Follow `GMAIL_OAUTH_SETUP.md`

3. **Enable Gmail API**
   - Follow `GMAIL_OAUTH_SETUP.md`

4. **Create OAuth Credentials**
   - Follow `GMAIL_OAUTH_SETUP.md`
   - Get SHA-1 fingerprint from `./gradlew signingReport`
   - Register in Cloud Console

5. **Test the Integration**
   - Use `GmailIntegrationWidget` in your UI
   - Or call services directly

## Using in Your App

### Option 1: Use Pre-built Widget
```dart
import 'package:my_app/src/widgets/gmail_integration_widget.dart';

// In your page
body: const GmailIntegrationWidget(),
```

### Option 2: Custom Integration
```dart
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/gmail_service.dart';

// Sign in
final user = await GmailAuthService.signIn();

// Fetch emails
final emails = await GmailService.fetchEmails();

// Process emails
for (var email in emails) {
  print('From: ${email.from}');
  print('Subject: ${email.subject}');
  print('Body: ${email.body}');
  
  // Run your phishing detection
  // ...
}
```

## Important Permissions

Already added to `AndroidManifest.xml`:
- `android.permission.INTERNET` - Required for API calls

## Gmail API Scopes

The app uses these Gmail API scopes:
- `gmail.readonly` - Read emails
- `gmail.modify` - Mark as read, trash emails

## Local Caching

Emails are automatically cached in SharedPreferences:
- **StorageKey**: `gmail_emails`
- **LastSyncKey**: `gmail_last_sync`

Load cached emails if network fails:
```dart
// Automatically handled internally
// But you can also:
final cachedEmails = await GmailService._loadEmails();
final lastSync = await GmailService.getLastSync();
```

## Search Examples

```dart
// Unread emails
final unread = await GmailService.searchEmails('is:unread');

// From specific sender
final fromPhisher = await GmailService.searchEmails('from:suspicious@example.com');

// With specific words
final phishing = await GmailService.searchEmails('verify account password reset');

// Emails with attachments
final withAttachments = await GmailService.searchEmails('has:attachment');

// Within date range
final recent = await GmailService.searchEmails('after:2024/01/01');
```

## For Phishing Detection

You can now:

1. **Get email body** - Full content for ML analysis
```dart
final email = await GmailService.getEmailById(emailId);
String emailContent = email.body; // Complete email body
```

2. **Extract features** from email:
   - Sender domain
   - Subject keywords
   - Body content
   - Links in email
   - Attachment presence

3. **Flag suspicious emails**:
```dart
// Mark as spam
await GmailService.markAsSpam(emailId);

// Or mark as read
await GmailService.markAsRead(emailId);
```

4. **Background monitoring** - Combine with your SMS/WhatsApp listener to monitor all communication

## Troubleshooting

### Issue: Sign-in button doesn't work
- Check SHA-1 fingerprint is correct
- Verify package name is `com.example.my_app`
- Run `flutter clean && flutter pub get`

### Issue: No emails fetching
- Check internet connection
- Verify Gmail scopes are enabled
- Check Cloud Console credentials

### Issue: "Permission Denied"
- User needs to grant permissions in sign-in dialog
- Check account has Gmail enabled

### Issue: Body is empty
- Some emails may be HTML/rich text format
- The service handles both - check snippet if body is empty

## Next: Integrate ML Phishing Detection

Once emails are fetched:
```dart
final emails = await GmailService.fetchEmails();

for (var email in emails) {
  // Send to your ML model
  final isPhishing = await YourPhishingModel.predict(
    subject: email.subject,
    body: email.body,
    sender: email.from,
  );
  
  if (isPhishing) {
    // Mark as spam
    await GmailService.markAsSpam(email.id);
  }
}
```

## Done! 🎉

You now have:
- ✅ SMS reading (existing)
- ✅ WhatsApp monitoring (existing)
- ✅ Email reading with OAuth (new)
- ✅ All with phishing detection framework

Combine these for comprehensive communication monitoring!
