import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/premium_color_picker.dart';

class SelectionToolbar extends StatefulWidget {
  const SelectionToolbar({
    super.key,
    required this.isDark,
    required this.allSelected,
    required this.onSelectAll,
    required this.selectedCount,
    required this.onPin,
    required this.shouldPin,
    required this.onShare,
    required this.onDelete,
    required this.onColorChanged,
    required this.controller,
  });

  final bool isDark;
  final bool shouldPin;
  final bool allSelected;
  final int selectedCount;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onShare;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final Function(Color) onColorChanged;
  final HomeController controller;

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  List<Color> recentColors = [];

  late AnimationController _rotationController;

  final ValueNotifier<Offset> dialogOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final savedvalues = appSettingsRepository.settings.recentColorValues;

    recentColors = savedvalues.map((val) => Color(val)).toList();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dialogOffsetNotifier.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Small delay to ensure MediaQuery has updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureDialogIsVisible();
    });
  }

  void _ensureDialogIsVisible() {
    // We need to access the latest screen size
    final screenSize = MediaQuery.of(context).size;

    // These should match the math used in your onPanUpdate
    final double dWidth = (screenSize.width * 0.85).clamp(280.0, 360.0);
    const double dHeight = 350;

    final double maxX = (screenSize.width - dWidth) / 2;
    final double maxY = (screenSize.height - dHeight) / 2;

    // Clamp the existing offset to the new screen boundaries
    final double clampedX = dialogOffsetNotifier.value.dx.clamp(-maxX, maxX);
    final double clampedY = dialogOffsetNotifier.value.dy.clamp(-maxY, maxY);

    dialogOffsetNotifier.value = Offset(clampedX, clampedY);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark
        ? Colors.white
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.8);

    return Container(
      height: 56.0, // Enforce a strict, sleek height[cite: 12]
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
      ), // Align with note cards[cite: 12]
      child: Row(
        children: [
          // Constrain checkbox size to prevent it from pushing margins
          SizedBox(
            width: 32,
            child: Checkbox(
              side: BorderSide(
                color: iconColor,
                width: 1.5, // Thinner border[cite: 12]
              ),
              value: widget.allSelected,
              onChanged: (value) => widget.onSelectAll(value ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  4,
                ), // Subtle rounding[cite: 12]
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Select All',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15, // Slightly smaller, crisper font
              color: iconColor,
            ),
          ),
          SizedBox(width: 10),
          Text(
            '${widget.selectedCount}', // Use the passed count here
            style: TextStyle(fontWeight: FontWeight.bold, color: iconColor),
          ),
          const Spacer(),
          _buildColorCircle(),
          IconButton(
            // Use outlined icons for a lighter visual footprint[cite: 12]
            icon: Icon(
              widget.shouldPin
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,

              size: 22,
              color: iconColor,
            ),
            onPressed: widget.onPin,
            splashRadius: 20,
          ),
          IconButton(
            // Use outlined icons for a lighter visual footprint[cite: 12]
            icon: Icon(Icons.share_outlined, size: 22, color: iconColor),
            onPressed: widget.onShare,
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 22, color: iconColor),
            onPressed: widget.onDelete,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle() {
    return GestureDetector(
      onTap: () => _openPremiumColorPicker(),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: UIConstants.toolbarColorCircleMargin,
              ),
              width: UIConstants.iconMD,
              height: UIConstants.iconMD,
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  transform: GradientRotation(
                    _rotationController.value * 2 * math.pi,
                  ),
                  colors: const [
                    Color(0xFFFFF59D),
                    Color(0xFFFFCC80),
                    Color(0xFFEF9A9A),
                    Color(0xFFCE93D8),
                    Color(0xFF90CAF9),
                    Color(0xFFA5D6A7),
                    Color(0xFFE0E0E0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                shape: BoxShape.circle,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openPremiumColorPicker() async {
    _rotationController.stop();
    final originalColors = {
      for (final note in widget.controller.selectedNotes)
        note.id: note.cardColor,
    };

    final screenSize = MediaQuery.of(context).size;
    final maxColors = screenSize.width > 600 ? 8 : 6;
    final Color initialColor = recentColors.isEmpty
        ? Colors.red
        : recentColors[0];

    final Color? resultColor = await showDialog<Color>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => PremiumColorPicker(
        initialColor: initialColor,
        recentColors: recentColors,
        isDark: isDark,
        maxColors: maxColors,
        onPreviewChanged: (color) =>
            widget.controller.updateSelectedColors(color),
      ),
    );

    if (resultColor != null) {
      appSettingsRepository.addRecentColor(resultColor, maxColors);
      widget.controller.saveColors;
      setState(() {
        recentColors.remove(resultColor);
        recentColors.insert(0, resultColor);
        if (recentColors.length > maxColors) recentColors.removeLast();
      });
    } else {
      widget.controller.restoreColors(originalColors);
    }

    _rotationController.repeat();
  }
}
