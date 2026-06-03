import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';

class AlignmentMenu extends StatelessWidget {
  const AlignmentMenu({
    super.key,
    required this.controller,
    required this.isDark,
    required this.toolbarController,
    required this.menuController,
  });

  final QuillController controller;
  final NoteToolbarController toolbarController;
  final MenuController menuController;
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

        return ToolbarMenuWrapper(
          toolbarController: toolbarController,
          menuController: menuController,
          child: MenuAnchor(
            controller: menuController,
            alignmentOffset: const Offset(15, -220),
            builder: (context, controller, child) => IconButton(
              icon: const Icon(
                Icons.format_align_justify,
                color: Colors.blueAccent,
              ),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
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
          ),
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
    final activeColor = context.colorScheme.primary;
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
