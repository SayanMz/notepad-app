import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/search_constants.dart';

// Empty search states explain whether the user has searched yet or just found no match.
class SearchInitialState extends StatelessWidget {
  const SearchInitialState({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchMessage(
      title: 'Search your notes by title or content',
      subtitle: 'Type a keyword or use the filter to find notes.',
      icon: Icons.manage_search_rounded,
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context) {
    final title = query.isNotEmpty
        ? 'No notes matched "$query"'
        : 'No notes matched your filters';

    return SearchMessage(
      title: title,
      subtitle: 'Try a shorter phrase or adjust your selection.',
      icon: Icons.search_off_rounded,
    );
  }
}

class SearchMessage extends StatelessWidget {
  const SearchMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SearchConstants.emptyHorizontalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: SearchConstants.emptyIconSize,
              color: AppColors.searchResultSubtitleDark,
            ),
            const SizedBox(height: SearchConstants.emptyTitleGap),
            FittedBox(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SearchConstants.emptyTitleFontSize,
                  fontWeight: FontWeight.w600,
                  color: context.isDark ? AppColors.searchResultTitleDark : AppColors.searchResultTitleLight,
                ),
              ),
            ),
            const SizedBox(height: SearchConstants.emptySubtitleGap),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.searchResultSubtitleLight),
            ),
          ],
        ),
      ),
    );
  }
}

