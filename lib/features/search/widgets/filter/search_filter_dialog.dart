import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_sheet.dart';

// Search filter dialog provides the modal shell for the filter sheet.
class SearchFilterActionButton extends StatelessWidget {
  final search_ctrl.SearchController controller;

  const SearchFilterActionButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: SearchConstants.appBarActionPadding,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => _openSearchFilterDialog(context),
        icon: ImageIcon(
          const AssetImage('assets/images/filter_icon.png'),
          color: context.isDark ? const Color(0xFFFFFFFF) : Colors.black54,
          size: SearchConstants.filterButtonSize,
        ),
        splashRadius: SearchConstants.filterButtonSize,
      ),
    );
  }

  Future<void> _openSearchFilterDialog(BuildContext context) async {
    if (context.viewInsetsBottom > 0) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (!context.mounted) return;

    final result = await showGeneralDialog<SearchFilters>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Filter',
      barrierColor: Colors.black.withValues(
        alpha: SearchConstants.dialogBarrierAlpha,
      ),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, _, _) => _buildResponsiveDialogWrapper(
        context,
        child: SearchFilterBottomSheet(initialFilters: controller.filters),
      ),
      transitionBuilder: (context, animation, _, child) {
        final bool isClosing = animation.status == AnimationStatus.reverse;
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: isClosing
              ? Curves.easeInOutCubic
              : const Cubic(0.2, 0.0, 0.0, 1.0),
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: isClosing ? Curves.easeOutCubic : const Interval(0.0, 0.5),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.4),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (result != null) controller.applyFilters(result);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildResponsiveDialogWrapper(
    BuildContext context, {
    required Widget child,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.viewInsetsBottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: SearchConstants.filterDialogMaxWidth,
            ),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );
  }
}

