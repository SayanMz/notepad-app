/// Normalized date/time selection used by search filters.
class SearchDateSelection {
  const SearchDateSelection({
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
  });

  final int? year;
  final int? month;
  final int? day;
  final int? hour;
  final int? minute;

  bool get hasValues =>
      year != null ||
      month != null ||
      day != null ||
      hour != null ||
      minute != null;

  SearchDateSelection copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
  }) {
    return SearchDateSelection(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}
