import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/services/smooth_slide_fade.dart';
import 'package:notepad/features/search/widgets/header/search_collapsible_header.dart';
import 'package:notepad/features/search/widgets/results/results_view.dart';

// Strict heights to guarantee pixel-perfect padding
const double kSearchTopBarHeight = 112.0; // 56 (AppBar) + 56 (Chips)
const double kSearchMetadataHeight = 56.0;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
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
            onNotification: _searchController.handleScrollNotification,
            child: Stack(
              children: [
                Positioned.fill(
                  //Initial + Empty State + Drag Handle + Search Result cards
                  child: ResultsView(
                    controller: _searchController,
                    scrollController: _scrollController,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //BLOCK A: Dynamically hide the AppBar + Quick Chips
                      ValueListenableBuilder<bool>(
                        valueListenable: _searchController.showTopBars,
                        builder: (context, showTop, _) {
                          return Material(
                            color: context.theme.scaffoldBackgroundColor,
                            elevation: 0,
                            child: SmoothSlideFade(
                              showTopBars: showTop,
                              child: SearchCollapsibleHeader(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                              ),
                            ),
                          );
                        },
                      ),

                      // BLOCK B: Pinned Results Count
                      Material(
                        color: context.theme.scaffoldBackgroundColor,
                        elevation: 0,
                        child: ResultsMetadataHeader(
                          controller: _searchController,
                          onClearFilter: () {
                            _searchController.showHeaders();
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0.0,
                                duration: AnimationConstants.fast,
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
