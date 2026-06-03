// Empty search states explain whether the user has searched yet or just found no match.
import 'package:flutter/material.dart';
import 'package:notepad/features/filter/search_constants.dart';

// Empty search states explain whether the query matched nothing or has not run yet.
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
              color: Colors.grey[500],
            ),
            const SizedBox(height: SearchConstants.emptyTitleGap),
            FittedBox(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: SearchConstants.emptyTitleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: SearchConstants.emptySubtitleGap),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

