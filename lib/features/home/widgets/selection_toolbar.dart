import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/data/notes_repository.dart';

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
    final iconColor = isDark ? Colors.white : colorScheme.onSurfaceVariant;

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
    _rotationController.stop(); //[cite: 12]
    Color temporaryColor = recentColors.isEmpty
        ? Colors.red
        : recentColors[0]; //[cite: 12] //[cite: 12]
    final Map<String, Color> originalColors = {
      for (var note in noteRepository.selectedNotes) note.id: note.cardColor,
    };
    final colorScheme = Theme.of(context).colorScheme;

    final screenSize = MediaQuery.of(context).size; //[cite: 12]
    final maxColors = screenSize.width > 600 ? 8 : 6; //[cite: 12]

    final bool? applied = await showDialog(
      context: context,
      barrierColor: Colors.transparent, //[cite: 12]
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Optimized width for mobile ergonomics
          final availableWidth = (screenSize.width * 0.85).clamp(
            280.0,
            360.0,
          ); //[cite: 12]
          final maxHeight = screenSize.height * 0.85; //[cite: 12]
          final displayColors = recentColors
              .take(maxColors)
              .toList(); //[cite: 12]

          final surfaceColor = isDark
              ? const Color(0xFF1E1E1E) // Premium solid dark surface
              : Colors.white;
          final borderColor = isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05);

          return ValueListenableBuilder<Offset>(
            valueListenable: dialogOffsetNotifier, //[cite: 12]
            builder: (context, offset, child) {
              return Transform.translate(
                offset: offset,
                child: child,
              ); //[cite: 12]
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                final screenSize = MediaQuery.of(context).size;
                final double dWidth = (screenSize.width * 0.85).clamp(
                  280.0,
                  360.0,
                );
                const double dHeight = 350;

                double newX = dialogOffsetNotifier.value.dx + details.delta.dx;
                double newY = dialogOffsetNotifier.value.dy + details.delta.dy;

                final double maxX = (screenSize.width - dWidth) / 2;
                final double maxY = (screenSize.height - dHeight) / 2;

                dialogOffsetNotifier.value = Offset(
                  newX.clamp(-maxX, maxX),
                  newY.clamp(-maxY, maxY),
                );
              }, //[cite: 12]
              child: Align(
                alignment: Alignment.center,
                child: Material(
                  type: MaterialType.transparency, //[cite: 12]
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 12,
                        sigmaY: 12,
                      ), //[cite: 12]
                      child: Container(
                        width: availableWidth,
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(
                            24.0,
                          ), //[cite: 12]
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
                              // --- THE DRAG HANDLE ---
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
                              // 1. CLEAN HEADER
                              Text(
                                'Color',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF111111),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 2. SQUASHED COLOR PICKER (Widescreen feel)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ColorPicker(
                                  pickerColor: temporaryColor,
                                  onColorChanged: (color) {
                                    setDialogState(
                                      () => temporaryColor = color,
                                    );
                                    noteRepository.updateColorPreview(color);
                                  },
                                  pickerAreaHeightPercent:
                                      0.25, // Compact height
                                  enableAlpha: false,
                                  displayThumbColor: true,
                                  labelTypes: const [],
                                  portraitOnly: true,
                                  colorPickerWidth: availableWidth - 40,
                                ),
                              ),

                              //const SizedBox(height: 16),

                              // 3. THE "SMART ROW" (Title + Actions on one line)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Recent",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),

                                  // Inline Text Buttons with Compact Visual Density
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity
                                              .compact, // Squeezes default margins
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          foregroundColor: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          foregroundColor: const Color(
                                            0xFF2C9C8D,
                                          ), // Your brand green
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Apply',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // 4. RECENT COLORS WRAP
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: displayColors
                                    .map(
                                      (color) => GestureDetector(
                                        onTap: () {
                                          setDialogState(
                                            () => temporaryColor = color,
                                          );
                                          widget.onColorChanged(color);
                                        },
                                        onDoubleTap: () {
                                          widget.onColorChanged(color);
                                          Navigator.pop(context, true);
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white24
                                                  : Colors.black12,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // 3. LOGIC HANDLER: Keeps your existing persistence and revert logic[cite: 12]
    if (applied == true) {
      appSettingsRepository.addRecentColor(
        temporaryColor,
        maxColors,
      ); //[cite: 12]
      noteRepository.saveSelectedColors(); //[cite: 12]
      setState(() {
        recentColors.remove(temporaryColor); //[cite: 12]
        recentColors.insert(0, temporaryColor); //[cite: 12]
        if (recentColors.length > maxColors) {
          recentColors.removeLast(); //[cite: 12]
        }
      });
    } else {
      noteRepository.restoreColors(originalColors); //[cite: 12]
    }

    _rotationController.repeat(); //[cite: 12]
  }
}
