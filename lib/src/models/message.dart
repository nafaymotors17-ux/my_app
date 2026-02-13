class Message {
  final String id;
  final String address;
  final String body;
  final DateTime date;
  final String source; // 'sms' or 'whatsapp'
  final bool isRead; // read/unread status (SMS only)

  Message({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.source,
    this.isRead = false,
  });
}
