import 'package:flutter/material.dart';

/// Manages the overlay lifecycles and menu dismissal synchronizations
/// for the nested formatting toolbar.
class NoteToolbarController {
  // Use a list to track multiple registered close callbacks
  final List<VoidCallback> _closeCallbacks = [];

  // Register a menu's close logic
  void register(VoidCallback closeLogic) => _closeCallbacks.add(closeLogic);

  // Remove logic when a menu is disposed
  void unregister(VoidCallback closeLogic) =>
      _closeCallbacks.remove(closeLogic);

  // Close everything currently open
  void closeAllMenus() {
    for (final close in List.of(_closeCallbacks)) {
      close();
    }
  }

  void dispose() {
    _closeCallbacks.clear();
  }
}

class ToolbarMenuWrapper extends StatefulWidget {
  const ToolbarMenuWrapper({
    super.key,
    required this.toolbarController,
    required this.menuController, // Hoisted controller
    required this.child,
  });

  final NoteToolbarController toolbarController;
  final MenuController menuController;
  final Widget child;

  @override
  State<ToolbarMenuWrapper> createState() => _ToolbarMenuWrapperState();
}

class _ToolbarMenuWrapperState extends State<ToolbarMenuWrapper> {
  void _close() {
    if (widget.menuController.isOpen) widget.menuController.close();
  }

  @override
  void initState() {
    super.initState();
    widget.toolbarController.register(_close);
  }

  @override
  void dispose() {
    widget.toolbarController.unregister(_close);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
