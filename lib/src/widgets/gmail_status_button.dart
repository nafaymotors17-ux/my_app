import 'package:flutter/material.dart';

class GmailStatusButton extends StatelessWidget {
  final bool isSignedIn;
  final String? userEmail;
  final VoidCallback onTap;

  const GmailStatusButton({
    super.key,
    required this.isSignedIn,
    this.userEmail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      // Not signed in — show a simple "Sign In" chip
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Tooltip(
          message: 'Sign in to Gmail',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Signed in — show email + tap to open sign-out dialog
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: 'Tap to manage Gmail account',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail, color: Colors.red[700], size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    userEmail ?? 'Gmail',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, color: Colors.red[400], size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
