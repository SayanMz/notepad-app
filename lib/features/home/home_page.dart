import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/controllers/sync_controller.dart';
import 'package:notepad/features/home/widgets/drawer_items/home_drawer.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/home_fab.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_list.dart';
import 'package:notepad/features/home/widgets/selection_tools/selection_overlay.dart';

// Home page shell that coordinates note browsing, actions, and list state.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScrollController _scrollController;
  late final SelectionController _selectionController;
  late final AnimationControllerState _animationController;
  late final HomeFabController _fabController;
  late final AuthController _authController;
  late final SyncController _syncController;
  late final HomeController _controller;

  bool _handleScroll(Notification notification) {
    if (!mounted) return false;

    return _fabController.handleScroll(
      notification,
      isSelectionMode: _selectionController.isSelectionMode,
    );
  }

  ScrollPhysics get _scrollPhysics {
    if (noteRepository.activeNotes.isEmpty) {
      return const NeverScrollableScrollPhysics();
    }
    if (_selectionController.isSelectionMode) {
      return const AlwaysScrollableScrollPhysics();
    }
    return const BouncingScrollPhysics();
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectionController = SelectionController();
    _animationController = AnimationControllerState();
    _fabController = HomeFabController();
    _authController = authController;
    _syncController = SyncController(authController: _authController);
    _controller = HomeController(
      selectionController: _selectionController,
      animationController: _animationController,
    );
    _authController.initialize();
    noteRepository.activeRevision.addListener(_handleNotesChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _syncController.dispose();
    _fabController.dispose();
    _selectionController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    noteRepository.activeRevision.removeListener(_handleNotesChanged);
    super.dispose();
  }

  void _handleNotesChanged() {
    if (_controller.activeNotes.isEmpty && _scrollController.hasClients) {
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPopScope(
      selectionController: _selectionController,
      builder: (context, isSelectionMode) {
        return NotificationListener<Notification>(
          onNotification: _handleScroll,
          child: Scaffold(
            backgroundColor: context.theme.scaffoldBackgroundColor,
            endDrawer: HomeDrawer(
              authController: _authController,
              syncController: _syncController,
            ),
            body: Stack(
              children: [
                SafeArea(
                  child: ListenableBuilder(
                    listenable: noteRepository.activeRevision,
                    builder: (context, child) {
                      return CustomScrollView(
                        controller: _scrollController,
                        physics: _scrollPhysics,
                        scrollCacheExtent: ScrollCacheExtent.pixels(
                          context.screenSize.height * 0.40,
                        ),
                        slivers: [
                          HomeAppBar(
                            onOpenDrawer: () =>
                                Scaffold.of(context).openEndDrawer(),
                          ),
                          NoteList(
                            controller: _controller,
                            fabController: _fabController,
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(
                              bottom: isSelectionMode ? 90 : 80,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SelectionOverlay(controller: _controller),
                HomeFab(
                  fabController: _fabController,
                  selectionController: _selectionController,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SelectionPopScope extends StatelessWidget {
  const SelectionPopScope({
    super.key,
    required this.selectionController,
    required this.builder,
  });

  final SelectionController selectionController;
  final Widget Function(BuildContext context, bool isSelectionMode) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selectionController,
      builder: (context, _) {
        final isSelectionMode = selectionController.isSelectionMode;

        return PopScope(
          canPop: !isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            if (isSelectionMode) {
              if (selectionController.selectionCount > 0) {
                HapticFeedback.mediumImpact();
                selectionController.clearSelection();
              } else {
                selectionController.exitSelectionMode();
              }
            }
          },
          child: builder(context, isSelectionMode),
        );
      },
    );
  }
}
