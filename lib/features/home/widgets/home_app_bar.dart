import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/services/ui_management/theme_fader.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/search/search_page.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/core/services/ui_management/app_router.dart';
import 'package:notepad/features/trash/recycle_page.dart';

// Top home bar with search, trash, theme toggle, and drawer access.
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.onOpenDrawer});
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return SliverAppBar(
      floating: true,
      stretch: true,
      automaticallyImplyLeading: false,
      actions: const [SizedBox.shrink()],
      scrolledUnderElevation: HomeConstants.appBarScrolledUnderElevation,
      surfaceTintColor: HomeConstants.appBarSurfaceTint,
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = context.topPadding;
          final standardHeight = kToolbarHeight + topPadding;

          final double overscrollDelta = constraints.maxHeight - standardHeight;

          final double stretchProgress =
              (overscrollDelta / HomeConstants.appBarOverscrollThreshold).clamp(
                0.0,
                1.0,
              );

          final double toolbarOpacity = (1.0 - (stretchProgress * 2.0)).clamp(
            0.0,
            1.0,
          );
          final double largeTitleOpacity = ((stretchProgress - 0.5) * 2.0)
              .clamp(0.0, 1.0);

          return Stack(
            children: [
              Opacity(
                opacity: toolbarOpacity,
                child: IgnorePointer(
                  ignoring: toolbarOpacity == 0.0,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            ThemeFader.captureAndFade(
                              context: context,
                              executeThemeSwap: () async {
                                final currentIsDark =
                                    appSettingsRepository.settings.isDarkMode;
                                await appSettingsRepository.update(
                                  appSettingsRepository.settings.copyWith(
                                    isDarkMode: !currentIsDark,
                                  ),
                                );
                              },
                            );
                          },
                          icon: Icon(
                            Icons.light,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: UIConstants.paddingSM),
                        Text(
                          'Notepad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: HomeConstants.appBarTitleFontSize,
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
                              AppRouter.sharedAxis(const SearchPage()),
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
                              AppRouter.slide(const RecyclePage()),
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

              Opacity(
                opacity: largeTitleOpacity,
                child: IgnorePointer(
                  ignoring: largeTitleOpacity == 0.0,
                  child: SafeArea(
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(
                        bottom: HomeConstants.appBarExpandedBottomPadding,
                      ),
                      child: Text(
                        'Notepad',
                        style: TextStyle(
                          fontSize: HomeConstants.appBarExpandedTitleFontSize,
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
          );
        },
      ),
    );
  }
}
