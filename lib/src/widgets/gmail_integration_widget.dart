import 'package:flutter/material.dart';
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/gmail_service.dart';

class GmailIntegrationWidget extends StatefulWidget {
  const GmailIntegrationWidget({Key? key}) : super(key: key);

  @override
  State<GmailIntegrationWidget> createState() => _GmailIntegrationWidgetState();
}

class _GmailIntegrationWidgetState extends State<GmailIntegrationWidget> {
  bool _isSignedIn = false;
  bool _isLoading = false;
  List<Email> _emails = [];
  String _statusMessage = 'Not signed in';

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    final user = await GmailAuthService.silentSignIn();
    setState(() {
      _isSignedIn = user != null;
      _statusMessage = user != null ? 'Signed in as: ${user.email}' : 'Not signed in';
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Signing in...';
    });

    try {
      final user = await GmailAuthService.signIn();
      if (user != null) {
        setState(() {
          _isSignedIn = true;
          _statusMessage = 'Signed in as: ${user.email}';
        });
        
        // Fetch emails after signing in
        await _fetchEmails();
      } else {
        setState(() {
          _statusMessage = 'Sign in cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Sign in failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEmails() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching emails...';
    });

    try {
      final emails = await GmailService.fetchEmails(maxResults: 20);
      setState(() {
        _emails = emails;
        _statusMessage = 'Fetched ${emails.length} emails';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching emails: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await GmailAuthService.signOut();
    setState(() {
      _isSignedIn = false;
      _emails = [];
      _statusMessage = 'Signed out';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Gmail Integration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Status Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(height: 16),

            // Sign In / Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_isSignedIn ? _handleGoogleSignOut : _handleGoogleSignIn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSignedIn ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isSignedIn ? 'Sign Out' : 'Sign In with Google',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Fetch Emails Button
            if (_isSignedIn)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _fetchEmails,
                  child: const Text('Refresh Emails'),
                ),
              ),
            const SizedBox(height: 24),

            // Emails List
            if (_emails.isNotEmpty)
              Text(
                'Recent Emails (${_emails.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 8),
            ..._emails.map((email) => EmailCard(email: email)).toList(),
          ],
        ),
      ),
    );
  }
}

class EmailCard extends StatelessWidget {
  final Email email;

  const EmailCard({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From
            Row(
              children: [
                const Text('From: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    email.from,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Subject
            Row(
              children: [
                const Text('Subject: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    email.subject,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Snippet
            Text(
              email.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Date and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  email.date.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await GmailService.markAsRead(email.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as read')),
                        );
                      },
                      icon: const Icon(Icons.done, size: 16),
                      label: const Text('Read'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await GmailService.markAsSpam(email.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as spam')),
                        );
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Spam'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
