import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/filter/controllers/search_controller.dart';
import 'package:notepad/features/filter/models/search_date_selection.dart';
import 'package:notepad/features/filter/models/search_filters.dart';

void main() {
  test('SearchController exposes empty state by default', () {
    final controller = SearchController();

    expect(controller.query, '');
    expect(controller.hasAnyCriteria, isFalse);
    expect(controller.hasFilters, isFalse);

    controller.dispose();
  });

  test('clearQuery removes text and clearFilter resets the filter model', () {
    final controller = SearchController();
    controller.textController.text = 'draft';

    controller.clearQuery();
    controller.applyFilters(
      const SearchFilters(
        isRangeSearch: true,
        start: SearchDateSelection(year: 2026),
        end: SearchDateSelection(year: 2026, month: 7),
      ),
    );
    controller.clearFilter();

    expect(controller.textController.text, '');
    expect(controller.filters.hasFilters, isFalse);
    expect(controller.hasAnyCriteria, isFalse);

    controller.dispose();
  });
}

