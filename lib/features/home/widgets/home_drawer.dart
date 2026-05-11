import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/home/widgets/spinning_sync_icon.dart';
import 'package:notepad/features/home/widgets/storage_progress_bar.dart';

class HomeDrawer extends StatelessWidget {
  final HomeController controller;
  final bool isDark;
  final Future<void> Function(Future<void> Function()) handleCloudAction;

  const HomeDrawer({
    super.key,
    required this.controller,
    required this.isDark,
    required this.handleCloudAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 90, right: 16),
      child: Align(
        alignment: Alignment.topRight,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller.authController,
            controller.syncStatusNotifier,
            controller.statusColorNotifier,
          ]),
          builder: (context, _) {
            final user = googleDriveService.currentUser;
            final stats = controller.authController.storageStats;
            return Material(
              elevation: 16,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.65,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // This makes it grow with content
                    children: [
                      _HomeDrawerHeader(
                        isDark: isDark,
                        controller: controller.authController,
                        isSavingNotifier: controller.isSavingNotifier,
                        storageText: stats['text'],
                        storageProgress: stats['percent'],
                        user: user,
                        syncStatusText: controller.syncStatusNotifier.value,
                        statusColor: controller.statusColorNotifier.value,
                      ),
                      const SizedBox(height: UIConstants.paddingSM),
                      _HomeDrawerActions(
                        isDark: isDark,
                        controller: controller.authController,
                        onBackup: () => handleCloudAction(
                          () => controller.runManualBackup(),
                        ),
                        onRestore: () => handleCloudAction(
                          () => controller.runManualRestore(),
                        ),
                        user: user,
                      ),
                      const SizedBox(height: 16),
                    ],
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
    required this.controller,
    required this.isSavingNotifier,
    required this.storageText,
    required this.storageProgress,
    required this.user,
    required this.syncStatusText,
    required this.statusColor,
  });

  final bool isDark;
  final String syncStatusText;
  final Color? statusColor;
  final AuthController controller;
  final ValueNotifier<bool> isSavingNotifier;
  final String storageText;
  final double storageProgress;
  final GoogleSignInAccount? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            user == null ? Icons.cloud_off_outlined : Icons.cloud_done,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            controller.displayName ?? 'Not signed in',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            controller.displayEmail ?? 'Connect Google Drive to sync',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 14),
          StorageProgressBar(progress: storageProgress),
          const SizedBox(height: 8),
          Text(
            storageText,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: isSavingNotifier,
            builder: (context, isSaving, _) {
              return Row(
                children: [
                  if (isSaving)
                    const SpinningSyncIcon()
                  else
                    Icon(
                      Icons.sync,
                      size: 18,
                      color:
                          statusColor ??
                          (isDark ? Colors.white70 : Colors.black54),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    user == null
                        ? 'Cloud sync'
                        : isSaving
                        ? 'Working...'
                        : syncStatusText,
                    style: TextStyle(
                      color:
                          statusColor ??
                          (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              );
            },
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
    required this.user,
  });

  final bool isDark;
  final AuthController controller;
  final Future<void> Function() onBackup;
  final Future<void> Function() onRestore;
  final GoogleSignInAccount? user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          if (user != null) ...[
            _DrawerActionTile(
              icon: Icons.backup_rounded,
              title: 'Backup now',
              subtitle: 'Save notes to Google Drive',
              onTap: onBackup,
              isDark: isDark,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            _DrawerActionTile(
              icon: Icons.restore_rounded,
              title: 'Restore backup',
              subtitle: 'Merge notes from Google Drive',
              onTap: onRestore,
              isDark: isDark,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
          ],
          _DrawerActionTile(
            icon: user == null
                ? Icons.account_circle_outlined
                : Icons.exit_to_app_rounded,

            title: user != null ? 'Sign out' : 'Sign in',
            subtitle: user != null
                ? 'Disconnect this Google account'
                : 'Connect your Google account',
            onTap: () async {
              if (user != null) {
                await controller.logout();
              } else {
                await controller.login();
              }
            },
            isDark: isDark,
            colorScheme: colorScheme,
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
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: isDark ? Colors.white : colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () async {
        await onTap();
      },
    );
  }
}
