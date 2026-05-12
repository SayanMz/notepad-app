extension NoteDateFormatter on DateTime {
  /// Formats the timestamp into a readable string with granular control.
  /// Usage: note.updatedAt.format() -> "May 12, 2026 • 8:45 AM"
  String format({
    bool showDate = true,
    bool showYear = true,
    bool showTime = true,
  }) {
    final month = _monthName(this.month);

    // Construct the Date portion
    final dateStr = '$month $day${showYear ? ', $year' : ''}';

    if (!showTime) return dateStr;

    // Construct the Time portion
    final hour = this.hour == 0
        ? 12
        : (this.hour > 12 ? this.hour - 12 : this.hour);
    final minute = this.minute.toString().padLeft(2, '0');
    final meridiem = this.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $meridiem';

    if (!showDate) return timeStr;

    // Combine both with the bullet separator
    return '$dateStr • $timeStr';
  }

  // Private helper for month names
  String _monthName(int month) {
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
    return months[month - 1];
  }
}
