import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// BOOTSTRAP LOADING VIEW
/// ---------------------------------------------------------------------------
///
/// Displays a loading UI while the application is initializing.
///
/// Responsibilities:
/// - Inform the user that startup is in progress
/// - Provide a minimal, blocking UI until bootstrap completes
///
/// Design:
/// - Stateless and lightweight
/// - Uses centered layout with progress indicator
/// - No logic, purely presentational
class BootstrapLoadingView extends StatelessWidget {
  const BootstrapLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Loading indicator
            CircularProgressIndicator(),

            SizedBox(height: 16),

            /// Status message
            Text('Starting Notepad...'),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BOOTSTRAP ERROR VIEW
/// ---------------------------------------------------------------------------
///
/// Displays a fallback UI when application startup fails.
///
/// Responsibilities:
/// - Inform the user that startup failed
/// - Display a user-readable error message
/// - Provide retry mechanism
///
/// Design:
/// - Stateless UI driven by message + retry callback
/// - Keeps error handling separate from bootstrap logic
class BootstrapErrorView extends StatelessWidget {
  const BootstrapErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Error message displayed to the user
  final String message;

  /// Callback triggered when user taps "Retry"
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Error icon
              const Icon(Icons.error_outline, size: 48),

              const SizedBox(height: 16),

              /// Primary error title
              const Text(
                'Notepad could not start',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              /// Detailed error message
              Text(message, textAlign: TextAlign.center),

              const SizedBox(height: 20),

              /// Retry button to re-trigger bootstrap
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BOOTSTRAP APP WRAPPER
/// ---------------------------------------------------------------------------
///
/// Controls application startup flow.
///
/// Responsibilities:
/// - Execute bootstrap logic before rendering main app
/// - Show loading UI during initialization
/// - Show error UI if bootstrap fails
/// - Render main app when initialization succeeds
///
/// Design:
/// - Uses FutureBuilder to react to bootstrap state
/// - Stores bootstrap future to prevent duplicate executions
/// - Supports retry by regenerating the future
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    super.key,
    required this.bootstrapper,
    required this.child,
  });

  /// Bootstrap function that performs initialization
  final Future<void> Function() bootstrapper;

  /// Root application widget to render after bootstrap completes
  final Widget child;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  /// Cached bootstrap future to avoid repeated execution
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();

    /// Trigger bootstrap on first build
    _bootstrapFuture = widget.bootstrapper();
  }

  /// Re-runs bootstrap process (used after failure)
  void _retry() {
    setState(() {
      /// Assign new future to trigger FutureBuilder rebuild
      _bootstrapFuture = widget.bootstrapper();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        // --- LOADING STATE ---
        if (snapshot.connectionState != ConnectionState.done) {
          // Wrap in MaterialApp to provide Directionality and Theme
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BootstrapLoadingView(),
          );
        }

        // --- ERROR STATE ---
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

        // --- SUCCESS STATE ---
        // widget.child is likely your main MaterialApp, so it doesn't need wrapping here.
        return widget.child;
      },
    );
  }
}
