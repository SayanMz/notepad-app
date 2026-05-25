import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notepad/core/services/context_extensions.dart';

/// Consolidated interaction state for the picker
class DraggablePickerState {
  final Offset offset;
  final bool isDragging;
  final bool isOverTarget;
  final double proximityProgress; // Pre-calculated for build performance
  final double scale; // Calculated in PanUpdate
  final double opacity; // Calculated in PanUpdate

  const DraggablePickerState({
    this.offset = Offset.zero,
    this.isDragging = false,
    this.isOverTarget = false,
    this.proximityProgress = 1.0,
    this.scale = 1.0,
    this.opacity = 1.0,
  });

  DraggablePickerState copyWith({
    Offset? offset,
    bool? isDragging,
    bool? isOverTarget,
    double? proximityProgress,
    double? scale,
    double? opacity,
  }) {
    return DraggablePickerState(
      offset: offset ?? this.offset,
      isDragging: isDragging ?? this.isDragging,
      isOverTarget: isOverTarget ?? this.isOverTarget,
      proximityProgress: proximityProgress ?? this.proximityProgress,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
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
    final screenSize = context.screenSize;
    final availableWidth = (screenSize.width * 0.8).clamp(260.0, 300.0);
    const double dHeight = 240;
    bool isClosing = false;

    // OPTIMIZATION: Logic moved to PanUpdate. Build only reads values.
    return ValueListenableBuilder<DraggablePickerState>(
      valueListenable: _pickerNotifier,
      builder: (context, state, pickerUI) {
        return IgnorePointer(
          ignoring: isClosing,
          child: Stack(
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
                left: (screenSize.width - availableWidth) / 2 + state.offset.dx,
                top: (screenSize.height - dHeight) / 2 + state.offset.dy,
                child: Opacity(
                  opacity: state.opacity,
                  child: Transform.scale(
                    scale: state.scale,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _pickerNotifier.value = state.copyWith(
                          isDragging: true,
                        );
                      },
                      onPanUpdate: (details) {
                        setState(() => isClosing = true);
                        final currentState = _pickerNotifier.value;

                        // 1. Calculate raw movement
                        double newX = currentState.offset.dx + details.delta.dx;
                        double newY = currentState.offset.dy + details.delta.dy;

                        // This calculates how far the widget is allowed to move from the center
                        final maxX = (screenSize.width - availableWidth) / 2;
                        final maxY = (screenSize.height - dHeight) / 2;

                        newX = newX.clamp(-maxX, maxX);
                        newY = newY.clamp(-maxY, maxY);

                        // 2. Perform math once per update in the callback
                        const targetX = 0.0;
                        final targetY = (screenSize.height / 2) - 110;
                        const hotZoneRadius = 100.0;

                        final distance = math.sqrt(
                          math.pow(newX - targetX, 2) +
                              math.pow(newY - targetY, 2),
                        );

                        // 3. Proximity & Visuals logic
                        final proximityProgress = (distance / 300).clamp(
                          0.0,
                          1.0,
                        );
                        bool isOver = distance < hotZoneRadius;

                        if (isOver != currentState.isOverTarget) {
                          if (isOver) HapticFeedback.lightImpact();
                        }

                        // Magnetic effect
                        if (isOver) {
                          newX = lerpDouble(newX, targetX, 0.2)!;
                          newY = lerpDouble(newY, targetY, 0.2)!;
                        }

                        // 4. Batch update values to prevent build thrashing
                        _pickerNotifier.value = currentState.copyWith(
                          offset: Offset(newX, newY),
                          isOverTarget: isOver,
                          proximityProgress: proximityProgress,
                          scale: isOver
                              ? proximityProgress.clamp(0.3, 1.0)
                              : 1.0,
                          opacity: isOver
                              ? proximityProgress.clamp(0.0, 1.0)
                              : 1.0,
                        );
                      },
                      onPanEnd: (_) {
                        final currentState = _pickerNotifier.value;
                        if (currentState.isOverTarget) {
                          HapticFeedback.heavyImpact();
                          widget.onDismissRequested();
                          return;
                        }
                        _pickerNotifier.value = currentState.copyWith(
                          isDragging: false,
                          isOverTarget: false,
                          offset: currentState.offset,
                          scale: 1.0,
                          opacity: 1.0,
                        );
                      },
                      // OPTIMIZATION: Child is pre-built and wrapped in RepaintBoundary
                      child: pickerUI!,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) {
                      setState(() => pickerColor = color);
                      widget.onColorChanged(color);
                    },
                    pickerAreaHeightPercent: 0.35,
                    enableAlpha: false,
                    displayThumbColor: true,
                    labelTypes: const [],
                    portraitOnly: true,
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
