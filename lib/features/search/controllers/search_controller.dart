import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/note_search_service.dart';

/// ---------------------------------------------------------------------------
/// SEARCH CONTROLLER (INTERVIEW NOTE)
/// ---------------------------------------------------------------------------
///
/// Role:
/// Acts as the controller layer for the search feature, sitting between
/// the UI and data layer.
///
/// Responsibilities:
/// - Owns search state (query + filters)
/// - Handles debounced user input
/// - Executes search via repository
/// - Caches results for efficient UI rendering
/// - Notifies UI reactively via ChangeNotifier
///
/// Why this design:
/// Centralizes all search logic outside the UI to keep widgets declarative,
/// predictable, and easier to maintain/test.
///
/// Architectural Placement:
/// UI → Controller → Repository → Storage
///
/// Key Decisions:
/// - Uses immutable SearchState to avoid inconsistent state mutations
/// - Debounce implemented to prevent excessive search calls
/// - TextEditingController owned here to maintain single source of truth
///
/// Trade-offs:
/// - Uses ChangeNotifier for simplicity instead of heavier solutions
///   (e.g., Bloc/Riverpod)
/// - Suitable for mid-scale apps; can evolve to more structured state
///   management if complexity grows
class SearchController extends ChangeNotifier {
  /// Repository used to perform search operations

  /// Text controller owned by controller (single source for query input)
  final TextEditingController textController = TextEditingController();

  /// Internal search state (query + filters)
  SearchState _state = const SearchState(query: '', filters: SearchFilters());

  /// Cached search results
  List<NotesSection> _results = const [];

  /// Debounce timer for query input
  Timer? _debounce;

  /// -------------------------------------------------------------------------
  /// PUBLIC GETTERS (EXPOSED TO UI)
  /// -------------------------------------------------------------------------

  /// Current search results
  List<NotesSection> get results => _results;

  /// Current query string
  String get query => _state.query;

  /// Current filter configuration
  SearchFilters get filters => _state.filters;

  /// Indicates if filters are active
  bool get hasFilters => _state.hasFilters;

  /// Indicates if any search criteria exist (query or filters)
  bool get hasAnyCriteria => _state.hasAnyCriteria;

  /// -------------------------------------------------------------------------
  /// QUERY HANDLING
  /// -------------------------------------------------------------------------

  /// Handles query changes from UI input
  ///
  /// Behavior:
  /// - Cancels previous debounce
  /// - Waits for debounce duration
  /// - Updates state and triggers search
  void onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(UIConstants.debounceStandard, () {
      _state = _state.copyWith(query: value.trim());
      _recompute();
    });
  }

  /// Clears query input and resets search
  ///
  /// Behavior:
  /// - Cancels debounce
  /// - Clears text controller
  /// - Resets query in state
  /// - Triggers search update
  void clearQuery() {
    _debounce?.cancel();
    textController.clear();
    _state = _state.copyWith(query: '');
    _recompute();
  }

  /// Atomic State management
  /// Completely resets the search query and all filters,
  /// then triggers a single UI and database update.
  void clearFilter() {
    _state = _state.copyWith(filters: const SearchFilters());
    _recompute();
  }

  /// -------------------------------------------------------------------------
  /// FILTER HANDLING
  /// -------------------------------------------------------------------------

  /// Applies new filter configuration
  ///
  /// Behavior:
  /// - Updates state with new filters
  /// - Immediately recomputes search results
  void applyFilters(SearchFilters newfilters) {
    // copyWith preserves the existing _state.query, allowing Query + Filter!
    _state = _state.copyWith(filters: newfilters);
    _recompute();
  }

  /// -------------------------------------------------------------------------
  /// SEARCH EXECUTION
  /// -------------------------------------------------------------------------

  /// Forces recomputation of search results
  ///
  /// Used when:
  /// - Returning from note editing
  /// - External data changes
  void refresh() async {
    _recompute();
  }

  /// Core search execution method
  ///
  /// Behavior:
  /// - Delegates search to repository using current state
  /// - Updates cached results
  /// - Notifies listeners (UI rebuild)
  void _recompute() {
    // The UI stays responsive while this waits for the result
    final newResults = searchSync(_state);

    _results = newResults;
    notifyListeners(); // Triggers the AnimatedSwitcher in your results panel
  }

  /// -------------------------------------------------------------------------
  /// CLEANUP
  /// -------------------------------------------------------------------------

  @override
  void dispose() {
    /// Cancels pending debounce timer
    _debounce?.cancel();

    /// Disposes text controller to free resources
    textController.dispose();
    super.dispose();
  }
}
