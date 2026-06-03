// Sliver list keeps recycle-bin content lazy and scroll-friendly.
import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/trash/controller/recycle_controller.dart';
import 'package:notepad/features/trash/recycle_constants.dart';
import 'package:notepad/features/trash/widgets/swippeable_restore_item.dart';

// Sliver list wrapper keeps recycle bin rendering lazy and scroll-friendly.
class RecycleNotesSliverList extends StatelessWidget {
  const RecycleNotesSliverList({
    required this.isDark,
    required this.cardWidth,
    required this.onRestore,
    required this.onShowActionSheet,
    required this.controller,
    super.key,
  });
  final bool isDark;
  final double cardWidth;
  final void Function(NotesSection) onRestore;
  final void Function(BuildContext, NotesSection) onShowActionSheet;
  final RecycleController controller;

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
            note: note,
            isDark: isDark,
            onShowActionSheet: onShowActionSheet,
            onRestore: onRestore,
            cardWidth: cardWidth,
          );
        }, childCount: deletedNotes.length),
      ),
    );
  }
}
