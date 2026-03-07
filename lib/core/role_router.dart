import 'package:flutter/material.dart';
import '../utils/session.dart';
import '../core/navigation/customer_nav_shell.dart';
import '../screens/rider/rider_home.dart';
import '../screens/vendor/vendor_home.dart';
import '../screens/vendor/vendor_onboarding_screen.dart';
import '../services/api_service.dart';

class RoleRouter extends StatefulWidget {
  final VoidCallback onLogout;

  const RoleRouter({
    super.key,
    required this.onLogout,
  });

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  Widget? home;

  @override
  void initState() {
    super.initState();
    _resolveHome();
  }

  Future<void> _resolveHome() async {
    if (mounted) setState(() => home = null); // show loading while resolving

    final user = await Session.getUser();
    final role = user?["role"];

    Widget resolved;

    switch (role) {
      case "rider":
        resolved = RiderHome(
          onLogout: _handleLogout,
          onRoleSwitch: _resolveHome, // 👈 pass switch callback
        );
        break;
      case "vendor":
        final vendorRes = await ApiService.get("/vendors/me");
        if (vendorRes["onboardingCompleted"] == true) {
          resolved = VendorHome(
            onLogout: _handleLogout,
            onRoleSwitch: _resolveHome, // 👈 pass switch callback
          );
        } else {
          resolved = VendorOnboardingScreen(onCompleted: _resolveHome);
        }
        break;
      default:
        resolved = CustomerNavShell(
          onLogout: _handleLogout,
          onRoleSwitch: _resolveHome, // 👈 pass switch callback
        );
    }

    if (!mounted) return;
    setState(() => home = resolved);
  }

  Future<void> _handleLogout() async {
    await Session.clearAll();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    if (home == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return home!;
  }
}