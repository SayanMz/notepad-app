import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/features/home/home_page.dart';

// Startup splash that waits for initialization and animation before entering home.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.isInitializationComplete});

  final bool isInitializationComplete;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  bool _animationFinished = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

                  _animationController.animateTo(0.82).then((_) {
                    _animationFinished = true;
                    _checkAndNavigate();
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

  @override
  void didUpdateWidget(covariant SplashPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    if (widget.isInitializationComplete && _animationFinished) {
      _navigateToHome();
    }
  }
}
