import 'package:flutter/material.dart';
import 'utils/session.dart';
import 'screens/auth/login_screen.dart';
import 'core/role_router.dart';
import 'core/cart/cart_provider.dart';
import 'core/cart/cart_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  CartController? _CartController;

  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await Session.getToken();

    if (!mounted) return;

    setState(() {
      loggedIn = token != null;

      if (loggedIn) {
        _CartController = CartController();
      } else {
        _CartController = null;
      }

      loading = false;
    });
  }

  void refreshAuth() {
    setState(() {
      loading = true;
    });
    _checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return loggedIn && _CartController != null
        ? CartProvider(
          controller: _CartController!,
          child: RoleRouter(
            key: const ValueKey("roleRouter"),
            onLogout: refreshAuth,
          ),
        )
        : LoginScreen(
            key: const ValueKey("loginScreen"),
            onLogin: refreshAuth,
          );
  }
}