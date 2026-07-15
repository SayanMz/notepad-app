import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';

class BootstrapErrorView extends StatelessWidget {
  const BootstrapErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.paddingXXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: UIConstants.iconXL),
              const SizedBox(height: UIConstants.paddingLG),
              const Text(
                'Notepad could not start',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: UIConstants.headerTitleFontSize - 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: UIConstants.paddingMD),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: UIConstants.paddingXLarge),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    super.key,
    required this.bootstrapper,
    required this.child,
  });

  final Future<void> Function() bootstrapper;
  final Widget child;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = widget.bootstrapper();
  }

  void _retry() {
    setState(() {
      _bootstrapFuture = widget.bootstrapper();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BootstrapErrorView(
              message:
                  'The app could not finish starting. Please check your setup and try again.',
              onRetry: _retry,
            ),
          );
        }

        // Pass the actual app tree forward, keeping track of the loading status
        return widget.child;
      },
    );
  }
}
