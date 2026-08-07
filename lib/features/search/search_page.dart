import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/services/smooth_slide_fade.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_dialog.dart';
import 'package:notepad/features/search/widgets/results/search_results_panel.dart';
import 'package:notepad/features/search/widgets/search_input_field_bar.dart';

// Search page owns query input, filters, result browsing, and scroll-to-top behavior.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final search_ctrl.SearchController _searchController =
      search_ctrl.SearchController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showHeaders = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchStateChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _showHeaders.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.viewInsetsBottom > 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          Future.delayed(
            NoteConstants.notePageKeyboardDismissDelay,
            () => Navigator.of(context).pop(),
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _showHeaders,
                  builder: (context, show, _) => SmoothSlideFade(
                    isVisible: show,
                    minHeight: kToolbarHeight,
                    child: AppBar(
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      titleSpacing: 0,
                      title: Padding(
                        padding: const EdgeInsets.only(
                          right: SearchConstants.appBarTitleRightPadding,
                        ),
                        child: SearchInputFieldBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                        ),
                      ),
                      actions: [
                        SearchFilterActionButton(
                          controller: _searchController,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _buildResultsPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleHeaders(bool show) {
    _showHeaders.value = show;
  }

  double _lastPixelOffset = 0.0;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 1) {
      return true; //For nested viewport's scroll notification handling
    }
    if (notification.depth != 0) return false;

    //If there are no results, completely ignore scroll physics.
    if (_searchController.isShowingEmptyState) {
      _onSearchStateChanged();
      return false;
    }

    final metrics = notification.metrics;
    final currentPixels = metrics.pixels;
    final maxScroll = metrics.maxScrollExtent;

    // Ignore bounce/overscroll physics outside valid bounds
    if (metrics.outOfRange) return false;

    // Always show headers/chips at the top
    if (currentPixels <= 0) {
      _toggleHeaders(true);
      _lastPixelOffset = 0.0;
      return false;
    }

    // Always hide headers/chips at the bottom
    if (currentPixels >= maxScroll - SearchConstants.scrollBottomBoundary) {
      _toggleHeaders(false);
      return false;
    }

    final bool isPhysicalDrag =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;

    // Toggle based on scroll delta
    final delta = currentPixels - _lastPixelOffset;

    if (isPhysicalDrag &&
        delta.abs() > SearchConstants.scrollHideDeltaThreshold) {
      if (delta > 0 && _showHeaders.value) {
        if (currentPixels > SearchConstants.scrollLayoutShiftSafeZone) {
          _toggleHeaders(false); // Scrolling down -> hide
        }
      } else if (delta < 0 && !_showHeaders.value) {
        _toggleHeaders(true); // Scrolling up -> show
      }
      _lastPixelOffset = currentPixels;
    } else if (!isPhysicalDrag) {
      //prevents massive, fake pixel spikes in background
      _lastPixelOffset = currentPixels;
    }

    return false;
  }

  Future<void> _onSearchStateChanged() async {
    if (_searchController.isShowingEmptyState) {
      if (!_showHeaders.value) {
        _toggleHeaders(true);
        _lastPixelOffset = 0.0;
      }
    }
  }

  Widget _buildResultsPanel() {
    return Padding(
      padding: const EdgeInsets.only(
        left: SearchConstants.panelPadding,
        top: SearchConstants.panelPadding,
        bottom: SearchConstants.panelPadding,
      ),
      child: SearchResultsPanel(
        controller: _searchController,
        scrollController: _scrollController,
        showChips: _showHeaders,
        onClearFilter: () {
          _toggleHeaders(true);
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: AnimationConstants.fast,
              curve: Curves.easeOut,
            );
          }
        },
      ),
    );
  }
}
