import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_empty_state.dart';
// Import your newly extracted widget
import 'package:notepad/features/home/widgets/note_list_items/swipeable_note_item.dart';

class NoteList extends StatelessWidget {
  const NoteList({
    super.key,
    required this.isSelectionMode,
    required this.onOpenNote,
    required this.onTogglePin,
    required this.onShare,
    required this.onDeleteSelected,
    required this.onSelectionToggle,
    required this.controller,
  });

  final bool isSelectionMode;
  final Future<void> Function(String noteId) onOpenNote;
  final Future<void> Function(String noteId) onTogglePin;
  final VoidCallback onShare;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSelectionToggle;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: noteRepository.activeRevision,
      builder: (_, _) {
        final activeNotes = noteRepository.activeNotes;
        final pinnedNotes = noteRepository.pinnedNotes;
        final unpinnedNotes = noteRepository.unpinnedNotes;

        if (activeNotes.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: NoteEmptyState(),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            // ZONE 1: PINNED NOTES
            if (pinnedNotes.isNotEmpty) ...[
              _buildSectionHeader(context, "PINNED"),
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
                        // ⚡ Uses Extracted Widget
                        index: noteRepository.getPinnedLocalIndex(note.id),
                        note: note,
                        isSelectionMode: isSelectionMode,
                        controller: controller,
                        onOpenNote: onOpenNote,
                        onSelectionToggle: onSelectionToggle,
                        onTogglePin: onTogglePin,
                        onDeleted: controller.showSingleDeleteSnackbar,
                        isSelected: controller.isNoteSelected(note.id),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    noteRepository.reorderPinnedNotes(oldIndex, newIndex);
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
            ],

            // ZONE 2: UNPINNED NOTES
            if (unpinnedNotes.isNotEmpty) ...[
              if (pinnedNotes.isNotEmpty)
                _buildSectionHeader(context, "OTHERS"),
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
                        // ⚡ Uses Extracted Widget
                        index: noteRepository.getUnpinnedLocalIndex(note.id),
                        note: note,
                        isSelectionMode: isSelectionMode,
                        controller: controller,
                        onOpenNote: onOpenNote,
                        onSelectionToggle: onSelectionToggle,
                        onTogglePin: onTogglePin,
                        onDeleted: controller.showSingleDeleteSnackbar,
                        isSelected: controller.isNoteSelected(note.id),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    noteRepository.reorderUnpinnedNotes(oldIndex, newIndex);
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 70)),
          ],
        );
      },
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
