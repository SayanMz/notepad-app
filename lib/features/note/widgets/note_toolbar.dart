import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/main.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class NoteToolbar extends StatefulWidget {
  const NoteToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.shouldNudge = false, // NEW
    this.onNudgeComplete,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final bool shouldNudge;
  final VoidCallback? onNudgeComplete;

  @override
  State<NoteToolbar> createState() => _NoteToolbarState();
}

class _NoteToolbarState extends State<NoteToolbar> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  late final ScrollController _rowScrollController;
  late final ScrollController _fontSizeScrollController;

  @override
  void initState() {
    super.initState();
    _rowScrollController = ScrollController();
    _fontSizeScrollController = ScrollController();

    // 2. Trigger the Nudge if requested
    if (widget.shouldNudge) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _performNudge());
    }
  }

  @override
  void dispose() {
    _rowScrollController.dispose();
    _fontSizeScrollController.dispose();
    super.dispose();
  }

  void _openCustomColorPicker() {
    // Get currently selected color to start the picker with, default to black/white
    final currentAttr = widget.controller
        .getSelectionStyle()
        .attributes['color'];
    Color pickerColor = currentAttr != null
        ? Color(int.parse(currentAttr.value.replaceFirst('#', '0xff')))
        : (isDark ? Colors.white : Colors.black);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            pickerAreaHeightPercent: 0.7, // Balances height like your reference
            enableAlpha: false, // Standard hex only for Quill
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final hex =
                  '#${pickerColor.toARGB32().toRadixString(16).substring(2)}';
              widget.controller.formatSelection(ColorAttribute(hex));
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _performNudge() async {
    // Wait for the NotePage's AnimatedSize to finish sliding down
    // (Adjust this duration if your UIConstants.animationMedium is different)
    await Future.delayed(UIConstants.animationExtraSlow);

    if (!mounted || !_rowScrollController.hasClients) return;

    // Nudge right
    await _rowScrollController.animateTo(
      180.0,
      duration: UIConstants.animationMedium,
      curve: Curves.easeOut,
    );

    if (!mounted || !_rowScrollController.hasClients) return;

    // Snap back
    await _rowScrollController.animateTo(
      0.0,
      duration: UIConstants.animationMedium,
      curve: Curves.easeIn,
    );

    // Tell the parent we are done so it never happens again
    widget.onNudgeComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRawGlassToolbar(
          [
            _buildRawToggle(Icons.format_bold, Attribute.bold),
            _buildRawToggle(Icons.format_italic, Attribute.italic),
            _buildRawToggle(Icons.format_underlined, Attribute.underline),
            _buildRawToggle(
              Icons.format_strikethrough,
              Attribute.strikeThrough,
            ),
            _buildCheckboxToggle(),
          ],
          isScrollable: true,
          scrollController: _rowScrollController,
        ),
        _buildRawGlassToolbar(
          [
            _buildRawSizeMenu(),
            _buildRawColorMenu(),
            _buildRawListMenu(),
            _buildRawAlignmentMenu(widget.controller),
            IconButton(
              icon: Icon(
                Icons.link,
                color: isDark ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _convertToHyperlink(context),
            ),
          ],
          isScrollable: true,
          scrollController: _rowScrollController,
        ),
        const SizedBox(height: UIConstants.paddingM),
      ],
    );
  }

  // --- HYPERLINK LOGIC ---
  Future<void> _convertToHyperlink(BuildContext context) async {
    final selection = widget.controller.selection;
    int startIndex = selection.baseOffset;
    int textLength = selection.extentOffset - startIndex;

    String targetUrl = '';

    /// Extract selected or nearby text
    if (textLength > 0) {
      targetUrl = widget.controller.document.getPlainText(
        startIndex,
        textLength,
      );
    } else {
      final textBefore = widget.controller.document.getPlainText(0, startIndex);
      final lastSpace = textBefore.lastIndexOf(RegExp(r'\s'));
      startIndex = lastSpace == -1 ? 0 : lastSpace + 1;
      textLength = selection.baseOffset - startIndex;

      if (textLength <= 0) return;
      targetUrl = widget.controller.document.getPlainText(
        startIndex,
        textLength,
      );
    }

    /// Validate URL
    if (!_isValidLink(targetUrl)) {
      showRootSnackBar(
        const SnackBar(
          backgroundColor: AppColors.deleteDarkIcon,
          content: Text('Please enter a valid link'),
        ),
      );
      return;
    }

    String finalUrl = targetUrl.trim();
    if (!finalUrl.toLowerCase().startsWith('http://') &&
        !finalUrl.toLowerCase().startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    /// Ask user for display title
    final displayTitle = await _showLinkTitleDialog(context);

    if (displayTitle != null && displayTitle.isNotEmpty) {
      const trailingSpace = ' ';
      final insertedText = '$displayTitle$trailingSpace';
      widget.controller.replaceText(startIndex, textLength, insertedText, null);

      widget.controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.fromKeyValue('link', finalUrl),
      );
      widget.controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.fromKeyValue('color', AppColors.hyperlinkHex),
      );
      widget.controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.underline,
      );

      widget.controller.updateSelection(
        TextSelection.collapsed(offset: startIndex + insertedText.length),
        ChangeSource.local,
      );
      widget.controller.forceToggledStyle(const Style());
      widget.focusNode.requestFocus();
    }
  }

  bool _isValidLink(String text) {
    return RegExp(
      r'^(https?://)?([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)?$',
    ).hasMatch(text.trim());
  }

  Future<String?> _showLinkTitleDialog(BuildContext context) {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Hyperlink Title'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'e.g., Google or My Website',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers for Styling Bar ---
  Widget _buildRawGlassToolbar(
    List<Widget> children, {
    bool isScrollable = false,
    ScrollController? scrollController,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        UIConstants.toolbarMarginHorizontal,
        UIConstants.toolbarMarginTop,
        UIConstants.toolbarMarginHorizontal,
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UIConstants.radiusMD),
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: UIConstants.toolbarBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: UIConstants.toolbarShadowBlur,
            offset: const Offset(0, UIConstants.toolbarShadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UIConstants.radiusMD),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: UIConstants.toolbarBlurSigma,
            sigmaY: UIConstants.toolbarBlurSigma,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Divide by 4 to ensure exactly 4 items fit perfectly
              final double itemWidth = constraints.maxWidth / 4;
              final alignedChildren = children
                  .map(
                    (child) => SizedBox(
                      width: itemWidth,
                      child: Center(child: child),
                    ),
                  )
                  .toList();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: UIConstants.toolbarVerticalPadding,
                ),
                child: isScrollable
                    ? ShaderMask(
                        shaderCallback: (Rect rect) {
                          return const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [
                              0.0,
                              0.1,
                              0.9,
                              1.0,
                            ], // Fade starts at 85% of the width
                          ).createShader(rect);
                        },
                        blendMode: BlendMode
                            .dstIn, // Uses the gradient as an alpha mask
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(children: alignedChildren),
                        ),
                      )
                    : Row(children: alignedChildren),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRawToggle(IconData icon, Attribute attr) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final isSelected = widget.controller
            .getSelectionStyle()
            .attributes
            .containsKey(attr.key);
        return IconButton(
          icon: Icon(
            icon,
            color: isSelected
                ? Colors.blueAccent
                : (isDark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          onPressed: () {
            widget.focusNode.requestFocus();
            widget.controller.formatSelection(
              isSelected ? Attribute.clone(attr, null) : attr,
            );
          },
        );
      },
    );
  }

  Widget _buildRawSizeMenu() {
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

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final style = widget.controller.getSelectionStyle();
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

        return MenuAnchor(
          alignmentOffset: const Offset(-15, 0),
          builder: (context, menuController, child) => IconButton(
            icon: Icon(
              Icons.text_fields,
              color: menuController.isOpen
                  ? Colors.blueAccent
                  : isDark
                  ? Colors.white
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
          ),
          menuChildren: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50, maxHeight: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. HEADINGS DROPDOWN (Now dropping downwards)
                  Expanded(
                    child: MenuAnchor(
                      // Pushes the menu straight down beneath the button
                      alignmentOffset: const Offset(-55, 40),
                      builder: (context, innerMenuController, child) {
                        return TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : colorScheme.onSurfaceVariant,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => innerMenuController.isOpen
                              ? innerMenuController.close()
                              : innerMenuController.open(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                headingLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Arrow pointing down
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        );
                      },
                      menuChildren: [
                        _buildHeadingSizeItem('H1 (Title)', 32.0, currentSize),
                        _buildHeadingSizeItem('H2 (Header)', 28.0, currentSize),
                        _buildHeadingSizeItem(
                          'H3 (Subheader)',
                          24.0,
                          currentSize,
                        ),
                        _buildHeadingSizeItem(
                          'H4 (Small Header)',
                          20.0,
                          currentSize,
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 25,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),

                  // 2. FONT SIZE DROPDOWN (Now dropping downwards)
                  Expanded(
                    child: MenuAnchor(
                      // Pushes the menu straight down beneath the button
                      alignmentOffset: const Offset(-55, 40),
                      builder: (context, innerMenuController, child) {
                        return TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : colorScheme.onSurfaceVariant,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => innerMenuController.isOpen
                              ? innerMenuController.close()
                              : innerMenuController.open(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${currentSize.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Arrow pointing down
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        );
                      },
                      menuChildren: [
                        SizedBox(
                          height: 250,
                          child: Scrollbar(
                            thumbVisibility: true,
                            controller: _fontSizeScrollController,
                            child: SingleChildScrollView(
                              controller: _fontSizeScrollController,
                              child: Column(
                                children: standardSizes.map((size) {
                                  final bool isSelected = currentSize == size;
                                  return MenuItemButton(
                                    onPressed: () => _changeTextSize(size),
                                    child: Text(
                                      '${size.toInt()}',
                                      style: TextStyle(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : null,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
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

  // Update the helper to handle the light-up color
  Widget _buildHeadingSizeItem(String label, double size, double currentSize) {
    final bool isSelected = currentSize == size;
    return MenuItemButton(
      onPressed: () => _changeTextSize(size),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRawColorMenu() {
    return MenuAnchor(
      alignmentOffset: const Offset(-UIConstants.toolbarColorMenuOffsetX, 0),
      builder: (context, menuController, child) => IconButton(
        icon: const Icon(Icons.palette, color: Colors.redAccent),
        onPressed: () => menuController.isOpen
            ? menuController.close()
            : menuController.open(),
      ),
      menuChildren: [
        SizedBox(
          width: UIConstants.toolbarMenuWidth,
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              _buildColorCircle(
                isDark ? Colors.white : Colors.black,
                isDefault: true,
              ),
              _buildColorCircle(Colors.red),
              _buildColorCircle(Colors.pinkAccent),
              _buildColorCircle(Colors.amber),
              _buildColorCircle(Colors.green),
              _buildColorCircle(Colors.blue),
              _buildColorCircle(Colors.purple),
              // Rainbow trigger
              _buildColorCircle(Colors.transparent, isRainbow: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorCircle(
    Color color, {
    bool isDefault = false,
    bool isRainbow = false,
  }) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final String hexString =
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        final bool isSelected = isDefault
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
              _openCustomColorPicker();
            } else {
              final colorAttr = isDefault
                  ? Attribute.fromKeyValue('color', null)
                  : ColorAttribute(hexString);
              if (widget.controller.selection.isCollapsed) {
                widget.controller.formatSelection(colorAttr);
              } else {
                widget.controller.formatText(
                  widget.controller.selection.start,
                  widget.controller.selection.end -
                      widget.controller.selection.start,
                  colorAttr,
                );
              }
            }

            widget.focusNode.requestFocus();
          },
          child: Container(
            margin: const EdgeInsets.all(UIConstants.toolbarColorCircleMargin),
            width: UIConstants.toolbarColorCircleSize,
            height: UIConstants.toolbarColorCircleSize,
            decoration: BoxDecoration(
              // Use gradient for rainbow, solid color for others
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

  Widget _buildCheckboxToggle() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final currentList = widget.controller
            .getSelectionStyle()
            .attributes['list']
            ?.value;

        // Checkboxes have two possible values: 'unchecked' or 'checked'
        final bool isSelected =
            currentList == Attribute.unchecked.value ||
            currentList == Attribute.checked.value;

        return IconButton(
          icon: Icon(
            Icons.check_box_outlined,
            color: isSelected
                ? Colors
                      .blueAccent // Turn blue when selected
                : (isDark ? Colors.white : colorScheme.onSurfaceVariant),
          ),
          onPressed: () => _toggleListAttribute(Attribute.unchecked),
        );
      },
    );
  }

  Widget _buildRawListMenu() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        // Get the current list attribute value (e.g., 'ul' or 'ol')
        final currentList = widget.controller
            .getSelectionStyle()
            .attributes['list']
            ?.value;

        final bool isListActive =
            currentList == Attribute.ul.value ||
            currentList == Attribute.ol.value;

        return MenuAnchor(
          builder: (context, menuController, child) => IconButton(
            icon: Icon(
              Icons.format_list_bulleted,
              color: (menuController.isOpen || isListActive)
                  ? Colors.blueAccent
                  : (isDark ? Colors.white : colorScheme.onSurfaceVariant),
            ),
            onPressed: () => menuController.isOpen
                ? menuController.close()
                : menuController.open(),
          ),
          menuChildren: [
            _buildListItem(
              Icons.format_list_bulleted,
              'Bullets',
              isDark,
              currentList,
              Attribute.ul,
              colorScheme,
            ),
            _buildListItem(
              Icons.format_list_numbered,
              'Numbers',
              isDark,
              currentList,
              Attribute.ol,
              colorScheme,
            ),
          ],
        );
      },
    );
  }

  Widget _buildListItem(
    IconData icon,
    String label,
    bool isDark,
    dynamic currentList,
    Attribute attr,
    ColorScheme colorScheme,
  ) {
    // Check if this specific list type is active
    final isSelected = currentList == attr.value;
    // Highlighting: Amber for Dark mode, Teal for Light mode

    final defaultColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return MenuItemButton(
      style: ButtonStyle(
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (isSelected) {
            return colorScheme.primary;
          }
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary;
          }
          return defaultColor;
        }),
      ),
      leadingIcon: Icon(icon),
      onPressed: () => _toggleListAttribute(attr), // Uses your existing logic
      child: Text(label),
    );
  }

  void _changeTextSize(double exactSize) {
    final sizeAttr = Attribute.fromKeyValue('size', exactSize);

    if (widget.controller.selection.isCollapsed) {
      widget.controller.formatSelection(sizeAttr);
    } else {
      widget.controller.formatText(
        widget.controller.selection.start,
        widget.controller.selection.end - widget.controller.selection.start,
        sizeAttr,
      );
    }

    widget.focusNode.requestFocus();
  }

  void _toggleListAttribute(Attribute attribute) {
    widget.focusNode.requestFocus();

    final selection = widget.controller.selection;
    final style = widget.controller.getSelectionStyle();
    final currentList = style.attributes['list'];

    //  STANDARD BEHAVIOR
    if (!selection.isCollapsed) {
      if (currentList?.value == attribute.value) {
        widget.controller.formatSelection(
          Attribute.clone(Attribute.list, null),
        );
      } else {
        widget.controller.formatSelection(attribute);
      }
      return;
    }

    final offset = selection.baseOffset;
    final line = widget.controller.document.queryChild(offset).node;

    if (line != null && line.parent != null) {
      final parent = line.parent!;

      if (parent.style.attributes.containsKey('list')) {
        final blockStart = parent.documentOffset;
        final blockLength = parent.length;

        if (currentList?.value == attribute.value) {
          // Toggle OFF: Remove formatting from the document row
          widget.controller.formatText(
            line.documentOffset,
            line.length,
            Attribute.clone(Attribute.list, null),
          );

          widget.controller.formatSelection(
            Attribute.clone(Attribute.list, null),
          );
        } else {
          // Toggle ON / SWITCH: Apply new list type to the entire document block
          widget.controller.formatText(blockStart, blockLength, attribute);

          widget.controller.formatSelection(attribute);
        }

        return; // updateSelection is no longer needed, formatSelection handles it
      }
    }

    // 3. FALLBACK
    if (currentList?.value == attribute.value) {
      widget.controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      widget.controller.formatSelection(attribute);
    }
  }

  Widget _buildRawAlignmentMenu(QuillController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final currentAlign = controller
            .getSelectionStyle()
            .attributes[Attribute.align.key]
            ?.value;

        return MenuAnchor(
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
            _buildAlignmentItem(
              Icons.format_align_left,
              'left',
              'Left',
              isDark,
              currentAlign,
            ),
            _buildAlignmentItem(
              Icons.format_align_center,
              'center',
              'Center',
              isDark,
              currentAlign,
            ),
            _buildAlignmentItem(
              Icons.format_align_right,
              'right',
              'Right',
              isDark,
              currentAlign,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlignmentItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
    dynamic currentAlign,
  ) {
    final bool isSelected =
        (currentAlign == value) || (currentAlign == null && value == 'left');

    final activeColor = colorScheme.primary;
    final defaultColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return MenuItemButton(
      leadingIcon: Icon(icon, color: isSelected ? activeColor : defaultColor),
      onPressed: () => widget.controller.formatSelection(
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

/*
Interview Note: "I refactored the toolbar into a StatefulWidget to centralize theme data access. 
By using getters on the State class, I eliminated redundant context passing across my helper methods 
while ensuring the UI remains reactive to system theme changes."
*/
