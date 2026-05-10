import 'dart:async';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/core/data/notes_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/note_list.dart';
import 'package:notepad/features/home/widgets/selection_toolbar.dart';
import 'package:notepad/features/home/widgets/spinning_sync_icon.dart';
import 'package:notepad/features/home/widgets/storage_progress_bar.dart';
import 'package:notepad/features/note/note_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  double _storageProgress = 0.45;
  var user = googleDriveService.currentUser;
  String _storageText = 'Sync and protect your data';
  String _syncStatusText = 'Ready to sync';
  Color? _statusColor;
  final AuthController authController = AuthController();
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);

  var isSelectionMode = noteRepository.selectedNotes.isNotEmpty;
  late ScrollController _scrollController;
  late final HomeController _controller;

  final ValueNotifier<bool> _isFabExtended = ValueNotifier(true);
  final ValueNotifier<double> _fabAlignX = ValueNotifier(
    0.0,
  ); // 0.0 = center, 1.0 = end
  Timer? _debounce;

  // --- Delta Tracking Variables ---
  double _accumulatedDelta = 0.0;

  void _updateFabState({required bool extend}) {
    if (_isFabExtended.value == extend) return;
    _isFabExtended.value = extend;
    _fabAlignX.value = extend ? 0.0 : 0.95;
  }

  bool _handleScroll(Notification notification) {
    if (!mounted || isSelectionMode) return false;

    // 1. OVERSCROLL PROTECTION: Ignore physics bounces at edges
    if (notification is ScrollNotification && notification.metrics.outOfRange) {
      _accumulatedDelta = 0.0; // Reset on bounce
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0.0;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double threshold = screenHeight * 0.10; // 10% Threshold
      final double offset = notification.metrics.pixels;

      // 2. ABSOLUTE TOP: Instant expand override
      if (offset <= 10) {
        _accumulatedDelta = 0.0;
        _updateFabState(extend: true);
        return true;
      }

      // 3. DELTA ACCUMULATION
      // If the scroll direction changes (e.g., you were going down, now going up),
      // we reset the accumulator so you have to move a full 10% in the NEW direction.
      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = delta;
      } else {
        _accumulatedDelta += delta;
      }

      // 4. TRIGGER CHECK
      // delta > 0 means scrolling DOWN (pixels increasing)
      if (_accumulatedDelta > threshold) {
        _updateFabState(extend: false);
        _accumulatedDelta = 0.0; // Reset after trigger to prevent double-firing
      }
      // delta < 0 means scrolling UP (pixels decreasing)
      else if (_accumulatedDelta < -threshold) {
        _updateFabState(extend: true);
        _accumulatedDelta = 0.0; // Reset after trigger
      }
    }

    // Reset accumulator when the user stops touching the screen
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedDelta = 0.0;
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _scrollController = ScrollController();

    // 1. Wait for the AuthController to finish its silent sign-in
    authController.initialize().then((_) {
      if (mounted) {
        setState(() {
          // 2. Re-assign the user variable NOW, after init is done
          user = googleDriveService.currentUser;
        });

        // 3. NOW check if they are logged in and fetch the stats
        if (user != null) {
          _updateStorageStats();
        } else {
          // Optional: Reset to 0 if they aren't logged in
          setState(() {
            _storageProgress = 0.0;
            _storageText = 'Offline';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _isSavingNotifier.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _updateStorageStats() async {
    final stats = await googleDriveService.getDetailedStorageUsage();
    if (mounted) {
      setState(() {
        _storageProgress = stats['percent'];
        _storageText = stats['text'];
      });
    }
  }

  Future<void> _handleCloudAction(Future<void> Function() action) async {
    try {
      _isSavingNotifier.value = true;
      await action();
      setState(() {
        _syncStatusText = 'All saved';
        _statusColor = Colors.green; // Set to green on success
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _syncStatusText = 'Ready to sync';
            _statusColor = null; // Revert to default color
          });
        }
      });
    } catch (e) {
      showErrorSnackBar(
        'Operation failed: $e',
        autoHideAfter: UIConstants.saveIndicatorDuration,
      );
      setState(() {
        _syncStatusText = 'Sync failed';
        _statusColor = Colors.redAccent; // Visual feedback for errors
      });
    } finally {
      _isSavingNotifier.value = false;
    }
  }

  void _setSelectionMode(bool enabled) {
    setState(() {
      isSelectionMode = enabled;
    });
    //_controller.toggleSelectionMode(enabled);
  }

  Future<void> _shareSelectedNotesAsHTML() async {
    _isSavingNotifier.value = true;
    await _controller.shareSelectedNotes(context);
    if (mounted) {
      _isSavingNotifier.value = false;
    }
  }

  Future<void> _confirmBulkDelete() async {
    final selectedNotes = noteRepository.selectedNotes;
    final selectedCount = selectedNotes.length;

    if (selectedNotes.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move selected notes to recycle bin?'),
        content: Text(
          selectedCount == 1
              ? 'The selected note will be moved to the recycle bin.'
              : '$selectedCount notes will be moved to the recycle bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    _setSelectionMode(false);
    _controller.deleteSelected(selectedNotes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    user = googleDriveService.currentUser;

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (isSelectionMode) {
          final selectedCount = _controller.selectedNotes.length;

          if (selectedCount > 0) {
            HapticFeedback.mediumImpact();
            noteRepository.clearSelection();
          } else {
            _setSelectionMode(false);
          }
        }
      },
      child: NotificationListener<Notification>(
        onNotification: _handleScroll,
        child: Scaffold(
          key: _scaffoldKey,
          // ... rest of your code remains identical
          backgroundColor: isDark
              ? AppColors.darkScaffold
              : AppColors.lightScaffold,
          endDrawer: _buildFloatingDrawer(isDark, user),
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  HomeAppBar(
                    isDark: isDark,
                    isSavingNotifier: _isSavingNotifier,
                    fadeRoute: AppRouter.fade,
                    slideRoute: AppRouter.slide,
                    onOpenDrawer: () =>
                        _scaffoldKey.currentState?.openEndDrawer(),
                  ),

                  NoteList(
                    isSelectionMode: isSelectionMode,
                    isSavingNotifier: _isSavingNotifier,
                    onOpenNote: (noteId) =>
                        _controller.openNote(context, noteId: noteId),
                    onTogglePin: (noteId) async =>
                        _controller.togglePin(noteId),
                    onShare: _shareSelectedNotesAsHTML,
                    onDeleteSelected: _confirmBulkDelete,
                    onSelectionToggle: () {
                      setState(() {
                        isSelectionMode = !isSelectionMode;
                      });
                    },
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: isSelectionMode ? 140.0 : 100.0),
                  ),
                ],
              ),

              _buildSelectionToolbar(),
              _buildFloatingActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDrawer(bool isDark, GoogleSignInAccount? user) {
    return Container(
      margin: const EdgeInsets.only(top: 90, right: 16),
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
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
                    authController: authController,
                    isSavingNotifier: _isSavingNotifier,
                    storageText: _storageText,
                    storageProgress: _storageProgress,
                    user: user,
                    syncStatusText: _syncStatusText,
                    statusColor: _statusColor,
                  ),
                  const SizedBox(height: UIConstants.paddingSM),
                  _HomeDrawerActions(
                    isDark: isDark,
                    authController: authController,
                    onBackup: () =>
                        _handleCloudAction(() => _controller.runManualBackup()),
                    onRestore: () => _handleCloudAction(
                      () => _controller.runManualRestore(),
                    ),
                    user: user,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([_isFabExtended, _fabAlignX]),
        builder: (context, _) {
          final bool isExtended = _isFabExtended.value;
          final double alignX = _fabAlignX.value;

          return AnimatedAlign(
            // 500ms provides a smooth 'glide' across your monitor
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            // Selection mode slides it off-screen (1.5), otherwise follows alignX
            alignment: Alignment(
              alignX == 0.0 ? 0.0 : 0.95,
              isSelectionMode ? 1.5 : 0.95,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fade,
                transitionDuration: UIConstants.animationExtraSlow,
                openColor: Theme.of(context).scaffoldBackgroundColor,
                closedColor: Colors.transparent,
                // Hide elevation when selection mode is active
                closedElevation: isSelectionMode
                    ? 0
                    : UIConstants.elevationHigh,
                closedBuilder: (context, openContainer) => InkWell(
                  onTap: openContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 60,
                    width: isExtended ? 140 : 65.0,
                    // Adjust padding to maintain the circular/rectangular shape
                    padding: EdgeInsets.symmetric(
                      horizontal: isExtended ? 20 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, color: Colors.white),
                        // AnimatedSize handles the 'New Note' text appearing/disappearing
                        if (isExtended)
                          Flexible(
                            // Wrap in Flexible to prevent Row overflow errors
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: FittedBox(
                                child: const Text(
                                  'New Note',
                                  maxLines: 1, // Ensure text stays on one line
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                openBuilder: (context, _) => const NotePage(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: !isSelectionMode,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          offset: isSelectionMode ? Offset.zero : const Offset(0, 1.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isSelectionMode ? 1.0 : 0.0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 24.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: ListenableBuilder(
                          listenable: noteRepository,
                          builder: (context, _) {
                            return SelectionToolbar(
                              isDark: isDark,
                              allSelected:
                                  noteRepository.areAllActiveNotesSelected,
                              onSelectAll: (val) => noteRepository
                                  .setSelectAllForAllActiveNotes(val),
                              onShare: _shareSelectedNotesAsHTML,
                              onDelete: _confirmBulkDelete,
                              onColorChanged: (color) => noteRepository
                                  .updateColorForSelectedNotes(color),
                              onPin: () => _controller.togglePinBulk(),
                              shouldPin: _controller.showPinAction,
                              selectedCount: _controller.selectedNotes.length,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
    valueListenable: first,
    builder: (context, a, _) => ValueListenableBuilder<B>(
      valueListenable: second,
      builder: (context, b, _) => builder(context, a, b, null),
    ),
  );
}

class _HomeDrawerHeader extends StatelessWidget {
  const _HomeDrawerHeader({
    required this.isDark,
    required this.authController,
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
  final AuthController authController;
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
            authController.displayName ?? 'Not signed in',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            authController.displayEmail ?? 'Connect Google Drive to sync',
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
    required this.authController,
    required this.onBackup,
    required this.onRestore,
    required this.user,
  });

  final bool isDark;
  final AuthController authController;
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
            icon: authController.isAuthenticated
                ? Icons.exit_to_app_rounded
                : Icons.account_circle_outlined,

            title: authController.isAuthenticated ? 'Sign out' : 'Sign in',
            subtitle: authController.isAuthenticated
                ? 'Disconnect this Google account'
                : 'Connect your Google account',
            onTap: () async {
              if (authController.isAuthenticated) {
                await authController.logout();
              } else {
                await authController.login();
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
