// Search page keeps results, filter controls, and empty states together.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/widgets/scroll_to_top_fab.dart';
import 'package:notepad/features/filter/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/filter/models/search_filters.dart';
import 'package:notepad/features/filter/search_constants.dart';
import 'package:notepad/features/filter/services/smooth_slide_fade.dart';
import 'package:notepad/features/filter/widgets/search_filter_dialog.dart';
import 'package:notepad/features/filter/widgets/search_results_panel.dart';
import 'package:notepad/features/note/note_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final search_ctrl.SearchController _searchController =
      search_ctrl.SearchController();
  final FocusNode _searchFocusNode = FocusNode();

  bool get isDark => context.isDark;

  final ValueNotifier<bool> _showHeaders = ValueNotifier(true);

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showScrollToTopBtn = ValueNotifier<bool>(false);

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
    _scrollController.dispose();
    _showScrollToTopBtn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification.depth == 1) {
              return true;
            }

            if (notification.depth == 0) {
              final shouldShow = notification.metrics.pixels > 200.0;
              if (_showScrollToTopBtn.value != shouldShow) {
                _showScrollToTopBtn.value = shouldShow;
              }

              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.reverse) {
                  _showHeaders.value = false;
                } else if (notification.direction == ScrollDirection.forward) {
                  _showHeaders.value = true;
                }
              }
            }
            return false;
          },
          child: Stack(
            children: [
              Column(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _showHeaders,
                    builder: (context, show, _) {
                      return SmoothSlideFade(
                        isVisible: show,
                        child: SizedBox(
                          key: const ValueKey('search_header'),
                          width: double.infinity,
                          child: AppBar(
                            surfaceTintColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            titleSpacing: 0,
                            title: Padding(
                              padding: const EdgeInsets.only(
                                right: SearchConstants.appBarTitleRightPadding,
                              ),
                              child: _buildSearchTextField(),
                            ),
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: SearchConstants.appBarActionPadding,
                                ),
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
                          _showHeaders.value = true;
                        },
                        onNoteTap: (note) async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotePage(noteId: note.id),
                            ),
                          );
                          if (!mounted) return;
                          _searchController.refresh();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: _searchController,
                builder: (context, _) {
                  return ScrollToTopFab(
                    scrollController: _scrollController,
                    showScrollToTopBtn: _showScrollToTopBtn,
                    heroTag: 'scrollToTopSearch',
                    additionalCondition: _searchController.hasAnyCriteria,
                    onPressed: () {
                      _showHeaders.value = true;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTextField() {
    final colorScheme = context.colorScheme;

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
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: SearchConstants.searchFieldBorderWidth,
          ),
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
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
        size: SearchConstants.filterButtonSize,
      ),
      splashRadius: SearchConstants.filterButtonSize,
    );
  }

  Future<void> _openSearchFilterDialog() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));

    final result = await showGeneralDialog<SearchFilters>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withValues(
        alpha: SearchConstants.dialogBarrierAlpha,
      ),
      transitionDuration: AnimationConstants.snappy,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildResponsiveDialogWrapper(
          child: SearchFilterBottomSheet(
            initialFilters: _searchController.filters,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (result != null) {
      _searchController.applyFilters(result);
    }
    Future.delayed(const Duration(milliseconds: 0), () {
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildResponsiveDialogWrapper({required Widget child}) {
    return Builder(
      builder: (context) {
        final bottomInset = context.viewInsetsBottom;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: SearchConstants.filterDialogMaxWidth,
                ),
                child: Material(color: Colors.transparent, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
