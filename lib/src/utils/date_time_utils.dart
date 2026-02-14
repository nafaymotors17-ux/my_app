/// Utility functions for formatting and date handling
class DateTimeUtils {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _fullMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Short format for lists:  "14 Feb" (same year) or "14 Feb 2025" (diff year),
  /// "2:30 PM" (today), "Yesterday"
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return _formatTime(date);
    }
    if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    if (date.year == now.year) {
      return '${date.day} ${_months[date.month - 1]}';
    }
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// Detailed format for email detail view: "Feb 14, 2026, 2:30 PM"
  static String formatDetailDate(DateTime date) {
    return '${_fullMonths[date.month - 1]} ${date.day}, ${date.year}, ${_formatTime(date)}';
  }

  /// Compact relative date + time: "Today, 2:30 PM" / "Yesterday, 2:30 PM" / "Feb 14, 2:30 PM"
  static String formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final time = _formatTime(date);

    if (dateDay == today) return time;
    if (dateDay == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
    if (date.year == now.year) return '${_months[date.month - 1]} ${date.day}, $time';
    return '${_months[date.month - 1]} ${date.day}, ${date.year}, $time';
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatDate(date);
    }
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
