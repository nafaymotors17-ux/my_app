class Message {
  final String id;
  final String address;
  final String body;
  final DateTime date;
  final String source; // 'sms' or 'gmail'
  final bool isRead;
  final String? subject; // Gmail subject
  final String? gmailTo; // Recipient for sent emails
  final String? gmailLabel; // INBOX, SENT, SPAM, etc.

  Message({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.source,
    this.isRead = false,
    this.subject,
    this.gmailTo,
    this.gmailLabel,
  });
}
