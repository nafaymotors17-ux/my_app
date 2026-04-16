/// Utility functions for formatting and date handling
class DateTimeUtils {
  /// Format DateTime to readable string
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Compact date for list rows (e.g., "18 Mar" or "18 Mar 2026")
  static String formatCompactDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final now = DateTime.now();
    final month = months[(date.month - 1).clamp(0, 11)];
    if (date.year == now.year) {
      return '${date.day} $month';
    }
    return '${date.day} $month ${date.year}';
  }

  /// More detailed date for message detail views.
  static String formatDetailDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[(date.weekday - 1).clamp(0, 6)];
    final month = months[(date.month - 1).clamp(0, 11)];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$weekday, ${date.day} $month ${date.year} • $hh:$mm';
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return formatDate(date);
    }
  }
}
