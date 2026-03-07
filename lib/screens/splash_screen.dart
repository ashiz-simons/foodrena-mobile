import 'package:flutter/material.dart';
import '../../utils/session.dart';
import '../auth/welcome_screen.dart';
import '../../core/role_router.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onLogin;

  const SplashScreen({super.key, this.onLogin});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // After animation, check session and route accordingly
    Future.delayed(const Duration(milliseconds: 1600), () async {
      if (!mounted) return;

      final token = await Session.getToken();

      if (!mounted) return;

      if (token != null) {
        // Already logged in — go to role router
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleRouter(onLogout: _handleLogout),
          ),
        );
      } else {
        // Not logged in — show welcome screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WelcomeScreen(onLogin: widget.onLogin),
          ),
        );
      }
    });
  }

  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(onLogin: widget.onLogin),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDC2626),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.restaurant,
                      color: Color(0xFFDC2626), size: 44),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Foodrena",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}