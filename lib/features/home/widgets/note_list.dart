// Note list assembles the active and deleted sections for the home screen.
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_empty_state.dart';
import 'package:notepad/features/home/widgets/note_list_items/swipeable_note_item.dart';

// Builds the active and deleted note sections with drag and selection behavior.
class NoteList extends StatelessWidget {
  const NoteList({super.key, required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenSize.width;
    final maxPreviewLines = screenWidth > 1200
        ? UIConstants.noteCardPreviewLargeDesktopLines
        : screenWidth > 900
        ? UIConstants.noteCardPreviewTabletLines
        : screenWidth > 600
        ? UIConstants.noteCardPreviewSmallTabletLines
        : UIConstants.noteCardPreviewPhoneLines;

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
                return RepaintBoundary(
                  key: ValueKey(note.id),
                  child: SwipeableNoteItem(
                    index: index,
                    note: note,
                    controller: controller,
                    animationController: controller.animationController,
                    maxPreviewLines: maxPreviewLines,
                  ),
                );
              },
              onReorderItem: (int oldIndex, int newIndex) {
                controller.handlePinnedReorder(oldIndex, newIndex);
              },
              onReorderStart: (index) {
                controller.setDraggingState(true);
              },
              onReorderEnd: (index) {
                controller.setDraggingState(false);
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
                return RepaintBoundary(
                  key: ValueKey(note.id),
                  child: SwipeableNoteItem(
                    index: index,
                    note: note,
                    controller: controller,
                    animationController: controller.animationController,
                    maxPreviewLines: maxPreviewLines,
                  ),
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
          left: UIConstants.listPadding + 20,
          top: 24,
          bottom: 8,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: context.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
