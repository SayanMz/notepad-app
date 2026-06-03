import 'package:flutter/material.dart';

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
        autofocus: true,
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
