import 'dart:async';

import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter/services.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/home_drawer.dart';
import 'package:notepad/features/home/widgets/home_fab.dart';
import 'package:notepad/features/home/widgets/note_list.dart';
import 'package:notepad/features/home/widgets/selection_overlay.dart';
import 'package:notepad/features/note/note_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool get isDark => context.isDark;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isSelectionMode = false;
  late ScrollController _scrollController;
  late final HomeController _controller;
  Timer? _debounce;

  // REPLACE the old _handleScroll with this
  // Location: home_page.dart
  bool _handleScroll(Notification notification) {
    if (!mounted) return false;

    // Updated to match the new signature
    return _controller.handleFabScroll(notification, isSelectionMode);
  }

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setSelectionMode(bool enabled) {
    setState(() {
      isSelectionMode = enabled;
    });
  }

  Future<void> _exitSelectionMode() async {
    await _controller.flushPendingPinnedWrites();
    _setSelectionMode(false);
  }

  Future<void> _shareSelectedNotesAsHTML() async {
    _controller.isSavingNotifier.value = true;

    await _controller.shareSelectedNotes(
      onError: (errorMessage) {
        if (!mounted) return;
        showErrorSnackBar('Could not share selected notes: $errorMessage');
      },
    );

    if (mounted) {
      _controller.isSavingNotifier.value = false;
    }
  }

  Future<void> _confirmBulkDelete() async {
    final selectedNotes = _controller.selectedNotes;
    final selectedCount = selectedNotes.length;

    if (selectedNotes.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move selected notes to recycle bin?'),
        content: Text(
          selectedCount == 1
              ? 'The selected note will be moved to the recycle bin.'
              : '$selectedCount notes will be moved to the recycle bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    await _controller.flushPendingPinnedWrites();

    _controller.executeBulkDelete(); // Logic moved to controller
    _setSelectionMode(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (isSelectionMode) {
          final selectedCount = _controller.selectedNotes.length;

          if (selectedCount > 0) {
            HapticFeedback.mediumImpact();
            _controller.clearSelection();
          } else {
            _exitSelectionMode();
          }
        }
      },
      child: NotificationListener<Notification>(
        onNotification: _handleScroll,
        child: Scaffold(
          key: _scaffoldKey,

          backgroundColor: isDark
              ? AppColors.darkScaffold
              : AppColors.lightScaffold,
          endDrawer: HomeDrawer(controller: _controller, isDark: isDark),
          body: Stack(
            children: [
              ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  return CustomScrollView(
                    controller: _scrollController,
                    key: ValueKey(
                      'home_scroll_view_empty_${_controller.activeNotes.isEmpty}',
                    ),
                    cacheExtent: HomeConstants.homeScrollCacheExtent,
                    physics: _controller.activeNotes.isEmpty
                        ? const NeverScrollableScrollPhysics()
                        : _controller.isSelectionMode
                        ? const AlwaysScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    slivers: [
                      HomeAppBar(
                        isDark: isDark,
                        isSavingNotifier: _controller.isSavingNotifier,
                        fadeRoute: AppRouter.fade,
                        slideRoute: AppRouter.slide,
                        onOpenDrawer: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                      ),

                      NoteList(
                        isSelectionMode: isSelectionMode,
                        // Inside CustomScrollView -> slivers -> NoteList
                        onOpenNote: (noteId) => _controller.openNote(
                          noteId: noteId,
                          onNavigate: (id) async {
                            await Navigator.push(
                              context,
                              AppRouter.slide(NotePage(noteId: id)),
                            );
                          },
                        ),
                        onTogglePin: (noteId) async =>
                            _controller.togglePin(noteId),
                        onShare: _shareSelectedNotesAsHTML,
                        onDeleteSelected: _confirmBulkDelete,
                        onSelectionToggle: () {
                          if (isSelectionMode) {
                            _exitSelectionMode();
                          } else {
                            _setSelectionMode(true);
                          }
                        },
                        controller: _controller,
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: isSelectionMode
                              ? HomeConstants.homeSelectionSpacerExpanded
                              : HomeConstants.homeSelectionSpacerCollapsed,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SelectionOverlay(
                controller: _controller,
                isSelectionMode: isSelectionMode,
                isDark: isDark,
                onShare: _shareSelectedNotesAsHTML,
                onDelete: _confirmBulkDelete,
              ),
              HomeFab(
                controller: _controller,
                isSelectionMode: isSelectionMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
