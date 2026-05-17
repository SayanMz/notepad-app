import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/features/note/widgets/toolbar_items/alignment_menu.dart';
import 'package:notepad/features/note/widgets/toolbar_items/color_menu.dart';
import 'package:notepad/features/note/services/hyperlink_handler.dart';
import 'package:notepad/features/note/widgets/toolbar_items/list_menu.dart';
import 'package:notepad/features/note/widgets/toolbar_items/size_menu.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';

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
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

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

  /// Restoration of the "Nudge" logic to signal scrollability to the user.
  Future<void> _performNudge() async {
    await Future.delayed(AnimationConstants.extraSlow);
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      NoteConstants.toolbarNudgeDistance,
      duration: AnimationConstants.medium,
      curve: Curves.easeOut,
    );
    await _scrollController.animateTo(
      0.0,
      duration: AnimationConstants.medium,
      curve: Curves.easeIn,
    );
    widget.onNudgeComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGlassContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // MATH FIX: Restored the 4.5 divisor to ensure the 5th item is half-visible.
          final double itemWidth =
              constraints.maxWidth / NoteConstants.toolbarItemWidthDivisor;
          return _buildScrollableRow(itemWidth);
        },
      ),
    );
  }

  /// Helper: Orchestrates the scrollable row and the ShaderMask fades.
  Widget _buildScrollableRow(double itemWidth) {
    final List<Widget> items = [
      _buildToggle(Icons.format_bold, Attribute.bold),
      _buildToggle(Icons.format_italic, Attribute.italic),
      _buildToggle(Icons.format_underlined, Attribute.underline),
      _buildToggle(Icons.format_strikethrough, Attribute.strikeThrough),
      _buildCheckbox(),
      SizeMenu(controller: widget.controller, isDark: isDark),
      ColorMenu(
        controller: widget.controller,
        focusNode: widget.focusNode,
        isDark: isDark,
        toolbarController: widget.toolbarController,
      ),
      ListMenu(
        controller: widget.controller,
        isDark: isDark,
        focusNode: widget.focusNode,
      ),
      AlignmentMenu(controller: widget.controller, isDark: isDark),
      _buildLinkButton(),
    ];

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
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

  Widget _buildToggle(IconData icon, Attribute attr) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isSel = widget.controller
            .getSelectionStyle()
            .attributes
            .containsKey(attr.key);
        return IconButton(
          icon: Icon(
            icon,
            color: isSel
                ? Colors.blueAccent
                : (isDark ? Colors.white : Colors.black54),
          ),
          onPressed: () {
            widget.focusNode.requestFocus();
            widget.controller.formatSelection(
              isSel ? Attribute.clone(attr, null) : attr,
            );
          },
        );
      },
    );
  }

  Widget _buildCheckbox() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final val = widget.controller
            .getSelectionStyle()
            .attributes['list']
            ?.value;
        final isSel = (val == 'unchecked' || val == 'checked');
        return IconButton(
          icon: Icon(
            Icons.check_box_outlined,
            color: isSel
                ? Colors.blueAccent
                : (isDark ? Colors.white : Colors.black54),
          ),
          onPressed: () {
            widget.focusNode.requestFocus();
            widget.controller.formatSelection(
              isSel
                  ? Attribute.clone(Attribute.list, null)
                  : Attribute.unchecked,
            );
          },
        );
      },
    );
  }

  Widget _buildLinkButton() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final isLink = widget.controller
            .getSelectionStyle()
            .attributes
            .containsKey('link');
        return IconButton(
          icon: Icon(
            Icons.link,
            color: isLink
                ? Colors.blueAccent
                : (isDark ? Colors.white : Colors.black54),
          ),
          onPressed: () => HyperlinkHandler.convertToHyperlink(
            context: context,
            controller: widget.controller,
            focusNode: widget.focusNode,
          ),
        );
      },
    );
  }

  /// Helper: Wraps the toolbar in the signature Glassmorphism effect and shadow.
  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      height: NoteConstants.toolbarHeight,
      margin: const EdgeInsets.fromLTRB(
        NoteConstants.toolbarMarginH,
        NoteConstants.toolbarMarginTop,
        NoteConstants.toolbarMarginH,
        NoteConstants.toolbarMarginBottom,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NoteConstants.toolbarBorderRadius),
        color: isDark
            ? Colors.white.withValues(alpha: NoteConstants.toolbarAlphaDark)
            : Colors.white.withValues(alpha: NoteConstants.toolbarAlphaLight),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: NoteConstants.toolbarBorderAlpha,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: NoteConstants.toolbarShadowAlpha,
            ),
            blurRadius: NoteConstants.toolbarShadowBlur,
            offset: Offset(0, NoteConstants.toolbarShadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NoteConstants.toolbarBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: NoteConstants.toolbarBlurSigma,
            sigmaY: NoteConstants.toolbarBlurSigma,
          ),
          child: child,
        ),
      ),
    );
  }
}
