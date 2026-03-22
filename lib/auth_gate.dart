import 'dart:io';
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
  CartController? _cartController;

  bool loading = true;
  bool loggedIn = false;
  bool noInternet = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 6));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAuth() async {
    setState(() { loading = true; noInternet = false; });

    final connected = await _hasInternet();
    if (!mounted) return;

    if (!connected) {
      setState(() { loading = false; noInternet = true; });
      return;
    }

    final token = await Session.getToken();
    if (!mounted) return;

    setState(() {
      loggedIn = token != null;
      _cartController = loggedIn ? CartController() : null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (noInternet) {
      return _NoInternetScreen(onRetry: _checkAuth);
    }

    return loggedIn && _cartController != null
        ? CartProvider(
            controller: _cartController!,
            child: RoleRouter(
              key: const ValueKey("roleRouter"),
              onLogout: _checkAuth,
            ),
          )
        : LoginScreen(
            key: const ValueKey("loginScreen"),
            onLogin: _checkAuth,
          );
  }
}

class _NoInternetScreen extends StatefulWidget {
  final VoidCallback onRetry;
  const _NoInternetScreen({required this.onRetry});

  @override
  State<_NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<_NoInternetScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _retrying = false);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F8F8);
    final textColor = dark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = dark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: dark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  "No internet connection",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Please check your Wi-Fi or mobile data and try again.",
                  style: TextStyle(
                    fontSize: 14,
                    color: subColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _retrying ? null : _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Try again",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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