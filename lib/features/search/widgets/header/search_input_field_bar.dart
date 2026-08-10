import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/search/controllers/search_controller.dart'
    as search_ctrl;
import 'package:notepad/features/search/search_constants.dart';

// Search input bar handles query entry, clear actions, and focus recovery.
class SearchInputFieldBar extends StatelessWidget {
  final search_ctrl.SearchController controller;
  final FocusNode focusNode;

  const SearchInputFieldBar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return TextField(
      onChanged: controller.onQueryChanged,
      controller: controller.textController,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search title or content...',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        suffixIcon: ListenableBuilder(
          listenable: controller.textController,
          builder: (context, _) {
            final text = controller.textController.text;
            if (text.isEmpty) return const SizedBox.shrink();

            return IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.clearQuery();

                final isKeyboardOpen = View.of(context).viewInsets.bottom > 0;
                if (!isKeyboardOpen) {
                  focusNode.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    focusNode.requestFocus();
                  });
                }
              },
            );
          },
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: SearchConstants.searchFieldBorderWidth,
          ),
          borderRadius: BorderRadius.circular(
            SearchConstants.searchFieldRadius,
          ),
        ),
      ),
    );
  }
}
