import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter/services.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/home_drawer.dart';
import 'package:notepad/features/home/widgets/home_fab.dart';
import 'package:notepad/features/home/widgets/note_list.dart';
import 'package:notepad/features/home/widgets/selection_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late ScrollController _scrollController;
  late final HomeController _controller;

  bool _handleScroll(Notification notification) {
    if (!mounted) return false;

    return _controller.handleFabScroll(notification);
  }

  ScrollPhysics get _getScrollPhysics {
    if (_controller.activeNotes.isEmpty) {
      return const NeverScrollableScrollPhysics();
    }
    if (_controller.selectionController.isSelectionMode) {
      return const AlwaysScrollableScrollPhysics();
    }
    return const BouncingScrollPhysics();
  }

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return PopScope(
          canPop: !_controller.selectionController.isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            if (_controller.selectionController.isSelectionMode) {
              final selectedCount =
                  _controller.selectionController.selectionCount;

              if (selectedCount > 0) {
                HapticFeedback.mediumImpact();
                _controller.selectionController.clearSelection();
              } else {
                _controller.selectionController.exitSelectionMode();
              }
            }
          },
          child: NotificationListener<Notification>(
            onNotification: _handleScroll,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: isDark
                  ? AppColors.darkScaffold
                  : AppColors.lightScaffold,
              endDrawer: HomeDrawer(controller: _controller),
              body: Stack(
                children: [
                  SafeArea(
                    child: CustomScrollView(
                      controller: _scrollController,
                      key: ValueKey(_controller.activeNotes.isEmpty),
                      physics: _getScrollPhysics,
                      cacheExtent: context.screenSize.height * 0.40,
                      slivers: [
                        HomeAppBar(
                          onOpenDrawer: () =>
                              _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        NoteList(controller: _controller),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            bottom:
                                _controller.selectionController.isSelectionMode
                                ? 90
                                : 80,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SelectionOverlay(
                    controller: _controller,
                    selectionController: _controller.selectionController,
                  ),
                  HomeFab(
                    controller: _controller,
                    selectionController: _controller.selectionController,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
