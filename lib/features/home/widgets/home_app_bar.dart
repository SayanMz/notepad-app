import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/services/ui_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/recycle_page.dart';
import 'package:notepad/features/search/search_page.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.isDark,
    required this.isSavingNotifier,
    required this.fadeRoute,
  });

  final bool isDark;
  final ValueNotifier<bool> isSavingNotifier;
  final Route Function(Widget) fadeRoute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: false,
      stretch: true,

      // CRITICAL: Turns off default back buttons so we have 100% control
      automaticallyImplyLeading: false,
      actions: const [SizedBox.shrink()],

      scrolledUnderElevation: 1.5,
      shadowColor: Colors.transparent,
      surfaceTintColor: const Color(0xFFB8E6DD),
      backgroundColor: isDark
          ? AppColors.darkScaffold
          : Theme.of(context).scaffoldBackgroundColor,

      /// EVERYTHING is now inside the flexible space!
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.of(context).padding.top;
          final standardHeight = kToolbarHeight + topPadding;

          final isOverscrolled = constraints.maxHeight > standardHeight + 15;

          return FlexibleSpaceBar(
            background: Stack(
              children: [
                /// ==========================================
                /// IMAGE A: THE STANDARD APP BAR (Fades OUT)
                /// ==========================================
                AnimatedOpacity(
                  opacity: isOverscrolled ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  // IgnorePointer prevents you from accidentally tapping
                  // the invisible icons when stretched!
                  child: IgnorePointer(
                    ignoring: isOverscrolled,
                    child: SafeArea(
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            // 1. Theme Toggle (Old Leading)
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

                            // 2. Standard Title
                            const SizedBox(width: 8),
                            Text(
                              'Notepad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),

                            const Spacer(), // Pushes everything else to the right!
                            // 3. Search Action
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

                            // 4. Recycle Bin Action
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
                                  fadeRoute(const RecyclePage()),
                                );
                              },
                            ),

                            // 5. Drawer Action
                            Builder(
                              builder: (context) {
                                return IconButton(
                                  icon: const Icon(Icons.sort),
                                  color: isDark
                                      ? Colors.white
                                      : colorScheme.onSurfaceVariant,
                                  onPressed: () {
                                    Scaffold.of(context).openEndDrawer();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                /// ==========================================
                /// IMAGE B: MASSIVE OVERSCROLL LOGO (Fades IN)
                /// ==========================================
                AnimatedOpacity(
                  opacity: isOverscrolled ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: SafeArea(
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(
                        bottom: 56.0,
                      ), //56 looks like branded
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
              ],
            ),
          );
        },
      ),
    );
  }
}
