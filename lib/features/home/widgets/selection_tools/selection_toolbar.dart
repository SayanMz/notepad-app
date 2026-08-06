import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/selection_tools/premium_color_picker.dart';

// Selection toolbar for bulk actions such as pinning, sharing, and color changes.
class SelectionToolbar extends StatefulWidget {
  const SelectionToolbar({super.key, required this.controller});
  final HomeController controller;

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar>
    with SingleTickerProviderStateMixin {
  ColorScheme get colorScheme => context.colorScheme;

  late AnimationController _rotationController;
  final ValueNotifier<Offset> dialogOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  final ValueNotifier<int> colorRevision = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: AnimationConstants.colorWheelSpin,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    dialogOffsetNotifier.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = context.isDark
        ? AppColors.toolbarInactiveIconDark
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.8);

    final homeController = widget.controller;
    final selectionCtrl = widget.controller.selectionController;

    return Container(
      height: EditorConstants.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: EditorConstants.toolbarCheckboxWidth,
            child: Checkbox(
              side: BorderSide(
                color: iconColor,
                width: EditorConstants.toolbarBorderWidth,
              ),
              value: selectionCtrl.areAllSelected(homeController.activeNotes),
              onChanged: (value) => homeController.toggleSelectAll(value),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  EditorConstants.toolbarCheckboxRadius,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Select All',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: EditorConstants.toolbarLabelFontSize,
              color: iconColor,
            ),
          ),
          const SizedBox(width: EditorConstants.toolbarCountGap),
          Text(
            '${selectionCtrl.selectionCount}',
            style: TextStyle(fontWeight: FontWeight.bold, color: iconColor),
          ),
          const Spacer(),
          _buildColorCircle(),
          IconButton(
            icon: Icon(
              homeController.showPinAction
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              size: EditorConstants.toolbarIconSize,
              color: iconColor,
            ),
            onPressed: () => homeController.togglePinBulk(),
            splashRadius: EditorConstants.toolbarSplashRadius,
          ),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              size: EditorConstants.toolbarIconSize,
              color: iconColor,
            ),
            onPressed: () => homeController.shareSelectedNotes(
              onError: (errorMessage) {
                if (!mounted) return;

                showErrorSnackBar(
                  'Could not share selected notes: $errorMessage',
                );
              },
            ),
            splashRadius: EditorConstants.toolbarSplashRadius,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: EditorConstants.toolbarIconSize,
              color: iconColor,
            ),
            onPressed: () => homeController.executeBulkDelete(),
            splashRadius: EditorConstants.toolbarSplashRadius,
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle() {
    return GestureDetector(
      onTap: () => _openPremiumColorPicker(),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: EditorConstants.toolbarColorCircleMargin,
        ),
        width: EditorConstants.toolbarColorCircleSize,
        height: EditorConstants.toolbarColorCircleSize,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.toolbarShadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SweepGradientPainter(_rotationController.value),
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openPremiumColorPicker() async {
    _rotationController.stop();

    final originalColors = widget.controller.getSelectedColorsSnapshot();
    final screenSize = context.screenSize;
    final maxColors =
        screenSize.width > EditorConstants.pickerRecentDesktopBreakpoint
        ? EditorConstants.pickerRecentDesktopCount
        : EditorConstants.pickerRecentPhoneCount;

    final recentColors = appSettingsRepository.settings.recentColorValues
        .map((val) => Color(val))
        .toList();

    final Color? resultColor = await showGeneralDialog<Color>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Color Picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PremiumColorPicker(
          initialColor: recentColors[0],
          recentColors: recentColors.take(maxColors).toList(),
          dialogOffsetNotifier: dialogOffsetNotifier,
          onPreviewChanged: (color) =>
              widget.controller.updateSelectedColors(color),
        );
      },
    );

    if (resultColor != null) {
      appSettingsRepository.addRecentColor(resultColor, maxColors);
      widget.controller.saveColors();
    } else {
      widget.controller.restoreColors(originalColors);
    }
    _rotationController.repeat();
  }
}

class SweepGradientPainter extends CustomPainter {
  SweepGradientPainter(this.rotationValue);

  final double rotationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(rotationValue * 2 * math.pi),
        colors: const [
          Color(0xFFFFF59D),
          Color(0xFFFFCC80),
          Color(0xFFEF9A9A),
          Color(0xFFCE93D8),
          Color(0xFF90CAF9),
          Color(0xFFA5D6A7),
          Color(0xFFE0E0E0),
        ],
      ).createShader(rect);

    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant SweepGradientPainter oldDelegate) {
    return oldDelegate.rotationValue != rotationValue;
  }
}
