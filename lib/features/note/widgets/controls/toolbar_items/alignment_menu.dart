import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';

// Paragraph alignment menu for left, center, and right formatting.
class AlignmentMenu extends StatelessWidget {
  const AlignmentMenu({
    super.key,
    required this.controller,
    required this.toolbarController,
    required this.menuController,
    required this.selectionStyle,
  });

  final QuillController controller;
  final NoteToolbarController toolbarController;
  final MenuController menuController;
  final Style selectionStyle;

  @override
  Widget build(BuildContext context) {
    final currentAlign = selectionStyle.attributes[Attribute.align.key]?.value;

    return ToolbarMenuWrapper(
      toolbarController: toolbarController,
      menuController: menuController,
      child: MenuAnchor(
        controller: menuController,
        alignmentOffset: const Offset(15, -220),
        builder: (context, controller, child) => IconButton(
          icon: const Icon(
            Icons.format_align_justify,
            color: AppColors.toolbarActiveIcon,
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
    final defaultColor = context.isDark
        ? AppColors.noteToolbarTextDark
        : AppColors.noteToolbarTextLight;

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
