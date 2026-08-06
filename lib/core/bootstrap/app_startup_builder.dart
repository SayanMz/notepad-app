// Wraps app startup state and shows a retryable error screen when bootstrap fails.
import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';

/// It exposes the bootstrapper completion status down the tree.
class BootstrapScope extends InheritedWidget {
  const BootstrapScope({
    super.key,
    required this.isInitializationComplete,
    required super.child,
  });

  final bool isInitializationComplete;

  static BootstrapScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BootstrapScope>();
  }

  @override
  bool updateShouldNotify(BootstrapScope oldWidget) {
    return isInitializationComplete != oldWidget.isInitializationComplete;
  }
}

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
        child: SingleChildScrollView(
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

class AppStartupBuilder extends StatefulWidget {
  const AppStartupBuilder({
    super.key,
    required this.bootstrapper,
    required this.child,
  });

  final Future<void> Function() bootstrapper;
  final Widget child;

  @override
  State<AppStartupBuilder> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<AppStartupBuilder> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = Future<void>.sync(widget.bootstrapper);
  }

  void _retry() {
    setState(() {
      _bootstrapFuture = Future<void>.sync(widget.bootstrapper);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errorMessage =
              snapshot.error?.toString().trim() ??
              'The app could not finish starting. Please check your setup and try again.';

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BootstrapErrorView(message: errorMessage, onRetry: _retry),
          );
        }

        final isComplete = snapshot.connectionState == ConnectionState.done;

        return BootstrapScope(
          isInitializationComplete: isComplete,
          child: widget.child,
        );
      },
    );
  }
}
