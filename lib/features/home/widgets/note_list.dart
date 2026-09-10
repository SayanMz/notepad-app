import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_empty_state.dart';
import 'package:notepad/features/home/widgets/note_list_items/swipeable_note_item.dart';

// Home note list that shows pinned and regular notes, with reordering and empty-state handling.
class NoteList extends StatelessWidget {
  const NoteList({
    super.key,
    required this.controller,
    required this.fabController,
  });

  final HomeController controller;
  final HomeFabController fabController;

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenSize.width;
    final maxPreviewLines = screenWidth > HomeConstants.noteListLargeDesktopBreakpoint
        ? HomeConstants.noteCardPreviewLargeDesktopLines
        : screenWidth > HomeConstants.noteListTabletBreakpoint
        ? HomeConstants.noteCardPreviewTabletLines
        : screenWidth > HomeConstants.noteListCompactBreakpoint
        ? HomeConstants.noteCardPreviewSmallTabletLines
        : HomeConstants.noteCardPreviewPhoneLines;

    final pinnedNotes = controller.pinnedNotes;
    final unpinnedNotes = controller.unpinnedNotes;

    if (!controller.hasActiveNotes) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: NoteEmptyState(),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (pinnedNotes.isNotEmpty) ...[
          _buildSectionHeader(context, 'PINNED (${pinnedNotes.length})'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.listPadding,
            ),
            sliver: SliverReorderableList(
              itemCount: pinnedNotes.length,
              itemBuilder: (context, index) {
                final note = pinnedNotes[index];

                return SwipeableNoteItem(
                  key: ValueKey(note.id),
                  index: index,
                  note: note,
                  controller: controller,
                  animationController: controller.animationController,
                  maxPreviewLines: maxPreviewLines,
                );
              },
              onReorderItem: (int oldIndex, int newIndex) {
                controller.handlePinnedReorder(oldIndex, newIndex);
              },
            ),
          ),
        ],
        if (unpinnedNotes.isNotEmpty) ...[
          if (pinnedNotes.isNotEmpty)
            _buildSectionHeader(context, 'OTHERS (${unpinnedNotes.length})'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.listPadding,
            ),
            sliver: SliverReorderableList(
              itemCount: unpinnedNotes.length,
              itemBuilder: (context, index) {
                final note = unpinnedNotes[index];

                return SwipeableNoteItem(
                  key: ValueKey(note.id),
                  index: index,
                  note: note,
                  controller: controller,
                  animationController: controller.animationController,
                  maxPreviewLines: maxPreviewLines,
                );
              },
              onReorderItem: (int oldIndex, int newIndex) {
                controller.handleUnpinnedReorder(oldIndex, newIndex);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: UIConstants.listPadding + UIConstants.paddingXLarge,
          top: UIConstants.paddingXL,
          bottom: UIConstants.paddingSM,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: HomeConstants.noteListSectionHeaderFontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: HomeConstants.noteListSectionHeaderLetterSpacing,
            color: context.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
