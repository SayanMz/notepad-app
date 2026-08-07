import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notepad/core/extensions/context_extensions.dart';

// Draggable color picker used by the custom text color flow.
class DraggablePickerState {
  final Offset offset;
  final bool isDragging;
  final bool isOverTarget;
  final double proximityProgress;
  final double scale;
  final double opacity;

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

class DraggableColorPicker extends StatefulWidget {
  final Color initialColor;
  final bool isDark;
  final Function(Color) onColorChanged;
  final VoidCallback onDismissRequested;

  const DraggableColorPicker({
    super.key,
    required this.initialColor,
    required this.isDark,
    required this.onColorChanged,
    required this.onDismissRequested,
  });

  @override
  State<DraggableColorPicker> createState() =>
      _DraggableToolbarColorPickerState();
}

class _DraggableToolbarColorPickerState extends State<DraggableColorPicker> {
  late Color pickerColor;

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
    final availableWidth = (screenSize.width * 0.4).clamp(260.0, 300.0);
    const double dHeight = 120;

    return ValueListenableBuilder<DraggablePickerState>(
      valueListenable: _pickerNotifier,
      builder: (context, state, pickerUI) {
        return Stack(
          children: [
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

            Positioned(
              left: (screenSize.width - availableWidth) / 2 + state.offset.dx,
              top: (screenSize.height - dHeight) / 2 + state.offset.dy,
              child: Opacity(
                opacity: state.opacity,
                child: Transform.scale(
                  scale: state.scale,
                  child: GestureDetector(
                    onPanStart: (_) {
                      _pickerNotifier.value = state.copyWith(isDragging: true);
                    },
                    onPanUpdate: (details) {
                      final currentState = _pickerNotifier.value;

                      double newX = currentState.offset.dx + details.delta.dx;
                      double newY = currentState.offset.dy + details.delta.dy;

                      final maxX = (screenSize.width - availableWidth) / 2;
                      final maxY = (screenSize.height - dHeight) / 2;

                      newX = newX.clamp(-maxX, maxX);
                      newY = newY.clamp(-maxY, maxY);

                      const targetX = 0.0;
                      final targetY = (screenSize.height / 2) - 110;
                      const hotZoneRadius = 100.0;

                      final distance = math.sqrt(
                        math.pow(newX - targetX, 2) +
                            math.pow(newY - targetY, 2),
                      );

                      final proximityProgress = (distance / 300).clamp(
                        0.0,
                        1.0,
                      );
                      bool isOver = distance < hotZoneRadius;

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
                        proximityProgress: proximityProgress,
                        scale: isOver ? proximityProgress.clamp(0.3, 1.0) : 1.0,
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
    final hsvColor = HSVColor.fromColor(pickerColor);

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
              const SizedBox(height: 16),

              SizedBox(
                height: 80,
                width: width - 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColorPickerArea(hsvColor, (color) {
                    setState(() => pickerColor = color.toColor());
                    widget.onColorChanged(color.toColor());
                  }, PaletteType.hsv),
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 18,
                width: width - 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColorPickerSlider(TrackType.hue, hsvColor, (color) {
                    setState(() => pickerColor = color.toColor());
                    widget.onColorChanged(color.toColor());
                  }, displayThumbColor: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
