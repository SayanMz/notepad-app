import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PremiumColorPicker extends StatefulWidget {
  final Color initialColor;
  final List<Color> recentColors;
  final bool isDark;
  final int maxColors;
  final Function(Color) onPreviewChanged;

  const PremiumColorPicker({
    super.key,
    required this.initialColor,
    required this.recentColors,
    required this.isDark,
    required this.maxColors,
    required this.onPreviewChanged,
  });

  @override
  State<PremiumColorPicker> createState() => _PremiumColorPickerState();
}

class _PremiumColorPickerState extends State<PremiumColorPicker> {
  late Color temporaryColor;
  final ValueNotifier<Offset> dialogOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  @override
  void initState() {
    super.initState();
    temporaryColor = widget.initialColor;
  }

  @override
  void dispose() {
    dialogOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = (screenSize.width * 0.85).clamp(280.0, 360.0);
    final maxHeight = screenSize.height * 0.85;
    final displayColors = widget.recentColors.take(widget.maxColors).toList();
    final colorScheme = Theme.of(context).colorScheme;

    final surfaceColor = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return ValueListenableBuilder<Offset>(
      valueListenable: dialogOffsetNotifier,
      builder: (context, offset, child) {
        return Transform.translate(offset: offset, child: child!);
      },
      child: GestureDetector(
        onPanUpdate: (details) {
          double newX = dialogOffsetNotifier.value.dx + details.delta.dx;
          double newY = dialogOffsetNotifier.value.dy + details.delta.dy;
          final double maxX = (screenSize.width - availableWidth) / 2;
          final double maxY = (screenSize.height - 350) / 2;

          dialogOffsetNotifier.value = Offset(
            newX.clamp(-maxX, maxX),
            newY.clamp(-maxY, maxY),
          );
        },
        child: Align(
          alignment: Alignment.center,
          child: RepaintBoundary(
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: availableWidth,
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            'Color',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ColorPicker(
                              pickerColor: temporaryColor,
                              onColorChanged: (color) {
                                setState(() => temporaryColor = color);
                                widget.onPreviewChanged(color);
                              },
                              pickerAreaHeightPercent: 0.25,
                              enableAlpha: false,
                              displayThumbColor: true,
                              labelTypes: const [],
                              portraitOnly: true,
                              colorPickerWidth: availableWidth - 40,
                            ),
                          ),
                          _buildActionRow(displayColors),
                        ],
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

  Widget _buildActionRow(List<Color> displayColors) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, temporaryColor),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C9C8D),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: displayColors
              .map(
                (color) => GestureDetector(
                  onTap: () {
                    setState(() => temporaryColor = color);
                    widget.onPreviewChanged(color);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
