import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/draggable_color_picker.dart';

// Text color menu for applying text colors and opening the custom picker.
class ColorMenu extends StatefulWidget {
  const ColorMenu({
    super.key,
    required this.controller,
    required this.focusNode,

    required this.toolbarController,
    required this.selectionStyle,
  });

  final QuillController controller;
  final NoteToolbarController toolbarController;
  final FocusNode focusNode;

  final Style selectionStyle;

  @override
  State<ColorMenu> createState() => _ColorMenuState();
}

class _ColorMenuState extends State<ColorMenu> {
  OverlayEntry? _overlayEntry;
  late final MenuController _menuController = MenuController();

  void _toggleCustomPicker() {
    if (_overlayEntry != null) {
      _closePicker();
    } else {
      _openPicker();
    }
  }

  @override
  void initState() {
    super.initState();
    // Register the internal close picker logic with the controller
    widget.toolbarController.register(_closePicker);
  }

  @override
  Future<void> dispose() async {
    widget.toolbarController.unregister(_closePicker);
    super.dispose();
  }

  void _openPicker() {
    final currentAttr = widget.selectionStyle.attributes['color'];
    final Color initialColor = currentAttr != null
        ? Color(int.parse(currentAttr.value.replaceFirst('#', '0xff')))
        : (context.isDark ? Colors.white : Colors.black);

    _overlayEntry = OverlayEntry(
      builder: (context) => DraggableColorPicker(
        initialColor: initialColor,
        isDark: context.isDark,
        onColorChanged: (selectedColor) {
          final hex =
              '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          widget.controller.formatSelection(ColorAttribute(hex));
        },
        onDismissRequested: _closePicker,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closePicker() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    // Ensure the parent MenuAnchor also closes
    if (_menuController.isOpen) _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.selectionStyle.attributes['color'];

    return ToolbarMenuWrapper(
      toolbarController: widget.toolbarController,
      menuController: _menuController,
      child: MenuAnchor(
        controller: _menuController,
        alignmentOffset: const Offset(-25, -160),
        builder: (context, controller, child) => IconButton(
          icon: const Icon(Icons.palette, color: Colors.redAccent),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
        menuChildren: [
          SizedBox(
            width: EditorConstants.toolbarMenuWidth,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _buildColorCircle(
                  context,
                  context.isDark ? Colors.white : Colors.black,
                  isDefault: true,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.red,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.pinkAccent,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.amber,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.green,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.blue,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.purple,
                  currentColor: currentColor,
                ),
                _buildColorCircle(
                  context,
                  Colors.transparent,
                  isRainbow: true,
                  currentColor: currentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(
    BuildContext context,
    Color color, {
    bool isDefault = false,
    bool isRainbow = false,
    dynamic currentColor,
  }) {
    final hexString =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final isSelected = isDefault
        ? currentColor == null
        : !isRainbow && currentColor?.value == hexString;

    return GestureDetector(
      onTap: () {
        if (isRainbow) {
          _toggleCustomPicker();
        } else {
          final colorAttr = isDefault
              ? Attribute.fromKeyValue('color', null)
              : ColorAttribute(hexString);
          widget.controller.formatSelection(colorAttr);

          if (_menuController.isOpen) {
            _menuController.close();
          }

          widget.focusNode.requestFocus();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(EditorConstants.toolbarColorCircleMargin),
        width: EditorConstants.toolbarColorCircleSize,
        height: EditorConstants.toolbarColorCircleSize,
        decoration: BoxDecoration(
          color: isRainbow ? null : color,
          gradient: isRainbow
              ? const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.indigo,
                    Colors.purple,
                    Colors.red,
                  ],
                )
              : null,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.lightGreenAccent : Colors.white,
            width: EditorConstants.toolbarColorCircleBorderWidth,
          ),
        ),
      ),
    );
  }
}
