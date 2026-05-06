import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/widgets/search_filter_dialog.dart';
import 'package:notepad/features/search/widgets/search_results_panel.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final search_ctrl.SearchController _searchController =
      search_ctrl.SearchController(repository: noteRepository);

  final FocusNode _searchFocusNode = FocusNode();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // State to control visibility of AppBar and Chips
  bool _showHeaders = true;

  final bool _isOpeningSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            // Hide headers when scrolling down
            if (notification.direction == ScrollDirection.reverse) {
              if (_showHeaders) setState(() => _showHeaders = false);
            }
            // Show headers when scrolling up
            else if (notification.direction == ScrollDirection.forward) {
              if (!_showHeaders) setState(() => _showHeaders = true);
            }
            return false;
          },
          child: Column(
            children: [
              /// ---------------------------------------------------------------
              /// ANIMATED APP BAR (TextField + Filter exactly as requested)
              /// ---------------------------------------------------------------
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _showHeaders
                    ? SizedBox(
                        width: double.infinity,
                        child: AppBar(
                          surfaceTintColor: Colors.transparent,
                          // TextField securely placed in title
                          title: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildSearchTextField(),
                          ),
                          titleSpacing: 0,
                          // Filter button placed securely in actions
                          actions: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _searchFilter(),
                            ),
                          ],
                          primary:
                              false, // Prevents double spacing under SafeArea
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),

              /// ---------------------------------------------------------------
              /// SEARCH RESULTS PANEL
              /// ---------------------------------------------------------------
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SearchResultsPanel(
                    controller: _searchController,
                    showChips: _showHeaders,
                    // FIX: Force headers back open when clear filter is pressed
                    onClearFilter: () {
                      if (!_showHeaders) {
                        setState(() => _showHeaders = true);
                      }
                    },
                    onNoteTap: (note) async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotePage(noteId: note.id),
                        ),
                      );
                      if (mounted) {
                        _searchController.refresh();
                        // FIX: Safety check in case they deleted the last note
                        if (_searchController.results.isEmpty &&
                            !_showHeaders) {
                          setState(() => _showHeaders = true);
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTextField() {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      onChanged: _searchController.onQueryChanged,
      controller: _searchController.textController,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search title or content...',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController.textController,
          builder: (context, value, _) {
            return value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clearQuery();
                      _searchFocusNode.requestFocus();
                      // Also reveal headers if text is cleared manually
                      if (!_showHeaders) setState(() => _showHeaders = true);
                    },
                  );
          },
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXL),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXL),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: UIConstants.searchFieldBorderWidth,
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusXL),
        ),
      ),
    );
  }

  Widget _searchFilter() {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: _openSearchFilterDialog,
      icon: ImageIcon(
        const AssetImage('assets/images/filter_icon.png'),
        color: isDark ? const Color(0xFFFFFFFF) : Colors.black54,
        size: 24,
      ),
      splashRadius: 24,
    );
  }

  // 2. Updated function with the "Guard" pattern
  Future<void> _openSearchFilterDialog() async {
    final result = await showGeneralDialog<SearchFilters>(
      context: context,
      barrierDismissible: true, // Tapping background closes it
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withValues(
        alpha: 0.5,
      ), // Impenetrable native barrier
      transitionDuration: const Duration(
        milliseconds: 400,
      ), // Your custom speed
      // 1. Where the widget sits on the screen
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          // Inside _openSearchFilterDialog in SearchPage.dart
          child: SafeArea(
            bottom: true,
            child: ConstrainedBox(
              // Removed outer GestureDetector swipe logic
              constraints: const BoxConstraints(maxWidth: 600),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Still blocks tap-through to the barrier
                  child: SearchFilterBottomSheet(
                    initialFilters: _searchController.filters,
                  ),
                ),
              ),
            ),
          ),
        );
      },

      // 2. The custom Slide Animation
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 1), // Starts off-screen at the bottom
                end: Offset.zero, // Rests in its normal position
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves
                      .easeOutQuart, // A premium, smooth deceleration curve
                ),
              ),
          child: child,
        );
      },
    );

    // This code only runs AFTER the dialog is fully closed
    if (result == null) return;
    _searchController.applyFilters(result);

    // Reveal headers if hidden
    if (!_showHeaders) setState(() => _showHeaders = true);
  }
}
