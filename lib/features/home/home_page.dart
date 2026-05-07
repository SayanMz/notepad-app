import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'package:notepad/features/home/services/auth_controller.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/selection_toolbar.dart';
import 'package:notepad/features/home/widgets/spinning_sync_icon.dart';
import 'package:notepad/features/home/widgets/storage_progress_bar.dart';
import 'package:notepad/features/note/data/note_repository.dart';
import 'package:notepad/features/home/services/app_router.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/note_list.dart';
import 'package:notepad/features/note/note_page.dart';
import 'package:animations/animations.dart';

/// ---------------------------------------------------------------------------
/// HOME PAGE (ROOT DASHBOARD)
/// ---------------------------------------------------------------------------
///
/// ROLE IN ARCHITECTURE:
/// - Acts as the primary orchestration layer for the notes feature
/// - Coordinates between:
///     • UI (widgets)
///     • Data (repositories)
///     • Services (recovery, export, etc.)
///
/// RESPONSIBILITIES:
/// - Render note list via composition (NoteList)
/// - Handle selection mode lifecycle
/// - Trigger navigation flows
/// - Coordinate recovery + async operations
///
/// DESIGN PRINCIPLES USED:
/// - Separation of concerns (UI split into widgets)
/// - Repository-driven state (single source of truth)
/// - Minimal local state (only UI concerns)
///
/// INTERVIEW NOTE:
/// This is a “thin orchestration layer” — not a business logic container.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Internal state for HomePage.
///
/// Contains ONLY:
/// - UI-level state (selection mode)
/// - Async indicators
/// - Lifecycle hooks (init/dispose)
class _HomePageState extends State<HomePage> {
  double _storageProgress = 0.0;
  var user = googleDriveService.currentUser;
  String _storageText = 'Sync and protect your data';

  /// Tracks whether selection mode is active.
  ///
  /// NOTE:
  /// This is derived from repository state, but kept locally for UI toggling.
  /// (Could be fully derived in future refactor)
  var isSelectionMode = noteRepository.selectedNotes.isNotEmpty;

  late ScrollController _scrollController;
  // bool _isFabVisible = true;
  final ValueNotifier<bool> _isFabVisible = ValueNotifier(true);

  /// Local snapshot used ONLY during recovery flow.
  ///
  final activeNotes = noteRepository.activeNotes;
  late final HomeController _controller;

  /// Controls async UI feedback (e.g., export/share loading indicator).
  ///
  /// DESIGN:
  /// - Lightweight alternative to full state management
  /// - Scoped to UI-only async operations
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);

  /// -------------------------------------------------------------------------
  /// LIFECYCLE: INIT
  /// -------------------------------------------------------------------------
  ///
  /// Checks for crash recovery data at startup.
  ///
  AuthController authController = AuthController();

  @override
  void initState() {
    super.initState();
    authController.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _controller = HomeController();
    _scrollController = ScrollController();
    if (user != null) {
      _updateStorageStats();
    }

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isFabVisible.value) _isFabVisible.value = false;
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_isFabVisible.value) _isFabVisible.value = true;
      }
    });
  }

  /// -------------------------------------------------------------------------
  /// LIFECYCLE: DISPOSE
  /// -------------------------------------------------------------------------
  ///
  /// Cleans up ValueNotifier to prevent memory leaks.
  @override
  void dispose() {
    _isSavingNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Toggles selection mode.
  ///
  /// SIDE EFFECT:
  /// - Clears repository selection when exiting mode
  void _setSelectionMode(bool enabled) {
    setState(() {
      isSelectionMode = enabled;
    });
    _controller.toggleSelectionMode(enabled);
    // if (!enabled) {
    //   noteRepository.clearSelection();
    // }
  }

  /// Shares selected notes as HTML.
  ///
  /// UX:
  /// - Shows loading indicator via ValueNotifier
  /// - Handles errors gracefully
  Future<void> _shareSelectedNotesAsHTML() async {
    _isSavingNotifier.value = true;

    await _controller.shareSelectedNotes(context);

    if (mounted) {
      _isSavingNotifier.value = false;
    }
  }

  /// Handles bulk delete with confirmation + undo.
  ///
  /// UX PATTERN:
  /// - Confirmation dialog
  /// - Snackbar with restore option
  Future<void> _confirmBulkDelete() async {
    final selectedNotes = noteRepository.selectedNotes;

    if (selectedNotes.isEmpty) return;

    final selectedCount = selectedNotes.length;

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

    await _controller.deleteSelected(selectedNotes);
  }

  Future<void> _updateStorageStats() async {
    final stats = await googleDriveService.getDetailedStorageUsage();
    if (mounted) {
      setState(() {
        // This fills your blue progress bar
        _storageProgress = stats['percent'];
        // This fills your text label
        _storageText = stats['text'];
      });
    }
  }

  /// -------------------------------------------------------------------------
  /// BUILD METHOD
  /// -------------------------------------------------------------------------
  ///
  /// Composes UI using extracted widgets.
  ///
  /// DESIGN:
  /// - Thin UI layer
  /// - Delegates heavy UI to NoteList
  /// - AppBar isolated (no rebuild dependency)
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    user = googleDriveService.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      /// Prevents exit through system back navigation during selection mode for 1st time
      canPop: !isSelectionMode,

      /// Back button exits selection mode instead of leaving page
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isSelectionMode) {
          _setSelectionMode(false);
        }
      },

      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkScaffold
            : AppColors.lightScaffold,

        /// AppBar is isolated widget (better performance)
        endDrawer: Container(
          margin: EdgeInsets.only(top: 90),
          child: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.50,
              width: MediaQuery.of(context).size.width * 0.50, // Standard width
              child: ListenableBuilder(
                listenable: authController,
                builder: (BuildContext context, Widget? child) {
                  final bool isAuth = authController.isAuthenticated;
                  final stats = authController.storageStats;
                  final firstName =
                      authController.displayName?.split(' ').first ?? 'User';
                  final normalizedUserName =
                      "Hello, ${firstName.toUpperCase()}";
                  return Drawer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(UIConstants.paddingLG),
                          color: !isDark
                              ? Theme.of(context).colorScheme.primaryContainer
                              : AppColors.darkScaffold,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                //User profile picture
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          isAuth &&
                                              authController.avatarUrl != null
                                          ? NetworkImage(
                                              authController.avatarUrl!,
                                            )
                                          : null,
                                      child:
                                          !isAuth ||
                                              authController.avatarUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 45,
                                              color: Colors.grey,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(
                                      height: UIConstants.paddingSM,
                                    ),
                                    //User name
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isAuth
                                            ? normalizedUserName
                                            : 'Cloud Sync',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: UIConstants.paddingXS,
                                    ),
                                    //Storage space in text

                                    //Storage space in %
                                    ///Hide this if the user hasn't logged in yet.
                                    // Inside the Drawer Column, replace the storage space section:
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _isSavingNotifier,
                                      builder: (context, isSaving, _) {
                                        return Column(
                                          children: [
                                            Text(
                                              isSaving
                                                  ? 'Syncing with cloud...'
                                                  : (isAuth
                                                        ? stats['text']
                                                        : 'Sign in to securely backup your notes'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            if (isAuth)
                                              SizedBox(
                                                width: 170,
                                                height: 30,
                                                child: isSaving
                                                    ? const SpinningSyncIcon() // Show spinner during active work[cite: 15]
                                                    : StorageProgressBar(
                                                        progress:
                                                            stats['percent'],
                                                        color: Colors
                                                            .lightBlueAccent,
                                                      ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(
                                      height: UIConstants.paddingXS,
                                    ),
                                  ],
                                ),
                              ), // Prep for Firebase
                            ],
                          ),
                        ),
                        const SizedBox(height: UIConstants.paddingSM),
                        ListTile(
                          leading: Icon(isAuth ? Icons.backup : Icons.login),
                          title: Text(
                            isAuth
                                ? 'Backup to Cloud'
                                : "Sign in with Google Drive",
                          ),
                          onTap: () async {
                            if (!isAuth) return authController.login();

                            // 1. CAPTURE CONTEXT VARIABLES BEFORE ASYNC GAP
                            final messenger = ScaffoldMessenger.of(context);
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;

                            try {
                              _isSavingNotifier.value = true;
                              await _controller.runManualBackup();

                              // 2. USE CAPTURED MESSENGER
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup successful!',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.green.shade100
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: isDark
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.green.shade100,
                                  behavior: SnackBarBehavior.floating,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: isDark
                                        ? BorderSide(
                                            color: Colors.green.withValues(
                                              alpha: 0.5,
                                            ),
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup failed: $e',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.red.shade100
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: isDark
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.red.shade100,
                                  behavior: SnackBarBehavior.floating,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: isDark
                                        ? BorderSide(
                                            color: Colors.red.withValues(
                                              alpha: 0.5,
                                            ),
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                              );
                            } finally {
                              _isSavingNotifier.value = false;
                            }
                          },
                        ),
                        if (isAuth)
                          ListTile(
                            leading: const Icon(Icons.download),
                            title: const Text('Restore from Cloud'),
                            onTap: () async {
                              if (!isAuth) return authController.login();

                              // 1. CAPTURE CONTEXT VARIABLES BEFORE ASYNC GAP
                              final messenger = ScaffoldMessenger.of(context);
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;

                              try {
                                _isSavingNotifier.value = true;
                                await _controller.runManualRestore();

                                // 2. USE CAPTURED MESSENGER
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Restore successful! Notes updated.',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.green.shade100
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.green.shade100,
                                    behavior: SnackBarBehavior.floating,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: isDark
                                          ? BorderSide(
                                              color: Colors.green.withValues(
                                                alpha: 0.5,
                                              ),
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Restore failed: $e',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.red.shade100
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : Colors.red.shade100,
                                    behavior: SnackBarBehavior.floating,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: isDark
                                          ? BorderSide(
                                              color: Colors.red.withValues(
                                                alpha: 0.5,
                                              ),
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                );
                              } finally {
                                _isSavingNotifier.value = false;
                              }
                            },
                          ),

                        const Spacer(),
                        if (isAuth)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () => authController.logout(),
                                child: const Text(
                                  'Sign Out',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        /// Main content delegated to NoteList
        /// Main content now wrapped in a Stack to allow floating UI
        body: Stack(
          children: [
            // --- 1. THE SCROLLING LAYER (Background) ---
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
                ),
                NoteList(
                  isSelectionMode: isSelectionMode,
                  isSavingNotifier: _isSavingNotifier,
                  onOpenNote: (noteId) =>
                      _controller.openNote(context, noteId: noteId),
                  onTogglePin: (noteId) => _controller.togglePin(noteId),
                  onShare: _shareSelectedNotesAsHTML,
                  onDeleteSelected: _confirmBulkDelete,
                  onSelectionToggle: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                    });
                  },
                ),
                // IMPORTANT: This invisible spacer ensures the very last note
                // can be scrolled high enough to be seen above the floating toolbar!
                SliverToBoxAdapter(
                  child: SizedBox(height: isSelectionMode ? 140.0 : 100.0),
                ),
              ],
            ),

            // --- 2. THE FLOATING HUD LAYER (Foreground) ---
            // --- 2. THE FLOATING HUD LAYER (Foreground) ---
            Align(
              alignment: Alignment.bottomCenter,
              // 1. IgnorePointer prevents the invisible toolbar from blocking taps
              child: IgnorePointer(
                ignoring: !isSelectionMode,
                // 2. AnimatedSlide controls the vertical popup motion
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic, // A snappy, premium deceleration
                  // Offset(0, 1.5) means push it 150% of its own height downwards
                  offset: isSelectionMode ? Offset.zero : const Offset(0, 1.5),
                  // 3. AnimatedOpacity fades it in as it slides up
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
                                      allSelected: noteRepository
                                          .areAllActiveNotesSelected,
                                      onSelectAll: (val) => noteRepository
                                          .setSelectAllForAllActiveNotes(val),
                                      onShare: _shareSelectedNotesAsHTML,
                                      onDelete: _confirmBulkDelete,
                                      onColorChanged: (color) => noteRepository
                                          .updateColorForSelectedNotes(color),
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
            ),
          ],
        ),

        /// FAB hidden during selection mode
        /// FAB logic upgraded to match the sliding toolbar choreography
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _isFabVisible,
          builder: (context, isVisible, child) {
            // The FAB should only show if we are NOT in selection mode
            // AND the user hasn't scrolled it away.
            final shouldShowFab = !isSelectionMode && isVisible;

            // 1. Match the Toolbar's exact slide physics
            return AnimatedSlide(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              offset: shouldShowFab
                  ? Offset.zero
                  : const Offset(0, 1.5), // Slide down
              // 2. Match the Toolbar's fade physics
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: shouldShowFab ? 1.0 : 0.0,
                // 3. Prevent ghost taps while hidden
                child: IgnorePointer(
                  ignoring: !shouldShowFab,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: UIConstants.paddingXS,
                    ),
                    child: OpenContainer(
                      transitionType: ContainerTransitionType.fade,
                      transitionDuration: UIConstants.animationExtraSlow,
                      openColor: Theme.of(context).scaffoldBackgroundColor,
                      closedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      closedElevation: UIConstants.elevationHigh,
                      closedShape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(UIConstants.radiusLG),
                        ),
                      ),
                      closedBuilder: (context, openContainer) =>
                          FloatingActionButton.extended(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            onPressed: openContainer,
                            icon: const Icon(Icons.add),
                            label: const Text(
                              'New Note',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      openBuilder: (context, _) => const NotePage(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ), // End of Scaffold
    ); // End of PopScope
  }
}

/// ---------------------------------------------------------------------------
/// INTERVIEW NOTES
/// ---------------------------------------------------------------------------
///
/// Key talking points:
///
/// 1. Architecture:
///    - "I decomposed a large UI into smaller reusable widgets"
///    - "HomePage acts as an orchestration layer, not a logic container"
///
/// 2. State Management:
///    - "I rely on repository as single source of truth"
///    - "UI only holds transient state (selection mode, loading)"
///
/// 3. UX:
///    - Undo delete (Snackbar)
///    - Crash recovery system
///    - Selection mode with bulk actions
///
/// 4. Scalability:
///    - Centralized routing (AppRouter)
///    - Service layer separation
