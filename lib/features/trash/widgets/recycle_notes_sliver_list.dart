import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';
import 'package:notepad/features/trash/recycle_constants.dart';
import 'package:notepad/features/trash/widgets/swippeable_restore_item.dart';

// Sliver list keeps recycle-bin content lazy and scroll-friendly.
class RecycleNotesSliverList extends StatelessWidget {
  const RecycleNotesSliverList({
    required this.controller,
    required this.cardWidth,
    required this.onRestore,
    required this.onShowActionSheet,
    super.key,
  });

  final RecycleController controller;
  final double cardWidth;
  final void Function(NotesSection) onRestore;
  final void Function(BuildContext, NotesSection) onShowActionSheet;

  @override
  Widget build(BuildContext context) {
    final deletedNotes = controller.deletedNotes;

    return SliverPadding(
      padding: const EdgeInsets.all(RecycleConstants.listPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final note = deletedNotes[index];

          return SwipeableRestoreItem(
            key: ValueKey(note.id),
            cardWidth: cardWidth,
            note: note,
            onRestore: onRestore,
            onShowActionSheet: onShowActionSheet,
          );
        }, childCount: deletedNotes.length),
      ),
    );
  }
}
