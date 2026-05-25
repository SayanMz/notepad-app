import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';

class SizeMenu extends StatefulWidget {
  const SizeMenu({
    super.key,
    required this.controller,
    required this.isDark,
    required this.focusNode,
    required this.toolbarController,
  });

  final QuillController controller;
  final NoteToolbarController toolbarController;
  final bool isDark;
  final FocusNode focusNode;

  static const List<double> standardSizes = [
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

  // ⚡ Map sizes to their labels for easy lookup
  static final Map<double, String> headingLabels = {
    32.0: 'H1',
    28.0: 'H2',
    24.0: 'H3',
    20.0: 'H4',
  };

  @override
  State<SizeMenu> createState() => _SizeMenuState();
}

class _SizeMenuState extends State<SizeMenu> {
  // ⚡ Persistent storage for controllers
  late final MenuController _parentMenuController;
  late final MenuController _headingMenuController;
  late final MenuController _sizeMenuController;

  @override
  void initState() {
    super.initState();
    _parentMenuController = MenuController();
    _headingMenuController = MenuController();
    _sizeMenuController = MenuController();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final style = widget.controller.getSelectionStyle();
        final double currentSize =
            double.tryParse(
              style.attributes['size']?.value.toString() ?? '16',
            ) ??
            16.0;

        final String headingLabel = SizeMenu.headingLabels[currentSize] ?? 'H';

        return ToolbarMenuWrapper(
          toolbarController: widget.toolbarController,
          menuController: _parentMenuController,
          child: MenuAnchor(
            controller: _parentMenuController,
            alignmentOffset: const Offset(0, -125),
            builder: (context, controller, child) => IconButton(
              icon: Icon(
                Icons.text_fields,
                color: controller.isOpen
                    ? Colors.blueAccent
                    : (widget.isDark ? Colors.white : Colors.black54),
              ),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
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
                        controller: _headingMenuController,
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
                      color: widget.isDark ? Colors.white24 : Colors.black12,
                    ),

                    // 2. FONT SIZE SECTION
                    Expanded(
                      child: MenuAnchor(
                        controller: _sizeMenuController,
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
                                children: SizeMenu.standardSizes
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
          ),
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
      onPressed: () {
        widget.focusNode.requestFocus();
        widget.controller.formatSelection(Attribute.fromKeyValue('size', size));
      },
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
