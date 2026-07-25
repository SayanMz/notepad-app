import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
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

    return SliverMainAxisGroup(
      slivers: [
        // Text directly on the page surface above note items
        const SliverToBoxAdapter(child: _RecycleBinInfoText()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: RecycleConstants.listPadding,
            vertical: RecycleConstants.listPadding / 2,
          ),
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
        ),
      ],
    );
  }
}

/// Plain informational description rendered directly on the page surface.
class _RecycleBinInfoText extends StatelessWidget {
  const _RecycleBinInfoText();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RecycleConstants.listPadding,
        vertical: RecycleConstants.listPadding / 2,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: const BoxDecoration(
          color: Colors.transparent, // Completely invisible background
        ),
        child: Text(
          'Items in the Recycle Bin will be permanently deleted after 30 days.',
          style: TextStyle(
            fontSize: 13.0,
            height: 1.4,
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
