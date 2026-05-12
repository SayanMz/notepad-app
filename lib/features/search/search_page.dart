import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/widgets/search_filter_dialog.dart';
import 'package:notepad/features/search/widgets/search_results_panel.dart';
import 'package:notepad/features/search/widgets/smooth_slide_fade.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final search_ctrl.SearchController _searchController =
      search_ctrl.SearchController();
  final FocusNode _searchFocusNode = FocusNode();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // Change in _SearchPageState
  final ValueNotifier<bool> _showHeaders = ValueNotifier(true);

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
    _showHeaders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse) {
              _showHeaders.value = false;
            } else if (notification.direction == ScrollDirection.forward) {
              _showHeaders.value = true;
            }
            return false;
          },
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _showHeaders,
                builder: (context, show, _) {
                  return SmoothSlideFade(
                    isVisible: show,
                    child: SizedBox(
                      key: const ValueKey(
                        'search_header',
                      ), // Key is vital for Switcher
                      width: double.infinity,
                      child: AppBar(
                        surfaceTintColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        titleSpacing: 0,
                        title: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: _buildSearchTextField(),
                        ),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _searchFilter(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SearchResultsPanel(
                    controller: _searchController,
                    showChips: _showHeaders,
                    onClearFilter: () {
                      _showHeaders.value = true;
                    },
                    onNoteTap: (note) async {
                      final didChange = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotePage(noteId: note.id),
                        ),
                      );
                      if (mounted && didChange == true) {
                        _searchController.refresh();
                        if (_searchController.results.isEmpty &&
                            !_showHeaders.value) {
                          _showHeaders.value = true;
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

  Future<void> _openSearchFilterDialog() async {
    final result = await showGeneralDialog<SearchFilters>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildResponsiveDialogWrapper(
          child: SearchFilterBottomSheet(
            initialFilters: _searchController.filters,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
          child: child,
        );
      },
    );

    if (result == null) return;
    _searchController.applyFilters(result);
  }

  Widget _buildResponsiveDialogWrapper({required Widget child}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}
