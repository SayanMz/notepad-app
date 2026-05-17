import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SizeMenu extends StatelessWidget {
  const SizeMenu({super.key, required this.controller, required this.isDark});

  final QuillController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final List<double> standardSizes = [
      8,
      9,
      10,
      11,
      12,
      14,
      16,
      18,
      20,
      24,
      28,
      32,
      36,
      48,
      60,
      72,
    ];
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final style = controller.getSelectionStyle();
        final double currentSize =
            double.tryParse(
              style.attributes['size']?.value.toString() ?? '16',
            ) ??
            16.0;

        String headingLabel = 'H';
        if (currentSize == 32.0) {
          headingLabel = 'H1';
        } else if (currentSize == 28.0) {
          headingLabel = 'H2';
        } else if (currentSize == 24.0) {
          headingLabel = 'H3';
        } else if (currentSize == 20.0) {
          headingLabel = 'H4';
        }

        // Update this line in size_menu.dart
        return MenuAnchor(
          // FIX: -40 X-offset and -160 Y-offset to float consistently
          alignmentOffset: const Offset(0, -125),
          builder: (context, menuController, child) => IconButton(
            icon: Icon(
              Icons.text_fields,
              color: menuController.isOpen
                  ? Colors.blueAccent
                  : (isDark ? Colors.white : Colors.black54),
            ),
            onPressed: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
          ),
          // Note: Keep the innerMenu offsets (-55, -180 and -55, -250)
          // as they handle the sub-menus correctly.
          menuChildren: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120, maxHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. HEADINGS SECTION
                  Expanded(
                    child: MenuAnchor(
                      alignmentOffset: const Offset(
                        -55,
                        -200,
                      ), // Floats above the button
                      builder: (context, innerMenu, _) => TextButton(
                        onPressed: () => innerMenu.isOpen
                            ? innerMenu.close()
                            : innerMenu.open(),
                        child: Row(
                          children: [
                            Text(
                              headingLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_up, size: 18),
                          ],
                        ),
                      ),
                      menuChildren: [
                        _buildSizeItem(
                          'H1 (Title)',
                          32.0,
                          currentSize,
                          colorScheme,
                        ),
                        _buildSizeItem(
                          'H2 (Header)',
                          28.0,
                          currentSize,
                          colorScheme,
                        ),
                        _buildSizeItem(
                          'H3 (Sub)',
                          24.0,
                          currentSize,
                          colorScheme,
                        ),
                        _buildSizeItem(
                          'H4 (Small)',
                          20.0,
                          currentSize,
                          colorScheme,
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 20,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),

                  // 2. FONT SIZE SECTION
                  Expanded(
                    child: MenuAnchor(
                      alignmentOffset: const Offset(
                        -55,
                        -250,
                      ), // Floats above the button
                      builder: (context, innerMenu, _) => TextButton(
                        onPressed: () => innerMenu.isOpen
                            ? innerMenu.close()
                            : innerMenu.open(),
                        child: Row(
                          children: [
                            Text(
                              '${currentSize.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_up, size: 18),
                          ],
                        ),
                      ),
                      menuChildren: [
                        SizedBox(
                          height: 240,
                          child: SingleChildScrollView(
                            child: Column(
                              children: standardSizes
                                  .map(
                                    (size) => _buildSizeItem(
                                      '${size.toInt()}',
                                      size,
                                      currentSize,
                                      colorScheme,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSizeItem(
    String label,
    double size,
    double currentSize,
    ColorScheme colorScheme,
  ) {
    final bool isSelected = currentSize == size;
    return MenuItemButton(
      onPressed: () =>
          controller.formatSelection(Attribute.fromKeyValue('size', size)),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
