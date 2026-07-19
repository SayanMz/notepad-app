import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/core/widgets/scroll_to_top_fab.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';
import 'package:notepad/features/trash/recycle_constants.dart';
import 'package:notepad/features/trash/widgets/recycle_empty_state.dart';
import 'package:notepad/features/trash/widgets/recycle_header_delegate.dart';
import 'package:notepad/features/trash/widgets/recycle_notes_sliver_list.dart';

// Recycle bin keeps deleted notes available for restore or permanent deletion.
class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  bool get isDark => context.isDark;

  late final RecycleController _controller;
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _showScrollToTopBtn = ValueNotifier<bool>(false);
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = RecycleController(noteRepository: noteRepository);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _showScrollToTopBtn.dispose();
    super.dispose();
  }

  Future<void> _handleRestoreNote(NotesSection note) async {
    final title = note.displayTitle;
    final isRestored = await _controller.restoreNote(note.id);

    if (!(mounted || isRestored)) {
      debugPrint("The note: ${note.id} couldn't be restored.");
      return;
    }

    showRestorationSnackBar(
      message: '$title is now restored.',
      onUndo: () => _controller.undoRestore(note.id),
    );
  }

  Future<void> _handleDeleteForever(NotesSection note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    _controller.deleteForever(note.id);

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _handleEmptyRecycleBin() async {
    final shouldEmpty = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Recycle Bin?'),
        content: const Text(
          'All notes in the trash will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (shouldEmpty == true) {
      _controller.emptyRecycleBin();
    }
  }

  void _showNoteActionSheet(BuildContext context, NotesSection note) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RecycleConstants.sheetRadius),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: RecycleConstants.sheetHandleTopGap),
            Container(
              width: RecycleConstants.sheetHandleWidth,
              height: RecycleConstants.sheetHandleHeight,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(
                        alpha: RecycleConstants.sheetHandleDarkAlpha,
                      )
                    : Colors.black.withValues(
                        alpha: RecycleConstants.sheetHandleLightAlpha,
                      ),
                borderRadius: BorderRadius.circular(
                  RecycleConstants.sheetHandleRadius,
                ),
              ),
            ),
            const SizedBox(height: RecycleConstants.sheetHandleBottomGap),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.green),
              title: const Text('Restore note'),
              onTap: () {
                Navigator.pop(context);
                _handleRestoreNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete forever'),
              onTap: () => _handleDeleteForever(note),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const notesEmptyText = 'Recycle bin is empty';
    final cardWidth =
        context.screenSize.width - (RecycleConstants.listPadding * 2);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : AppColors.lightScaffold,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final isEmpty = _controller.isEmpty;

            return Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: isEmpty
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(
                          decelerationRate: ScrollDecelerationRate.fast,
                          parent: ClampingScrollPhysics(),
                        ),
                  scrollCacheExtent: ScrollCacheExtent.pixels(
                    HomeConstants.homeScrollCacheExtent,
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: SmoothHeaderDelegate(
                        title: 'Recycle Bin',
                        forceCentered: isEmpty,
                        onEmptyBin: _handleEmptyRecycleBin,
                      ),
                    ),
                    if (isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: RecycleEmptyState(text: notesEmptyText),
                      )
                    else
                      RecycleNotesSliverList(
                        controller: _controller,
                        cardWidth: cardWidth,
                        onRestore: _handleRestoreNote,
                        onShowActionSheet: _showNoteActionSheet,
                      ),
                  ],
                ),

                ScrollToTopFab(
                  scrollController: _scrollController,
                  heroTag: 'scrollToTopRecycle',
                  behavior: FabScrollBehavior.persistentWhileScrolling,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
