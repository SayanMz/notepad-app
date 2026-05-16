import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/recycle_page.dart';
import 'package:notepad/features/search/search_page.dart';
import 'package:notepad/core/services/context_extensions.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.isDark,
    required this.isSavingNotifier,
    required this.fadeRoute,
    required this.slideRoute,
    required this.onOpenDrawer,
  });

  final bool isDark;
  final ValueNotifier<bool> isSavingNotifier;
  final Route Function(Widget) fadeRoute;
  final Route Function(Widget) slideRoute;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: false,
      stretch: true,
      automaticallyImplyLeading: false,
      actions: const [SizedBox.shrink()],
      scrolledUnderElevation: 1.5,
      shadowColor: Colors.transparent,
      surfaceTintColor: const Color(0xFFB8E6DD),
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.of(context).padding.top;
          final standardHeight = kToolbarHeight + topPadding;
          final isOverscrolled = constraints.maxHeight > standardHeight + 15;

          return FlexibleSpaceBar(
            background: Stack(
              children: [
                AnimatedOpacity(
                  opacity: isOverscrolled ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: isOverscrolled,
                    child: SafeArea(
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                final currentIsDark =
                                    appSettingsRepository.settings.isDarkMode;
                                await appSettingsRepository.update(
                                  appSettingsRepository.settings.copyWith(
                                    isDarkMode: !currentIsDark,
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.light,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notepad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.search,
                                size: UIConstants.iconMD,
                                color: isDark
                                    ? Colors.white
                                    : colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () async {
                                uiNotifier.clearSnackBars();
                                await Navigator.push(
                                  context,
                                  fadeRoute(const SearchPage()),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.restore_from_trash,
                                size: UIConstants.iconMD,
                                color: isDark
                                    ? Colors.white
                                    : colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () async {
                                uiNotifier.clearSnackBars();
                                await Navigator.push(
                                  context,
                                  slideRoute(const RecyclePage()),
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                return IconButton(
                                  icon: const Icon(Icons.sort),
                                  color: isDark
                                      ? Colors.white
                                      : colorScheme.onSurfaceVariant,
                                  onPressed: onOpenDrawer,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isOverscrolled ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: SafeArea(
                    child: RepaintBoundary(
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 56.0),
                        child: Text(
                          'Notepad',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
