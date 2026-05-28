import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/services/note_preview_util.dart';
import 'package:notepad/core/services/note_timestamp_formatter.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.index,
    required this.note,
    required this.isSelectionMode,
    required this.isVaporizing,
    required this.onTap,
    required this.onLongPress,
    required this.onPin,
    required this.isSelected,
    required this.colorNotifier,
    required this.maxPreviewLines,
    required this.selectionMode,
  });

  final int index;
  final NotesSection note;
  final bool isSelectionMode;
  final bool isVaporizing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPin;
  final bool isSelected;
  final bool selectionMode;
  final ValueNotifier<int> colorNotifier;
  final int maxPreviewLines;

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenSize.width; //

    // 🌟 STEP 1: Pass a high ceiling limit to pull the full un-truncated cache stream!
    // This gives the card access to all 12 cached lines so checklists aren't cut short.
    final List<PreviewLine> cachedLines = note.getPreview(12);

    // 🌟 STEP 2: Extract text items and safely clip them to respect maxPreviewLines
    final regularTextWidgets = cachedLines
        .where((line) => !line.isList)
        .take(
          maxPreviewLines,
        ) // Enforces your responsive layout ceiling strictly on text!
        .map((line) => _PreviewLine(line: line.text, width: screenWidth)); //

    // 🌟 STEP 3: Extract ALL available checklist items from the cache group (up to 6)
    final checklistItems = cachedLines
        .where((line) => line.isList)
        .map((line) => line.text)
        .take(maxPreviewLines)
        .toList(); //

    // Combine them safely: text paragraphs on top, full scrollable checklists on the bottom
    final List<Widget> finalCardLayoutWidgets = [
      // 🌟 THE FIX: Wrap your regular text blocks in a Flexible layout block.
      // This forces the text paragraphs to truncate with ellipsis (...) when content gets large,
      // instead of aggressively expanding and crushing your checklist row off-screen!
      if (regularTextWidgets.isNotEmpty)
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [...regularTextWidgets],
          ),
        ),

      // Ensure there is always a tiny spacing buffer above your scrollable checklist tag row
      if (checklistItems.isNotEmpty)
        const SizedBox(height: UIConstants.paddingXS),

      if (checklistItems.isNotEmpty)
        _ChecklistPreviewGroup(
          items: checklistItems,
          selectionMode: selectionMode, //
        ),
    ];

    final bool showAsSelected = isSelectionMode && isSelected; //
    return AnimatedScale(
      scale: isVaporizing ? 0.0 : (showAsSelected ? 0.96 : 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInBack,
      child: AnimatedOpacity(
        opacity: isVaporizing ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: UIConstants.animationMedium,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: UIConstants.paddingXXS),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UIConstants.radiusMD),
            boxShadow: showAsSelected
                ? [
                    BoxShadow(
                      color: context.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
            border: Border.all(
              color: showAsSelected
                  ? context.colorScheme.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: UIConstants.selectionBorderWidth,
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: showAsSelected ? 0 : UIConstants.elevationLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusMD),
              side: showAsSelected
                  ? BorderSide(
                      color: context.colorScheme.primary.withValues(alpha: 0.6),
                      width: UIConstants.selectionBorderWidth,
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(UIConstants.paddingLG),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: ListenableBuilder(
                        listenable: colorNotifier,
                        builder: (context, child) {
                          return AnimatedContainer(
                            duration: UIConstants.animationMedium,
                            decoration: BoxDecoration(
                              color: !context.isDark
                                  ? note.cardColor
                                  : note.cardColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: UIConstants.animationMedium,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: isSelectionMode
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          right: UIConstants.paddingMD,
                                        ),
                                        child: Icon(
                                          showAsSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: showAsSelected
                                              ? context.colorScheme.primary
                                                    .withValues(alpha: 0.6)
                                              : Colors.grey,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              AnimatedPadding(
                                duration: UIConstants.animationMedium,
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.only(
                                  left: isSelectionMode
                                      ? 0.0
                                      : 4.0, // Soft organic shift offset
                                ),
                                child: Text(
                                  note.displayTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: UIConstants.noteCardTitleFontSize,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (note.isPinned)
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      style: const ButtonStyle(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(
                                        Icons.push_pin,
                                        size: UIConstants.iconSM,
                                        color: note.isPinned
                                            ? context.colorScheme.primary
                                                  .withValues(alpha: 0.8)
                                            : Colors.grey.withValues(
                                                alpha: 0.4,
                                              ),
                                      ),
                                      onPressed: isSelectionMode ? null : onPin,
                                    ),
                                  if (!isSelectionMode) ...[
                                    const SizedBox(width: 12),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.grey.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: UIConstants.iconMD,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Edited: ${note.updatedAt.format(showYear: false)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: UIConstants.noteCardEditedFontSize,
                            ),
                          ),
                          const SizedBox(height: UIConstants.paddingSM),
                          ...finalCardLayoutWidgets,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistPreviewGroup extends StatelessWidget {
  final List<String> items;
  final bool selectionMode;
  const _ChecklistPreviewGroup({
    required this.items,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UIConstants.paddingXS),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          return true;
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: selectionMode
              ? NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),

          child: Row(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: context.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.isDark
                                  ? Colors.white70
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.line, required this.width});
  final String line;
  final double width;

  @override
  Widget build(BuildContext context) {
    final displayText = line.trim();
    if (displayText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: UIConstants.paddingXS),
      child: Text(
        displayText,
        maxLines: width > 1200 ? 12 : (width > 600 ? 2 : 1),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: UIConstants.noteCardPreviewFontSize,
          height: width > 1200 ? 1.3 : 1.5,
        ),
      ),
    );
  }
}
