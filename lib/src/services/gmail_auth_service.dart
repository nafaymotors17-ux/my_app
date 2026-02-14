import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

class GmailAuthService {
  /// Web Client ID from Google Cloud Console (OAuth 2.0 Client ID, type: Web application).
  /// ⚠️ MUST be the Web client, NOT the Android client. Required for Gmail API token exchange.
  /// Create at: Credentials → Create Credentials → OAuth 2.0 Client ID → Web application
  static const String? serverClientId = '860732880625-n4hhcerh7f4v6o361jue7moms8ejo5j7.apps.googleusercontent.com';

  static GoogleSignIn? _googleSignInInstance;
  static GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/gmail.modify',
      ],
      serverClientId: serverClientId,
    );
    return _googleSignInInstance!;
  }

  static GoogleSignInAccount? _currentUser;

  /// Sign in to Google. Shows account picker if needed.
  /// Do not sign out first – that slows the picker and can break completion on Android.
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      // Disconnect first to clear any stale tokens (fixes 7-day testing-mode expiry)
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // Ignore – might not be connected
      }
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        // Validate that we can actually get a token right away
        final auth = await _currentUser!.authentication;
        if (auth.accessToken == null) {
          print('⚠ Sign-in succeeded but accessToken is null');
          _currentUser = null;
        }
      }
      return _currentUser;
    } catch (e) {
      print('Error signing in: $e');
      _currentUser = null;
      rethrow;
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

  /// Fully disconnect (revoke tokens). Useful when tokens are stale.
  static Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    _currentUser = null;
  }

  /// Get current signed in user
  static GoogleSignInAccount? getCurrentUser() {
    return _currentUser;
  }

  /// Check if user is already signed in (uses cached credentials).
  /// Also validates the token is still usable.
  static Future<GoogleSignInAccount?> silentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        // Validate token is still valid — this is the key check.
        // silentSignIn can return a cached user even when the refresh token
        // has expired (e.g. Google Cloud project in "Testing" mode = 7-day expiry).
        try {
          final auth = await _currentUser!.authentication;
          if (auth.accessToken == null) {
            print('⚠ Silent sign-in: user cached but accessToken null — clearing');
            _currentUser = null;
          }
        } catch (e) {
          print('⚠ Silent sign-in: token validation failed ($e) — clearing user');
          _currentUser = null;
          // Also sign out so stale cache doesn't persist
          try {
            await _googleSignIn.signOut();
          } catch (_) {}
        }
      }
      return _currentUser;
    } catch (e) {
      print('Error in silent sign in: $e');
      _currentUser = null;
      return null;
    }
  }

  /// Get Gmail service with authentication.
  /// If the token is expired, attempts re-auth once before giving up.
  static Future<gmail.GmailApi?> getGmailService() async {
    // 1. Make sure we have a user
    if (_currentUser == null) {
      _currentUser = await silentSignIn();
      if (_currentUser == null) {
        return null;
      }
    }

    // 2. Try to get a valid token
    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken == null) throw Exception('accessToken is null');
      final client = GmailClient(http.Client(), auth.accessToken!);
      return gmail.GmailApi(client);
    } catch (e) {
      print('⚠ Token fetch failed ($e) — attempting re-auth...');

      // 3. Token is dead — clear user and try silent sign-in once more
      _currentUser = null;
      try {
        await _googleSignIn.signOut(); // clear stale cache
        _currentUser = await _googleSignIn.signInSilently();
        if (_currentUser != null) {
          final auth = await _currentUser!.authentication;
          if (auth.accessToken != null) {
            final client = GmailClient(http.Client(), auth.accessToken!);
            return gmail.GmailApi(client);
          }
        }
      } catch (retryError) {
        print('⚠ Re-auth also failed: $retryError');
      }

      // 4. Nothing worked — user needs to sign in again interactively
      _currentUser = null;
      return null;
    }
  }

  /// Whether we currently have a valid-looking user. Does NOT hit the network.
  static bool get hasUser => _currentUser != null;

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
