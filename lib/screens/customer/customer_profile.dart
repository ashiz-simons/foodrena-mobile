import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';
import '../../utils/session.dart';
import '../auth/login_screen.dart';
import '../../core/role_router.dart';
class CustomerProfile extends StatelessWidget {
  const CustomerProfile({super.key});

  Future<Map?> _getUser() async {
    return await Session.getUser();
  }

  Future<void> _logout(BuildContext context) async {
    await Session.clear();

    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RoleRouter()),
        (route) => false,
    );
 }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: FutureBuilder<Map?>(
        future: _getUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?["name"] ?? "Customer";
          final email = user?["email"] ?? "";

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= USER INFO =================
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      email,
                      style: const TextStyle(
                        color: CustomerColors.textMuted,
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // ================= SETTINGS =================
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text("Change password"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Day 6
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none),
                  title: const Text("Notifications"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Later
                  },
                ),

                const Spacer(),

                // ================= LOGOUT =================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    onPressed: () => _logout(context),
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}