// Formats DateTime values into a compact readable date-time string.
extension NoteDateFormatter on DateTime {
  String format({
    bool showDate = true,
    bool showYear = true,
    bool showTime = true,
  }) {
    final month = _monthName(this.month);
    final dateStr = '$month $day${showYear ? ', $year' : ''}';

    if (!showTime) return dateStr;

    final hour = this.hour == 0
        ? 12
        : (this.hour > 12 ? this.hour - 12 : this.hour);
    final minute = this.minute.toString().padLeft(2, '0');
    final meridiem = this.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $meridiem';

    if (!showDate) return timeStr;

    return '$dateStr • $timeStr';
  }

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
