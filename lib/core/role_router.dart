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
  String? _currentRole; // track role so key changes force full rebuild

  @override
  void initState() {
    super.initState();
    _resolveHome();
  }

  Future<void> _resolveHome() async {
    if (mounted) setState(() => home = null);

    final user = await Session.getUser();
    final role = user?["role"] as String? ?? "customer";

    // Role changed — clear any stale navigation stack first
    if (_currentRole != null && _currentRole != role && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _currentRole = role;

    Widget resolved;

    switch (role) {
      case "rider":
        resolved = RiderHome(
          key: const ValueKey("riderHome"), // force fresh init on rebuild
          onLogout: _handleLogout,
          onRoleSwitch: _resolveHome,
        );
        break;
      case "vendor":
        try {
          final vendorRes = await ApiService.get("/vendors/me");
          if (vendorRes["onboardingCompleted"] == true) {
            resolved = VendorHome(
              key: const ValueKey("vendorHome"),
              onLogout: _handleLogout,
              onRoleSwitch: _resolveHome,
            );
          } else {
            resolved = VendorOnboardingScreen(
              key: const ValueKey("vendorOnboarding"),
              // onCompleted: when vendor leaves without finishing,
              // switch them back to customer so they aren't stuck.
              onCompleted: _resolveHome,
              onLeave: _switchBackToCustomer,
            );
          }
        } catch (_) {
          // Vendor profile fetch failed — fall back to customer
          await _switchBackToCustomer();
          return;
        }
        break;
      default:
        resolved = CustomerNavShell(
          key: const ValueKey("customerShell"),
          onLogout: _handleLogout,
          onRoleSwitch: _resolveHome,
        );
    }

    if (!mounted) return;
    setState(() => home = resolved);
  }

  Future<void> _switchBackToCustomer() async {
    try {
      final res = await ApiService.post("/auth/switch-role", {"role": "customer"});
      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"]);
    } catch (_) {}
    _resolveHome();
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