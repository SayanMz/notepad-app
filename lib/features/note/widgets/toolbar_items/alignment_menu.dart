import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class AlignmentMenu extends StatelessWidget {
  const AlignmentMenu({
    super.key,
    required this.controller,
    required this.isDark,
  });

  final QuillController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final currentAlign = controller
            .getSelectionStyle()
            .attributes[Attribute.align.key]
            ?.value;

        // Update this line in alignment_menu.dart
        return MenuAnchor(
          // FIX: Standardized to -40, -160 to match SizeMenu
          alignmentOffset: const Offset(15, -220),
          builder: (context, menuController, child) => IconButton(
            icon: const Icon(
              Icons.format_align_justify,
              color: Colors.blueAccent,
            ),
            onPressed: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
          ),
          menuChildren: [
            _buildItem(
              context,
              Icons.format_align_left,
              'left',
              'Left',
              currentAlign,
            ),
            _buildItem(
              context,
              Icons.format_align_center,
              'center',
              'Center',
              currentAlign,
            ),
            _buildItem(
              context,
              Icons.format_align_right,
              'right',
              'Right',
              currentAlign,
            ),
          ],
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    dynamic currentAlign,
  ) {
    final bool isSelected =
        (currentAlign == value) || (currentAlign == null && value == 'left');
    final activeColor = Theme.of(context).colorScheme.primary;
    final defaultColor = isDark ? Colors.white : Colors.black54;

    return MenuItemButton(
      leadingIcon: Icon(icon, color: isSelected ? activeColor : defaultColor),
      onPressed: () => controller.formatSelection(
        value == 'left'
            ? Attribute.leftAlignment
            : value == 'center'
            ? Attribute.centerAlignment
            : Attribute.rightAlignment,
      ),
      child: Text(label),
    );
  }
}
