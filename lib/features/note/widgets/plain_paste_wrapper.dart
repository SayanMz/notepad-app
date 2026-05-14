import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

class PlainPasteIntent extends Intent {
  const PlainPasteIntent();
}

class PlainPasteWrapper extends StatelessWidget {
  const PlainPasteWrapper({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            PlainPasteIntent(),
      },
      child: Actions(
        actions: {
          PlainPasteIntent: CallbackAction<PlainPasteIntent>(
            onInvoke: (_) async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);

              if (data?.text != null) {
                final index = controller.selection.baseOffset;
                final length = controller.selection.extentOffset - index;
                controller.replaceText(index, length, data!.text!, null);
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
