import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ListMenu extends StatelessWidget {
  const ListMenu({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final currentList = controller
            .getSelectionStyle()
            .attributes['list']
            ?.value;
        final bool isListActive =
            currentList == Attribute.ul.value ||
            currentList == Attribute.ol.value;

        return MenuAnchor(
          alignmentOffset: const Offset(0, -170),
          builder: (context, menuController, child) => IconButton(
            icon: Icon(
              Icons.format_list_bulleted,
              color: (menuController.isOpen || isListActive)
                  ? Colors.blueAccent
                  : (isDark ? Colors.white : Colors.black54),
            ),
            onPressed: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
          ),
          menuChildren: [
            _buildListItem(
              Icons.format_list_bulleted,
              'Bullets',
              currentList,
              Attribute.ul,
            ),
            _buildListItem(
              Icons.format_list_numbered,
              'Numbers',
              currentList,
              Attribute.ol,
            ),
          ],
        );
      },
    );
  }

  Widget _buildListItem(
    IconData icon,
    String label,
    dynamic currentList,
    Attribute attr,
  ) {
    final isSelected = currentList == attr.value;
    return MenuItemButton(
      leadingIcon: Icon(
        icon,
        color: isSelected
            ? Colors.blue
            : (isDark ? Colors.white : Colors.black54),
      ),
      onPressed: () => _handleListToggle(attr),
      child: Text(label),
    );
  }

  void _handleListToggle(Attribute attribute) {
    focusNode.requestFocus();

    final selection = controller.selection;
    final style = controller.getSelectionStyle();
    final currentList = style.attributes['list'];

    // 1. Handle non-collapsed selection (standard behavior)
    if (!selection.isCollapsed) {
      if (currentList?.value == attribute.value) {
        controller.formatSelection(Attribute.clone(Attribute.list, null));
      } else {
        controller.formatSelection(attribute);
      }
      return;
    }

    // 2. Handle collapsed selection with parent block logic
    final offset = selection.baseOffset;
    final queryResult = controller.document.queryChild(offset);
    final line = queryResult.node;

    if (line != null && line.parent != null) {
      final parent = line.parent!;

      // If the parent already contains a list, we manage the whole block
      if (parent.style.attributes.containsKey('list')) {
        final blockStart = parent.documentOffset;
        final blockLength = parent.length;

        if (currentList?.value == attribute.value) {
          // Toggle OFF: Remove list formatting specifically from this row
          controller.formatText(
            line.documentOffset,
            line.length,
            Attribute.clone(Attribute.list, null),
          );
          controller.formatSelection(Attribute.clone(Attribute.list, null));
        } else {
          // Toggle ON/SWITCH: Apply new list type to the entire block
          controller.formatText(blockStart, blockLength, attribute);
          controller.formatSelection(attribute);
        }
        return;
      }
    }

    // 3. Fallback to standard selection formatting
    if (currentList?.value == attribute.value) {
      controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      controller.formatSelection(attribute);
    }
  }
}
