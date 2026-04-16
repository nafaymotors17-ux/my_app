import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

class GmailAuthService {
  // ⚠️ IMPORTANT: Replace this with your WEB OAuth Client ID from Google Cloud Console
  // Steps to get it:
  // 1. Go to https://console.cloud.google.com/apis/credentials
  // 2. Create OAuth 2.0 Client ID → Choose "Web application" type
  // 3. Copy the Client ID (format: xxx-xxx.apps.googleusercontent.com)
  static const String _serverClientId = '84331485062-10p0smuhubp71s78i96dbdqvuo8qlh0p.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _serverClientId,
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  static GoogleSignInAccount? _currentUser;

  /// Sign in to Google
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Get current signed in user
  static GoogleSignInAccount? getCurrentUser() {
    return _currentUser;
  }

  /// Check if user is already signed in
  static Future<GoogleSignInAccount?> silentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (e) {
      print('Error in silent sign in: $e');
      return null;
    }
  }

  /// Get Gmail service with authentication
  static Future<gmail.GmailApi?> getGmailService() async {
    if (_currentUser == null) {
      _currentUser = await silentSignIn();
      if (_currentUser == null) {
        return null;
      }
    }

    try {
      final auth = await _currentUser!.authentication;
      final client = GmailClient(http.Client(), auth.accessToken!);
      return gmail.GmailApi(client);
    } catch (e) {
      print('Error getting Gmail service: $e');
      return null;
    }
  }

  /// Get user email
  static String? getUserEmail() {
    return _currentUser?.email;
  }

  /// Get user name
  static String? getUserName() {
    return _currentUser?.displayName;
  }
}

/// Custom HTTP client for Gmail API with bearer token
class GmailClient extends http.BaseClient {
  final http.Client _inner;
  final String _token;

  GmailClient(this._inner, this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
