import 'package:flutter/material.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/search_constants.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_dialog.dart';
import 'package:notepad/features/search/widgets/header/search_input_field_bar.dart';
import 'package:notepad/features/search/widgets/header/search_quick_chips.dart';

class SearchCollapsibleHeader extends StatelessWidget {
  const SearchCollapsibleHeader({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final search_ctrl.SearchController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(
              right: SearchConstants.appBarTitleRightPadding,
            ),
            child: SearchInputFieldBar(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
          actions: [SearchFilterButton(controller: controller)],
        ),
        const SizedBox(height: 12.0),
        SearchQuickChips(controller: controller),
      ],
    );
  }
}
