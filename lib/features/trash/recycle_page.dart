import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/notes_repository.dart'; // Still needed for the global instance injection
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/core/widgets/scroll_to_top_fab.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';
import 'package:notepad/features/trash/recycle_constants.dart';
import 'package:notepad/features/trash/widgets/recycle_empty_state.dart';
import 'package:notepad/features/trash/widgets/recycle_header_delegate.dart';
import 'package:notepad/features/trash/widgets/recycle_notes_sliver_list.dart';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  bool get isDark => context.isDark;

  late final RecycleController _controller;
  // ⚡ ADD THIS: The missing controller instance needed to trigger the scroll reset
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _showScrollToTopBtn = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _controller = RecycleController(noteRepository: noteRepository);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _showScrollToTopBtn.dispose();
    super.dispose();
  }

  // --- UI INTERACTION HANDLERS ---
  // Notice how these methods now only handle UI elements (Dialogs, Snackbars),
  // and delegate the actual data changes to _controller.

  Future<void> _handleRestoreNote(NotesSection note) async {
    final title = note.displayTitle; //
    final isRestored = await _controller.restoreNote(note.id);

    if (!(mounted || isRestored)) {
      debugPrint("The note: ${note.id} couldn't be restored."); //
      return;
    }

    showRestorationSnackBar(
      message: '$title is now restored.', //
      onUndo: () => _controller.undoRestore(note.id),
    );
  }

  Future<void> _handleDeleteForever(NotesSection note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever?'), //
        content: const Text('This action cannot be undone.'), //
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), //
            child: const Text('Cancel'), //
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, //
              foregroundColor: Colors.white, //
            ),
            onPressed: () => Navigator.pop(context, true), //
            child: const Text('Delete'), //
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    _controller.deleteForever(note.id);

    if (!mounted) return;
    Navigator.pop(context); // Close the bottom sheet if it's open
  }

  Future<void> _handleEmptyRecycleBin() async {
    // 1. Grab a frozen copy of the notes currently in the trash

    // 2. High-friction confirmation
    final shouldEmpty = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Recycle Bin?'), //
        content: const Text(
          'All notes in the trash will be permanently deleted. This action cannot be undone.', //
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), //
            child: const Text('Cancel'), //
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, //
              foregroundColor: Colors.white, //
            ),
            onPressed: () => Navigator.pop(context, true), //
            child: const Text('Empty Trash'), //
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
          top: Radius.circular(RecycleConstants.sheetRadius), //
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, //
          children: [
            const SizedBox(height: RecycleConstants.sheetHandleTopGap), //
            Container(
              width: RecycleConstants.sheetHandleWidth, //
              height: RecycleConstants.sheetHandleHeight, //
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(
                        alpha: RecycleConstants.sheetHandleDarkAlpha,
                      ) //
                    : Colors.black.withValues(
                        alpha: RecycleConstants.sheetHandleLightAlpha,
                      ), //
                borderRadius: BorderRadius.circular(
                  RecycleConstants.sheetHandleRadius,
                ), //
              ),
            ),
            const SizedBox(height: RecycleConstants.sheetHandleBottomGap), //
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.green), //
              title: const Text('Restore note'), //
              onTap: () {
                Navigator.pop(context); //
                _handleRestoreNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red), //
              title: const Text('Delete forever'), //
              onTap: () => _handleDeleteForever(note),
            ),
          ],
        ),
      ),
    );
  }

  // --- MAIN BUILD PIPELINE ---
  @override
  Widget build(BuildContext context) {
    const notesEmptyText = "Your trash is beautifully empty.";
    final cardWidth =
        context.screenSize.width - (RecycleConstants.listPadding * 2); //[cite: 3]

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : AppColors.lightScaffold, //[cite: 3]
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final isEmpty = _controller.isEmpty;

            return Stack(
              children: [
                // 1. The Scroll View with Activity Tracking
                NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    final shouldShow = notification.metrics.pixels > 200.0;

                    if (_showScrollToTopBtn.value != shouldShow) {
                      _showScrollToTopBtn.value = shouldShow;
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller:
                        _scrollController, // ⚡ Bound missing reference mapping
                    physics: isEmpty
                        ? const NeverScrollableScrollPhysics() //[cite: 3]
                        : const BouncingScrollPhysics(
                            decelerationRate: ScrollDecelerationRate.fast,
                            parent: ClampingScrollPhysics(),
                          ), //[cite: 3]
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true, //[cite: 3]
                        delegate: SmoothHeaderDelegate(
                          title: 'Recycle Bin', //[cite: 3]
                          isDark: isDark, //[cite: 3]
                          forceCentered: isEmpty,
                          onEmptyBin: _handleEmptyRecycleBin,
                        ),
                      ),
                      if (isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false, //[cite: 3]
                          child: RecycleEmptyState(
                            text: notesEmptyText,
                            isDark: isDark,
                          ),
                        )
                      else
                        RecycleNotesSliverList(
                          controller: _controller,
                          isDark: isDark,
                          cardWidth: cardWidth,
                          onRestore: _handleRestoreNote,
                          onShowActionSheet: _showNoteActionSheet,
                        ), // ⚡ Fixed truncated signature closing
                    ],
                  ),
                ),

                ScrollToTopFab(
                  scrollController: _scrollController,
                  showScrollToTopBtn: _showScrollToTopBtn,
                  heroTag: 'scrollToTopRecycle',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
