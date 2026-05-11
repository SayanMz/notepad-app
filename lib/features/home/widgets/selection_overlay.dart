import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/selection_toolbar.dart';

class SelectionOverlay extends StatelessWidget {
  final HomeController controller;
  final bool isSelectionMode;
  final bool isDark;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const SelectionOverlay({
    super.key,
    required this.controller,
    required this.isSelectionMode,
    required this.isDark,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: !isSelectionMode,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          offset: isSelectionMode ? Offset.zero : const Offset(0, 1.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isSelectionMode ? 1.0 : 0.0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 24.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: ListenableBuilder(
                          listenable: noteRepository,
                          builder: (context, _) {
                            return SelectionToolbar(
                              isDark: isDark,
                              allSelected: controller.isAllSelected,
                              onSelectAll: (val) =>
                                  controller.toggleSelectAll(val),
                              onShare: onShare,
                              onDelete: onDelete,
                              onColorChanged: (color) =>
                                  controller.updateSelectedColors(color),
                              onPin: () => controller.togglePinBulk(),
                              shouldPin: controller.showPinAction,
                              selectedCount: controller.selectedNotes.length,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
