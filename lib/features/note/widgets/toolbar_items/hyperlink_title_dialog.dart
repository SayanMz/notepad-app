import 'package:flutter/material.dart';

/// A specialized dialog that captures the display text for a hyperlink.
/// Returns the entered string or null if the user cancels.
Future<String?> showHyperlinkTitleDialog(BuildContext context) {
  final textController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter Hyperlink Title'),
      content: TextField(
        controller: textController,
        decoration: const InputDecoration(
          hintText: 'e.g., Google or My Website',
        ),
        autofocus: true, // Automatically opens the keyboard
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, textController.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
