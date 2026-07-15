import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.isInitializationComplete});

  final bool isInitializationComplete;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isTransitioning = false;
  bool _animationFinished = false;

  // 🌟 FIX 1: Add a loading state to hide the naked text
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant SplashPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInitializationComplete && _animationFinished) {
      _navigateToHome();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        // 🌟 FIX 1: The Silver Bullet.
        // Setting this to false prevents Flutter from blacking out the outgoing route.
        // The SplashPage will now stay perfectly visible underneath while HomePage fades in!
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            // 🌟 FIX 2: Apply a smooth deceleration curve so the fade feels organic, not linear.
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        // 🌟 FIX 3: A 700ms duration makes the cross-fade highly visible and luxurious.
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _isLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lotties/Notepad.json',
                controller: _animationController,
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _animationController.duration = composition.duration;
                  _animationController.value = 0.08;

                  setState(() {
                    _isLoaded = true;
                  });

                  // 🌟 FIX 4: Stop exactly at 0.82 (Frame 130).
                  // The pencil mathematically scales to 0 at this exact frame in your JSON file.
                  // It will look like it finishes writing and pops out of existence cleanly.
                  _animationController.animateTo(0.82).then((_) {
                    _animationFinished = true;
                    if (widget.isInitializationComplete) {
                      _navigateToHome();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Notepad',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
