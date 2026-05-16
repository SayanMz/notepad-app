import 'dart:async';

import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter/services.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
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
  bool _handleScroll(Notification notification) {
    if (!mounted) return false;
    return _controller.handleFabScroll(
      notification,
      MediaQuery.of(context).size,
      isSelectionMode,
    );
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

  // REWRITE to use the controller wrapper
  Future<void> _handleCloudAction(Future<void> Function() action) async {
    await _controller
        .runCloudOperation(
          action: action,
          loadingNotifier: _controller.isSavingNotifier,
          onStatusUpdate: (text, color) {
            _controller.syncStatusNotifier.value = text;
            _controller.statusColorNotifier.value = color;

            if (text == 'All saved') {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  _controller.syncStatusNotifier.value = 'Ready to sync';
                  _controller.statusColorNotifier.value = null;
                }
              });
            }
          },
        )
        .catchError((e) {
          showErrorSnackBar('Operation failed: $e');
        });
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
    final selectedNotes = noteRepository.selectedNotes;
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
    _setSelectionMode(false);
    _controller.executeBulkDelete(); // Logic moved to controller
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
            noteRepository.clearSelection();
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
          endDrawer: HomeDrawer(
            controller: _controller,
            isDark: isDark,
            handleCloudAction: _handleCloudAction,
          ),
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                cacheExtent: 400.0,
                physics: _controller.activeNotes.isEmpty
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
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
                    child: SizedBox(height: isSelectionMode ? 140.0 : 100.0),
                  ),
                ],
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
