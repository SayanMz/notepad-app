import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/widgets/toolbar_items/draggable_color_picker.dart';

class ColorMenu extends StatefulWidget {
  const ColorMenu({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.toolbarController,
  });

  final QuillController controller;
  final NoteToolbarController toolbarController;
  final FocusNode focusNode;
  final bool isDark;

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
    widget.toolbarController.register(_closePicker);
  }

  void _closePicker() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    if (_menuController.isOpen) _menuController.close();
  }

  void _openPicker() {
    final currentAttr = widget.controller
        .getSelectionStyle()
        .attributes['color'];
    Color initialColor = currentAttr != null
        ? Color(int.parse(currentAttr.value.replaceFirst('#', '0xff')))
        : (widget.isDark ? Colors.white : Colors.black);

    _overlayEntry = OverlayEntry(
      builder: (context) => DraggableColorPicker(
        initialColor: initialColor,
        isDark: widget.isDark,
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

  @override
  Future<void> dispose() async {
    widget.toolbarController.unregister(_closePicker);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            width: UIConstants.toolbarMenuWidth,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _buildColorCircle(
                  context,
                  widget.isDark ? Colors.white : Colors.black,
                  isDefault: true,
                ),
                _buildColorCircle(context, Colors.red),
                _buildColorCircle(context, Colors.pinkAccent),
                _buildColorCircle(context, Colors.amber),
                _buildColorCircle(context, Colors.green),
                _buildColorCircle(context, Colors.blue),
                _buildColorCircle(context, Colors.purple),
                _buildColorCircle(context, Colors.transparent, isRainbow: true),
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
  }) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final hexString =
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        final isSelected = isDefault
            ? widget.controller.getSelectionStyle().attributes['color'] == null
            : !isRainbow &&
                  widget.controller
                          .getSelectionStyle()
                          .attributes['color']
                          ?.value ==
                      hexString;

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
            margin: const EdgeInsets.all(UIConstants.toolbarColorCircleMargin),
            width: UIConstants.toolbarColorCircleSize,
            height: UIConstants.toolbarColorCircleSize,
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
                width: UIConstants.toolbarColorCircleBorderWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}
