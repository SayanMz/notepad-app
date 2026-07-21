import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/models/search_state.dart';
import 'package:notepad/features/search/services/note_search_service.dart';

// Search controller coordinates filters, results, and query state.
class SearchController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();

  SearchState _state = const SearchState(query: '', filters: SearchFilters());
  List<NotesSection> _results = const [];
  Timer? _debounce;

  List<NotesSection> get results => _results;
  String get query => _state.query;
  SearchFilters get filters => _state.filters;
  bool get hasFilters => _state.hasFilters;
  bool get hasAnyCriteria => _state.hasAnyCriteria;

  void onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(UIConstants.debounceStandard, () {
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
    final newResults = await searchAsync(_state);
    _results = newResults;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.dispose();
    super.dispose();
  }
}

