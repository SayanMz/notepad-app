import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/services/note_search_service.dart';

// Search controller coordinates filters, results, query state, and top bar visibility.
class SearchController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();

  final ValueNotifier<bool> showTopBars = ValueNotifier<bool>(true);
  double _lastPixelOffset = 0.0;

  SearchState _state = const SearchState(query: '', filters: SearchFilters());
  List<NotesSection> _results = const [];
  Timer? _debounce;
  bool _isDisposed = false;

  List<NotesSection> get results => _results;
  String get query => _state.query;
  SearchFilters get filters => _state.filters;
  bool get hasFilters => _state.hasFilters;
  bool get hasAnyCriteria => _state.hasAnyCriteria;
  bool get isShowingEmptyState => _results.isEmpty || !hasAnyCriteria;

  void onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AnimationConstants.debounceStandard, () {
      _state = _state.copyWith(query: value.trim());
      _recompute();
    });
  }

  void clearQuery() {
    _debounce?.cancel();
    textController.clear();
    _state = _state.copyWith(query: '');
    _recompute();
  }

  void clearFilter() {
    _state = _state.copyWith(filters: const SearchFilters());
    _recompute();
  }

  void applyFilters(SearchFilters newfilters) {
    _state = _state.copyWith(filters: newfilters);
    _recompute();
  }

  void refresh() {
    _recompute();
  }

  void _recompute() async {
    final searchState = _state;
    final newResults = await NoteSearchService.searchAsync(searchState);

    // If the controller was disposed or the state changed while we were
    // awaiting the results, discard them and return.
    if (_isDisposed || searchState != _state) return;

    _results = newResults;

    if (isShowingEmptyState) {
      showHeaders();
    }

    notifyListeners();
  }

  // --- Scroll Visibility & Physics Logic ---
  void showHeaders() {
    if (!showTopBars.value) {
      showTopBars.value = true;
      _lastPixelOffset = 0.0;
    }
  }

  void hideHeaders() {
    if (showTopBars.value) {
      showTopBars.value = false;
    }
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 1) return true;
    if (notification.depth != 0) return false;

    // Reset headers if in an empty state
    if (isShowingEmptyState) {
      showHeaders();
      return false;
    }

    final metrics = notification.metrics;
    final currentPixels = metrics.pixels;
    final maxScroll = metrics.maxScrollExtent;

    if (metrics.outOfRange) return false;

    // Show at top boundary
    if (currentPixels <= 0) {
      showHeaders();
      return false;
    }

    // Hide at bottom boundary
    if (currentPixels >= maxScroll - SearchConstants.scrollBottomBoundary) {
      hideHeaders();
      return false;
    }

    final bool isPhysicalDrag =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;

    final delta = currentPixels - _lastPixelOffset;

    if (isPhysicalDrag &&
        delta.abs() > SearchConstants.scrollHideDeltaThreshold) {
      if (delta > 0 && showTopBars.value) {
        if (currentPixels > SearchConstants.scrollLayoutShiftSafeZone) {
          hideHeaders();
        }
      } else if (delta < 0 && !showTopBars.value) {
        showHeaders();
      }
      _lastPixelOffset = currentPixels;
    } else if (!isPhysicalDrag) {
      _lastPixelOffset = currentPixels;
    }

    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    textController.dispose();
    showTopBars.dispose();
    super.dispose();
  }
}
