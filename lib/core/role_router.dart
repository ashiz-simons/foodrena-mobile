import 'package:flutter/material.dart';
import '../utils/session.dart';

import '../core/navigation/customer_nav_shell.dart';
import '../screens/rider/rider_home.dart';
import '../screens/vendor/vendor_home.dart';
import '../screens/auth/login_screen.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  Future<Widget> _resolveHome() async {
    final user = await Session.getUser();
    final role = user?["role"];

    if (role == "rider") {
      return RiderHome();
    }

    if (role == "vendor") {
      return VendorHome();
    }

    if (role == "user" || role == "customer") {
      return CustomerNavShell();
    }

    return LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveHome(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}