// Toolbar state stays separate from the editor so formatting stays testable.
import 'package:flutter/material.dart';

// Toolbar state lives here so formatting actions stay decoupled from the editor widget.
class NoteToolbarController {
  final List<VoidCallback> _closeCallbacks = [];

  void register(VoidCallback closeLogic) => _closeCallbacks.add(closeLogic);

  void unregister(VoidCallback closeLogic) =>
      _closeCallbacks.remove(closeLogic);

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
    required this.menuController,
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

