import 'package:flutter/material.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/controllers/sync_controller.dart';
import 'package:notepad/features/home/widgets/drawer_items/spinning_sync_icon.dart';
import 'package:notepad/features/home/widgets/drawer_items/storage_progress_bar.dart';
import 'package:notepad/core/extensions/context_extensions.dart';

// Drawer area for cloud sync status, account actions, and storage progress.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.authController,
    required this.syncController,
  });

  final AuthController authController;
  final SyncController syncController;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      margin: const EdgeInsets.only(
        top: HomeConstants.drawerMarginTop,
        right: HomeConstants.drawerMarginRight,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: ListenableBuilder(
          listenable: Listenable.merge([authController, syncController]),
          builder: (context, _) {
            return Material(
              elevation: HomeConstants.drawerElevation,
              color: isDark ? AppColors.homeDrawerSurface : Colors.white,
              borderRadius: BorderRadius.circular(
                HomeConstants.drawerBorderRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width:
                    context.screenSize.width * HomeConstants.drawerWidthFactor,
                constraints: BoxConstraints(
                  maxHeight:
                      context.screenSize.height *
                      HomeConstants.drawerMaxHeightFactor,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    return true;
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HomeDrawerHeader(
                          isDark: isDark,
                          authController: authController,
                          syncController: syncController,
                        ),
                        const SizedBox(height: UIConstants.paddingSM),
                        _HomeDrawerActions(
                          isDark: isDark,
                          controller: authController,
                          onBackup: () => syncController.executeBackup(),
                          onRestore: () => syncController.executeRestore(),
                        ),
                        const SizedBox(
                          height: HomeConstants.drawerHeaderSectionGap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeDrawerHeader extends StatelessWidget {
  const _HomeDrawerHeader({
    required this.isDark,
    required this.authController,
    required this.syncController,
  });

  final bool isDark;
  final AuthController authController;
  final SyncController syncController;

  @override
  Widget build(BuildContext context) {
    final stats = authController.storageStats;
    final bool isLoggedIn = authController.isAuthenticated;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        HomeConstants.drawerHeaderPaddingH,
        HomeConstants.drawerHeaderPaddingT,
        HomeConstants.drawerHeaderPaddingH,
        HomeConstants.drawerHeaderPaddingB,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLoggedIn ? Icons.cloud_done : Icons.cloud_off_outlined,
            size: HomeConstants.drawerIconSize,
          ),
          const SizedBox(height: HomeConstants.drawerHeaderSectionGap),
          Text(
            authController.displayName ?? 'Not signed in',
            style: TextStyle(
              fontSize: HomeConstants.drawerHeaderTitleFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HomeConstants.drawerHeaderTightGap),
          Text(
            authController.displayEmail ?? 'Connect Google Drive to sync',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: HomeConstants.drawerHeaderBlockGap),
          StorageProgressBar(progress: stats['percent']),
          const SizedBox(height: HomeConstants.drawerSectionGap),
          Text(
            stats['text'],
            style: TextStyle(
              fontSize: HomeConstants.drawerHeaderStatusFontSize,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: HomeConstants.drawerHeaderSectionGap),
          Row(
            children: [
              if (syncController.isSaving)
                const SpinningSyncIcon()
              else
                Icon(
                  Icons.sync,
                  size: 18,
                  color:
                      syncController.statusColor ??
                      (isDark ? Colors.white70 : Colors.black54),
                ),
              const SizedBox(width: UIConstants.paddingSM),
              Text(
                !isLoggedIn
                    ? 'Cloud sync'
                    : syncController.isSaving
                    ? 'Working...'
                    : syncController.statusText,
                style: TextStyle(
                  color:
                      syncController.statusColor ??
                      (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeDrawerActions extends StatelessWidget {
  const _HomeDrawerActions({
    required this.isDark,
    required this.controller,
    required this.onBackup,
    required this.onRestore,
  });

  final bool isDark;
  final AuthController controller;
  final Future<void> Function() onBackup;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = controller.isAuthenticated;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeConstants.drawerActionsPaddingH,
      ),
      child: Column(
        children: [
          if (isLoggedIn) ...[
            _DrawerActionTile(
              icon: Icons.backup_rounded,
              title: 'Backup now',
              subtitle: 'Save notes to Google Drive',
              onTap: onBackup,
              isDark: isDark,
            ),
            const SizedBox(height: HomeConstants.drawerSectionGap),
            _DrawerActionTile(
              icon: Icons.restore_rounded,
              title: 'Restore backup',
              subtitle: 'Merge notes from Google Drive',
              onTap: onRestore,
              isDark: isDark,
            ),
            const SizedBox(height: HomeConstants.drawerSectionGap),
          ],
          _DrawerActionTile(
            icon: isLoggedIn
                ? Icons.exit_to_app_rounded
                : Icons.account_circle_outlined,
            title: isLoggedIn ? 'Sign out' : 'Sign in',
            subtitle: isLoggedIn
                ? 'Disconnect this Google account'
                : 'Connect your Google account',
            onTap: () async {
              if (isLoggedIn) {
                await controller.logout();
              } else {
                await controller.login();
              }
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HomeConstants.drawerActionRadius),
      ),
      leading: Icon(
        icon,
        color: isDark ? Colors.white : context.colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () async {
        await onTap();
      },
    );
  }
}
