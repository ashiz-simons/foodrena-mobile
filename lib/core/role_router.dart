import 'package:flutter/material.dart';
import '../utils/session.dart';
import '../core/navigation/customer_nav_shell.dart';
import '../screens/rider/rider_home.dart';
import '../screens/vendor/vendor_home.dart';
import '../screens/vendor/vendor_onboarding_screen.dart';
import '../screens/shared/incoming_call_screen.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

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
  String? _currentRole;

  @override
  void initState() {
    super.initState();
    _resolveHome();
    _listenForCalls();
  }

  @override
  void dispose() {
    SocketService.off("call_invite", handlerId: "role_router_global");
    super.dispose();
  }

  void _listenForCalls() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      SocketService.on(
        "call_invite",
        (data) {
          if (!mounted) return;
          final callOrderId  = data["orderId"]?.toString() ?? "";
          final callerName   = data["callerName"] ?? "Unknown";
          final channelName  = data["channelName"] ?? callOrderId;
          final appId        = data["appId"] ?? "e03b6ecb7bcf4e279d314411ec817e7e";
          final token        = data["token"];
          final senderRole   = data["senderRole"] ?? "customer";
          final recipientRole = senderRole == "rider" ? "customer" : "rider";

          _showIncomingCall(
            orderId:     callOrderId,
            callerName:  callerName,
            senderRole:  recipientRole,
            channelName: channelName,
            appId:       appId,
            token:       token,
          );
        },
        handlerId: "role_router_global",
      );
    });
  }

  void _showIncomingCall({
    required String orderId,
    required String callerName,
    required String senderRole,
    required String channelName,
    required String appId,
    String? token,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          orderId:     orderId,
          callerName:  callerName,
          senderRole:  senderRole,
          channelName: channelName,
          appId:       appId,
          token:       token,
        ),
      ),
    );
  }

  Future<void> _resolveHome() async {
    if (mounted) setState(() => home = null);

    final user = await Session.getUser();
    final role = user?["role"] as String? ?? "customer";

    if (_currentRole != null && _currentRole != role && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _currentRole = role;

    Widget resolved;

    switch (role) {
      case "rider":
        resolved = RiderHome(
          key: const ValueKey("riderHome"),
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
              onCompleted: _resolveHome,
              onLeave: _switchBackToCustomer,
            );
          }
        } catch (_) {
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