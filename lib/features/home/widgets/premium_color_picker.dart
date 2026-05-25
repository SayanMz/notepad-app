import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';

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
    final screenSize = context.screenSize;
    final availableWidth =
        (screenSize.width * EditorConstants.pickerWidthFactor).clamp(
          EditorConstants.pickerMinWidth,
          EditorConstants.pickerMaxWidth,
        );
    final maxHeight =
        screenSize.height * EditorConstants.pickerMaxHeightFactor;
    final displayColors = widget.recentColors.take(widget.maxColors).toList();
    final colorScheme = context.colorScheme;

    final surfaceColor = widget.isDark
        ? AppColors.darkDialogSurface
        : Colors.white;
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
          final double maxY =
              (screenSize.height - EditorConstants.pickerDialogHeight) / 2;

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
                borderRadius: BorderRadius.circular(
                  EditorConstants.pickerRadius,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: EditorConstants.pickerBlurSigma,
                    sigmaY: EditorConstants.pickerBlurSigma,
                  ),
                  child: Container(
                    width: availableWidth,
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    padding: const EdgeInsets.all(
                      EditorConstants.pickerPadding,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(
                        EditorConstants.pickerRadius,
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: EditorConstants.pickerBorderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: EditorConstants.pickerShadowAlpha,
                          ),
                          blurRadius: EditorConstants.pickerShadowBlur,
                          offset: const Offset(
                            0,
                            EditorConstants.pickerShadowOffsetY,
                          ),
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
                              width: EditorConstants.pickerHandleWidth,
                              height: EditorConstants.pickerHandleHeight,
                              margin: const EdgeInsets.only(
                                bottom: EditorConstants.pickerHandleBottomMargin,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(
                                  EditorConstants.pickerHandleRadius,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Color',
                            style: TextStyle(
                              fontSize: EditorConstants.pickerTitleFontSize,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              12.0,
                            ),
                            child: ColorPicker(
                              pickerColor: temporaryColor,
                              onColorChanged: (color) {
                                setState(() => temporaryColor = color);
                                widget.onPreviewChanged(color);
                              },
                              pickerAreaHeightPercent:
                                  EditorConstants.pickerAreaHeightPercent,
                              enableAlpha: false,
                              displayThumbColor: true,
                              labelTypes: const [],
                              portraitOnly: true,
                              colorPickerWidth:
                                  availableWidth -
                                  EditorConstants.pickerInternalWidthPadding,
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
                fontSize: EditorConstants.pickerRecentLabelFontSize,
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
                      color: AppColors.colorPickerApply,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: EditorConstants.pickerRecentGap),
        Wrap(
          spacing: EditorConstants.pickerRecentGap,
          runSpacing: EditorConstants.pickerRecentGap,
          children: displayColors
              .map(
                (color) => GestureDetector(
                  onTap: () {
                    setState(() => temporaryColor = color);
                    widget.onPreviewChanged(color);
                  },
                  child: Container(
                    width: EditorConstants.pickerSwatchSize,
                    height: EditorConstants.pickerSwatchSize,
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
