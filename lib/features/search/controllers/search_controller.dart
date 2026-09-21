import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/services/model_download_service.dart';
import 'package:notepad/features/search/services/search_service.dart';
import 'package:notepad/features/search/services/semantic_search.dart';

/// Coordinates search query debouncing, filter criteria, ONNX semantic topic discovery,
/// result recomputation, and scroll-driven header visibility.
class SearchController extends ChangeNotifier {
  SearchController() {
    _initModelStatus();
    ModelDownloadService.statusNotifier.addListener(_onModelStatusChanged);
    SemanticSearchService.cacheRevision.addListener(_onCacheInvalidated);
  }

  // --- Public UI Controllers & Notifiers ---
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<bool> showTopBars = ValueNotifier<bool>(true);

  // --- Internal State & Variables ---
  SearchState _state = const SearchState();
  List<NotesSection> _results = const [];
  List<MapEntry<String, int>> _suggestedTopics = const [];
  double _lastPixelOffset = 0.0;
  Timer? _debounce;
  bool _isAnalyzing = false;
  bool _isDisposed = false;

  // --- Getters ---
  String get query => _state.query;
  String? get selectedTopic => _state.selectedTopic;
  SearchFilters get filters => _state.filters;
  bool get hasFilters => _state.hasFilters;
  bool get hasAnyCriteria => _state.hasAnyCriteria;
  bool get isShowingEmptyState => _results.isEmpty || !hasAnyCriteria;

  bool get isAnalyzing => _isAnalyzing;
  List<NotesSection> get results => _results;
  List<MapEntry<String, int>> get suggestedTopics => _suggestedTopics;
  Map<String, NotesSection> get cacheMap => noteRepository.cacheMap;

  // --- Public Actions & Search Criteria ---
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

  void applyFilters(SearchFilters newfilters) {
    _state = _state.copyWith(filters: newfilters);
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

  void refresh() {
    _recompute();
  }

  // --- Scroll Visibility & Physics Logic ---
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

  void _updateTopBars(bool visible) {
    if (showTopBars.value == visible) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && showTopBars.value != visible) {
        showTopBars.value = visible;
        if (visible) _lastPixelOffset = 0.0;
      }
    });
  }

  // --- Query Recomputation & AI Lifecycle ---
  void _recompute() async {
    final searchState = _state;
    final newResults = await SearchService.searchAsync(
      searchState,
      liveCacheMap: cacheMap,
    );

    // If the controller was disposed or the state changed while we were
    // awaiting the results, discard them and return.
    if (_isDisposed || searchState != _state) return;

    _results = newResults;

    if (isShowingEmptyState) {
      showHeaders();
    }

    notifyListeners();
  }

  void _onModelStatusChanged() {
    if (_isDisposed) return;
    if (ModelDownloadService.statusNotifier.value == ModelDownloadState.ready) {
      _loadSuggestedTopics();
    }
  }

  Future<void> _initModelStatus() async {
    if (ModelDownloadService.statusNotifier.value == ModelDownloadState.ready) {
      _loadSuggestedTopics();
    }
  }

  Future<void> _onCacheInvalidated() async {
    if (!_isDisposed) {
      await _loadSuggestedTopics();
      _recompute();
    }
  }

  Future<void> _loadSuggestedTopics() async {
    if (_isDisposed) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      final activeIds = noteRepository.activeNotes.map((n) => n.id).toList();
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

  // --- Lifecycle Cleanup ---
  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    textController.dispose();
    showTopBars.dispose();
    ModelDownloadService.statusNotifier.removeListener(_onModelStatusChanged);
    SemanticSearchService.cacheRevision.removeListener(_onCacheInvalidated);
    super.dispose();
  }
}
