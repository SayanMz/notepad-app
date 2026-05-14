import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Consolidated interaction state for the picker
class DraggablePickerState {
  final Offset offset;
  final bool isDragging;
  final bool isOverTarget;

  const DraggablePickerState({
    this.offset = Offset.zero,
    this.isDragging = false,
    this.isOverTarget = false,
  });

  DraggablePickerState copyWith({
    Offset? offset,
    bool? isDragging,
    bool? isOverTarget,
  }) {
    return DraggablePickerState(
      offset: offset ?? this.offset,
      isDragging: isDragging ?? this.isDragging,
      isOverTarget: isOverTarget ?? this.isOverTarget,
    );
  }
}

class DraggableToolbarColorPicker extends StatefulWidget {
  final Color initialColor;
  final bool isDark;
  final Function(Color) onColorChanged;
  final VoidCallback onDismissRequested;

  const DraggableToolbarColorPicker({
    super.key,
    required this.initialColor,
    required this.isDark,
    required this.onColorChanged,
    required this.onDismissRequested,
  });

  @override
  State<DraggableToolbarColorPicker> createState() =>
      _DraggableToolbarColorPickerState();
}

class _DraggableToolbarColorPickerState
    extends State<DraggableToolbarColorPicker> {
  late Color pickerColor;

  // Single notifier for all UI state changes
  final ValueNotifier<DraggablePickerState> _pickerNotifier = ValueNotifier(
    const DraggablePickerState(),
  );

  @override
  void initState() {
    super.initState();
    pickerColor = widget.initialColor;
  }

  @override
  void dispose() {
    _pickerNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // COMPACT FIX: Narrower width limits
    final availableWidth = (screenSize.width * 0.8).clamp(260.0, 300.0);
    // COMPACT FIX: Reduced base height estimate
    const double dHeight = 240;

    return ValueListenableBuilder<DraggablePickerState>(
      valueListenable: _pickerNotifier,
      builder: (context, state, pickerUI) {
        final offset = state.offset;

        // Target coordinates relative to screen center
        const targetX = 0.0;
        final targetY = (screenSize.height / 2) - 110;

        final distance = math.sqrt(
          math.pow(offset.dx - targetX, 2) + math.pow(offset.dy - targetY, 2),
        );

        // Visual feedback based on distance
        const hotZoneRadius = 100.0;
        final proximityProgress = (distance / 300).clamp(0.0, 1.0);

        return Stack(
          children: [
            // --- DYNAMIC DISMISS TARGET ---
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: state.isOverTarget ? 90 : 72,
                  height: state.isOverTarget ? 90 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isOverTarget
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : Colors.redAccent.withValues(alpha: 0.05),
                    boxShadow: state.isOverTarget
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                    border: Border.all(
                      color: state.isOverTarget
                          ? Colors.red
                          : Colors.redAccent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: state.isDragging ? 1.0 : 0.0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            // --- MAGNETIC DRAGGABLE PICKER ---
            Positioned(
              left: (screenSize.width - availableWidth) / 2 + offset.dx,
              top: (screenSize.height - dHeight) / 2 + offset.dy,
              child: Opacity(
                opacity: state.isDragging
                    ? proximityProgress.clamp(0.0, 1.0)
                    : 1.0,
                child: Transform.scale(
                  scale: state.isDragging
                      ? proximityProgress.clamp(0.3, 1.0)
                      : 1.0,
                  child: GestureDetector(
                    onPanStart: (_) {
                      _pickerNotifier.value = state.copyWith(isDragging: true);
                    },
                    onPanUpdate: (details) {
                      final currentState = _pickerNotifier.value;
                      double newX = currentState.offset.dx + details.delta.dx;
                      double newY = currentState.offset.dy + details.delta.dy;

                      final currentDistance = math.sqrt(
                        math.pow(newX - targetX, 2) +
                            math.pow(newY - targetY, 2),
                      );

                      bool isOver = currentDistance < hotZoneRadius;

                      if (isOver != currentState.isOverTarget) {
                        if (isOver) HapticFeedback.lightImpact();
                      }

                      if (isOver) {
                        newX = lerpDouble(newX, targetX, 0.2)!;
                        newY = lerpDouble(newY, targetY, 0.2)!;
                      }

                      _pickerNotifier.value = currentState.copyWith(
                        offset: Offset(newX, newY),
                        isOverTarget: isOver,
                      );
                    },
                    onPanEnd: (_) {
                      final currentState = _pickerNotifier.value;
                      if (currentState.isOverTarget) {
                        HapticFeedback.heavyImpact();
                        widget.onDismissRequested();
                      }
                      _pickerNotifier.value = currentState.copyWith(
                        isDragging: false,
                        isOverTarget: false,
                      );
                    },
                    child: pickerUI!,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: RepaintBoundary(child: _buildExpensiveUI(availableWidth)),
    );
  }

  Widget _buildExpensiveUI(double width) {
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: width,
            // COMPACT FIX: Tighter internal padding
            padding: const EdgeInsets.only(
              top: 12.0,
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF1E1E1E).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C9C8D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // COMPACT FIX: Reduced spacer height
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) {
                      setState(() => pickerColor = color);
                      widget.onColorChanged(color);
                    },
                    // COMPACT FIX: Lowered percentage to flatten the wheel slightly
                    pickerAreaHeightPercent: 0.35,
                    enableAlpha: false,
                    displayThumbColor: true,
                    labelTypes: const [],
                    portraitOnly: true,
                    // COMPACT FIX: Account for the 16px horizontal padding on both sides
                    colorPickerWidth: width - 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
