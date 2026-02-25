import 'package:flutter/material.dart';
import 'utils/session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await Session.getToken();
    setState(() {
      loggedIn = token != null;
      loading = false;
    });
  }

  /// 🔑 THIS IS THE MAGIC
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

    return loggedIn
        ? RoleRouter(onLogout: refreshAuth)
        : LoginScreen(onLogin: refreshAuth);
  }
}