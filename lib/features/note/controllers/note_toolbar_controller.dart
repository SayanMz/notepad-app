import 'package:flutter/material.dart';

/// Manages the overlay lifecycles and menu dismissal synchronizations
/// for the nested formatting toolbar.
class NoteToolbarController {
  VoidCallback? _onCloseRequested;
  bool isLocked = false; // The Safety Lock

  void registerMenu(VoidCallback closeLogic) => _onCloseRequested = closeLogic;

  void closeAllMenus() {
    isLocked = true; // Lock immediately on teardown
    _onCloseRequested?.call();
  }

  void dispose() {
    isLocked = false;
    _onCloseRequested = null;
  }
}
