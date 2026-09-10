import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/services/model_download_service.dart.dart';
import 'package:notepad/features/search/services/note_search_service.dart';
import 'package:notepad/features/search/services/semantic_search.dart';

/// Coordinates search query debouncing, filter criteria, ONNX semantic topic discovery,
/// result recomputation, and scroll-driven header visibility.
class SearchController extends ChangeNotifier {
  SearchController() {
    _loadSuggestedTopics();
    ModelDownloadService.isModelDownloaded.addListener(_onDownloadCompleted);
  }

  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> showTopBars = ValueNotifier<bool>(true);
  double _lastPixelOffset = 0.0;

  SearchState _state = const SearchState();
  List<NotesSection> _results = const [];
  List<MapEntry<String, int>> _suggestedTopics = const [];
  bool _isModelAvailable = false;
  bool _isAnalyzing = false;
  Timer? _debounce;
  bool _isDisposed = false;

  List<NotesSection> get results => _results;
  List<MapEntry<String, int>> get suggestedTopics => _suggestedTopics;
  bool get isModelAvailable => _isModelAvailable;
  bool get isAnalyzing => _isAnalyzing;
  String get query => _state.query;
  String? get selectedTopic => _state.selectedTopic;
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

  void selectTopic(String topic) {
    if (_state.selectedTopic == topic) {
      // Toggle off if already selected
      _state = _state.copyWith(selectedTopic: () => null);
    } else {
      _state = _state.copyWith(selectedTopic: () => topic);
    }
    _recompute();
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
    _loadSuggestedTopics();
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

  void _onDownloadCompleted() {
    if (!_isDisposed && ModelDownloadService.isModelDownloaded.value) {
      _loadSuggestedTopics();
    }
  }

  void _loadSuggestedTopics() async {
    _isModelAvailable = await SemanticSearchService.isModelAvailable();
    if (!_isModelAvailable) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      final activeIds = noteRepository.activeNotes.map((n) => n.id).toSet();
      _suggestedTopics = await SemanticSearchService.discoverSuggestedTopics(
        activeNoteIds: activeIds,
      );
    } catch (e) {
      debugPrint('Failed to discover suggested topics: $e');
      _suggestedTopics = [];
    } finally {
      _isAnalyzing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // --- Scroll Visibility & Physics Logic ---
  void _updateTopBars(bool visible) {
    if (showTopBars.value == visible) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && showTopBars.value != visible) {
        showTopBars.value = visible;
        if (visible) _lastPixelOffset = 0.0;
      }
    });
  }

  void showHeaders() => _updateTopBars(true);
  void hideHeaders() => _updateTopBars(false);

  void handleScrollNotification(ScrollNotification notification) {
    // Only track the primary vertical scroll list
    if (notification.depth != 0) return;

    if (isShowingEmptyState) {
      showHeaders();
      return;
    }

    final metrics = notification.metrics;
    if (metrics.outOfRange) return;

    final currentPixels = metrics.pixels;
    final maxScroll = metrics.maxScrollExtent;

    // Keep headers pinned when scroll extent is negligible or at top bounce
    if (maxScroll < 80.0 || currentPixels <= 0) {
      showHeaders();
      return;
    }

    // Auto-hide when reaching the bottom margin with sufficient list depth
    if (maxScroll > 150.0 &&
        currentPixels >= maxScroll - SearchConstants.scrollBottomBoundary) {
      hideHeaders();
      return;
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
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    textController.dispose();
    showTopBars.dispose();
    ModelDownloadService.isModelDownloaded.removeListener(_onDownloadCompleted);
    super.dispose();
  }
}
