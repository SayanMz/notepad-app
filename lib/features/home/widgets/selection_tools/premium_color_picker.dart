import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';

// Draggable color picker dialog for previewing and applying note colors.
class PremiumColorPicker extends StatefulWidget {
  final Color initialColor;
  final List<Color> recentColors;
  final Function(Color) onPreviewChanged;
  final ValueNotifier<Offset> dialogOffsetNotifier;

  const PremiumColorPicker({
    super.key,
    required this.initialColor,
    required this.recentColors,
    required this.onPreviewChanged,
    required this.dialogOffsetNotifier,
  });

  @override
  State<PremiumColorPicker> createState() => _PremiumColorPickerState();
}

class _PremiumColorPickerState extends State<PremiumColorPicker> {
  late Color temporaryColor;

  @override
  void initState() {
    super.initState();
    temporaryColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = context.screenSize;
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    final availableWidth =
        (screenSize.width * EditorConstants.pickerWidthFactor).clamp(
          EditorConstants.pickerMinWidth,
          EditorConstants.pickerMaxWidth,
        );
    final contentWidth =
        availableWidth - EditorConstants.pickerInternalWidthPadding;
    final maxHeight = screenSize.height * EditorConstants.pickerMaxHeightFactor;

    final baseSurface = isDark ? AppColors.darkDialogSurface : AppColors.pickerSurfaceLight;
    final gradientTop = baseSurface.withValues(alpha: isDark ? 0.35 : 0.92);
    final gradientBottom = baseSurface.withValues(alpha: isDark ? 0.70 : 0.55);

    final borderColor = isDark
        ? AppColors.pickerBorderDark.withValues(alpha: 0.15)
        : AppColors.pickerBorderLight.withValues(alpha: 0.08);

    return ValueListenableBuilder<Offset>(
      valueListenable: widget.dialogOffsetNotifier,
      builder: (context, offset, child) {
        return Transform.translate(offset: offset, child: child!);
      },
      child: GestureDetector(
        onPanUpdate: (details) {
          double newX = widget.dialogOffsetNotifier.value.dx + details.delta.dx;
          double newY = widget.dialogOffsetNotifier.value.dy + details.delta.dy;
          final double maxX = (screenSize.width - availableWidth) / 2;
          final double maxY =
              (screenSize.height - EditorConstants.pickerDialogHeight) / 2;

          widget.dialogOffsetNotifier.value = Offset(
            newX.clamp(-maxX, maxX),
            newY.clamp(-maxY, maxY),
          );
        },
        child: Align(
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: availableWidth,
              constraints: BoxConstraints(maxHeight: maxHeight),
              padding: const EdgeInsets.all(EditorConstants.pickerPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  EditorConstants.pickerRadius,
                ),
                border: Border.all(
                  color: borderColor,
                  width: EditorConstants.pickerBorderWidth,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientTop, gradientBottom],
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
                          color: colorScheme.primary.withValues(alpha: 0.5),
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
                        color: isDark ? AppColors.pickerTitleDark : AppColors.pickerTitleLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RepaintBoundary(
                      child: ColorPicker(
                        pickerColor: temporaryColor,
                        onColorChanged: (color) {
                          setState(() => temporaryColor = color);
                          widget.onPreviewChanged(color);
                        },
                        pickerAreaBorderRadius: const BorderRadius.all(
                          Radius.circular(16.0),
                        ),
                        pickerAreaHeightPercent:
                            EditorConstants.pickerAreaHeightPercent,
                        enableAlpha: false,
                        displayThumbColor: true,
                        labelTypes: const [],
                        portraitOnly: true,
                        colorPickerWidth: contentWidth,
                      ),
                    ),
                    _buildActionRow(widget.recentColors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(List<Color> recentColors) {
    final isDark = context.isDark;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: TextStyle(
                fontSize: EditorConstants.pickerRecentLabelFontSize,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.pickerRecentDark : AppColors.pickerRecentLight,
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
          children: recentColors
              .map(
                (color) => GestureDetector(
                  onTap: () {
                    setState(() {
                      temporaryColor = color;
                      widget.onPreviewChanged(color);
                      HapticFeedback.selectionClick();
                    });
                  },
                  child: Container(
                    width: EditorConstants.pickerSwatchSize,
                    height: EditorConstants.pickerSwatchSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.pickerSwatchBorderDark
                            : AppColors.pickerSwatchBorderLight,
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
