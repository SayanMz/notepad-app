import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/note/services/link_handlers/hyperlink_handler.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/alignment_menu.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/color_menu.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/list_menu.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/size_menu.dart';

// Glassy formatting toolbar for the note editor with inline styles, lists, colors, alignment, and links.
class NoteToolbar extends StatefulWidget {
  const NoteToolbar({
    super.key,
    required this.controller,
    required this.toolbarController,
    required this.focusNode,
    this.shouldNudge = false,
    this.onNudgeComplete,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final bool shouldNudge;
  final VoidCallback? onNudgeComplete;
  final NoteToolbarController toolbarController;

  @override
  State<NoteToolbar> createState() => _NoteToolbarState();
}

class _NoteToolbarState extends State<NoteToolbar> {
  late final ScrollController _scrollController;

  final MenuController _alignMenuCtrl = MenuController();
  final MenuController _listMenuCtrl = MenuController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.shouldNudge) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _performNudge());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    uiNotifier.clearSnackBars();
    super.dispose();
  }

  Future<void> _performNudge() async {
    await Future.delayed(AnimationConstants.extraSlow);
    if (!mounted || !_scrollController.hasClients) return;

    try {
      // First scroll leg towards right
      await _scrollController.animateTo(
        NoteConstants.toolbarNudgeDistance,
        duration: AnimationConstants.medium,
        curve: Curves.easeOut,
      );
      if (!mounted || !_scrollController.hasClients) return;

      // Second scroll leg back to start
      await _scrollController.animateTo(
        0.0,
        duration: AnimationConstants.medium,
        curve: Curves.easeIn,
      );

      widget.onNudgeComplete?.call();
    } catch (_) {
      // Swallows the scroll controller detachment error if destroyed mid-animation
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildGlassContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth =
              constraints.maxWidth / NoteConstants.toolbarItemWidthDivisor;

          return ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final selectionStyle = widget.controller.getSelectionStyle();
              final attributes = selectionStyle.attributes;
              final currentList = attributes['list']?.value;
              final isBold = attributes.containsKey(Attribute.bold.key);
              final isItalic = attributes.containsKey(Attribute.italic.key);
              final isUnderline = attributes.containsKey(
                Attribute.underline.key,
              );
              final isStrike = attributes.containsKey(
                Attribute.strikeThrough.key,
              );
              final isLink = attributes.containsKey('link');
              final isCheckbox =
                  currentList == 'unchecked' || currentList == 'checked';

              return _buildScrollableRow(
                itemWidth,
                selectionStyle: selectionStyle,
                isBold: isBold,
                isItalic: isItalic,
                isUnderline: isUnderline,
                isStrike: isStrike,
                isCheckbox: isCheckbox,
                isLink: isLink,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScrollableRow(
    double itemWidth, {
    required Style selectionStyle,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
    required bool isStrike,
    required bool isCheckbox,
    required bool isLink,
  }) {
    final List<Widget> items = [
      _buildToggle(Icons.format_bold, Attribute.bold, isBold),
      _buildToggle(Icons.format_italic, Attribute.italic, isItalic),
      _buildToggle(Icons.format_underlined, Attribute.underline, isUnderline),
      _buildToggle(
        Icons.format_strikethrough,
        Attribute.strikeThrough,
        isStrike,
      ),
      _buildCheckbox(isCheckbox),
      SizeMenu(
        controller: widget.controller,
        focusNode: widget.focusNode,
        toolbarController: widget.toolbarController,
        selectionStyle: selectionStyle,
      ),
      ColorMenu(
        controller: widget.controller,
        focusNode: widget.focusNode,
        toolbarController: widget.toolbarController,
        selectionStyle: selectionStyle,
      ),
      ListMenu(
        controller: widget.controller,
        focusNode: widget.focusNode,
        toolbarController: widget.toolbarController,
        menuController: _listMenuCtrl,
        selectionStyle: selectionStyle,
      ),
      AlignmentMenu(
        controller: widget.controller,
        toolbarController: widget.toolbarController,
        menuController: _alignMenuCtrl,
        selectionStyle: selectionStyle,
      ),
      _buildLinkButton(isLink),
    ];

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          AppColors.noteToolbarGradientLight,
          AppColors.noteToolbarGradientDark,
          AppColors.noteToolbarGradientDark,
          AppColors.noteToolbarGradientLight,
        ],
        stops: [
          NoteConstants.toolbarGradientStopEdge,
          NoteConstants.toolbarGradientStopStart,
          NoteConstants.toolbarGradientStopEnd,
          NoteConstants.toolbarGradientStopOppositeEdge,
        ],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: items
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildToggle(IconData icon, Attribute attr, bool isSelected) {
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected
            ? AppColors.toolbarActiveIcon
            : (context.isDark
                ? AppColors.noteToolbarTextDark
                : AppColors.noteToolbarTextLight),
      ),
      onPressed: () {
        widget.focusNode.requestFocus();
        widget.controller.formatSelection(
          isSelected ? Attribute.clone(attr, null) : attr,
        );
      },
    );
  }

  Widget _buildCheckbox(bool isSelected) {
    return IconButton(
      icon: Icon(
        Icons.check_box_outlined,
        color: isSelected
            ? AppColors.toolbarActiveIcon
            : (context.isDark
                ? AppColors.noteToolbarTextDark
                : AppColors.noteToolbarTextLight),
      ),
      onPressed: () {
        widget.controller.formatSelection(
          isSelected
              ? Attribute.clone(Attribute.list, null)
              : Attribute.unchecked,
        );
      },
    );
  }

  Widget _buildLinkButton(bool isLink) {
    return IconButton(
      icon: Icon(
        Icons.link,
        color: isLink
            ? AppColors.toolbarActiveLink
            : (context.isDark
                ? AppColors.noteToolbarTextDark
                : AppColors.noteToolbarTextLight),
      ),
      onPressed: () => HyperlinkHandler.convertToHyperlink(
        context: context,
        controller: widget.controller,
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Container(
        height: EditorConstants.toolbarHeight,
        margin: const EdgeInsets.fromLTRB(
          NoteConstants.toolbarMarginH,
          NoteConstants.toolbarMarginTop,
          NoteConstants.toolbarMarginH,
          NoteConstants.toolbarMarginBottom,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            NoteConstants.toolbarBorderRadius,
          ),
          color: AppColors.toolbarInactiveIconDark.withValues(
            alpha: context.isDark
                ? NoteConstants.toolbarAlphaDark
                : NoteConstants.toolbarAlphaLight,
          ),
          border: Border.all(
            color: AppColors.toolbarInactiveIconDark.withValues(
              alpha: NoteConstants.toolbarBorderAlpha,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.toolbarShadow.withValues(
                alpha: NoteConstants.toolbarShadowAlpha,
              ),
              blurRadius: NoteConstants.toolbarShadowBlur,
              offset: Offset(0, NoteConstants.toolbarShadowOffsetY),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            NoteConstants.toolbarBorderRadius,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: NoteConstants.toolbarBlurSigma,
              sigmaY: NoteConstants.toolbarBlurSigma,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
