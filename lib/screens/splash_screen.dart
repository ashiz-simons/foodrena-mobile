import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth_gate.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onLogin;
  const SplashScreen({super.key, this.onLogin});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _currentFrame = 0;
  Timer? _timer;

  static const int _totalFrames = 20;
  static const Duration _frameDuration = Duration(milliseconds: 80); // 80ms ≈ 12fps

  @override
  void initState() {
    super.initState();
    _preloadFrames();
    _startAnimation();
  }

  // Preload all frames so there's no stutter on first play
  void _preloadFrames() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < _totalFrames; i++) {
        final path = 'assets/splash_frames/frame_${i.toString().padLeft(2, '0')}.png';
        precacheImage(AssetImage(path), context);
      }
    });
  }

  void _startAnimation() {
    _timer = Timer.periodic(_frameDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentFrame < _totalFrames - 1) {
        setState(() => _currentFrame++);
      } else {
        timer.cancel();
        _navigateToApp();
      }
    });
  }

  void _navigateToApp() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String framePath =
        'assets/splash_frames/frame_${_currentFrame.toString().padLeft(2, '0')}.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Image.asset(
        framePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true, // prevents white flash between frames
      ),
    );
  }
}