import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/models/search_date_selection.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';

void main() {
  test('SearchDateSelection copyWith preserves existing values', () {
    const selection = SearchDateSelection(
      year: 2025,
      month: 7,
      day: 16,
      hour: 9,
      minute: 30,
    );

    final updated = selection.copyWith(hour: 10);

    expect(updated.year, 2025);
    expect(updated.month, 7);
    expect(updated.day, 16);
    expect(updated.hour, 10);
    expect(updated.minute, 30);
    expect(updated.hasValues, isTrue);
  });

  test('SearchFilters reports active boundaries as filter state', () {
    const filters = SearchFilters(
      start: SearchDateSelection(year: 2025),
      end: SearchDateSelection(),
    );

    expect(filters.hasFilters, isTrue);
    expect(filters.copyWith(isRangeSearch: true).isRangeSearch, isTrue);
  });

  test('SearchState normalizes queries and detects any criteria', () {
    const state = SearchState(
      query: '  Notepad Search  ',
      filters: SearchFilters(start: SearchDateSelection(year: 2025)),
    );

    expect(state.normalizedQuery, 'notepad search');
    expect(state.hasQuery, isTrue);
    expect(state.hasFilters, isTrue);
    expect(state.hasAnyCriteria, isTrue);

    final cleared = state.copyWith(query: '');
    expect(cleared.query, '');
    expect(cleared.filters.hasFilters, isTrue);
  });
}
