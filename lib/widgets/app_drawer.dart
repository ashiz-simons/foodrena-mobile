import 'package:flutter/material.dart';
import '../utils/session.dart';
import '../services/api_service.dart';
import '../screens/rider/vehicle_info_screen.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback onRoleSwitch;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.onRoleSwitch,
    required this.onLogout,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map? user;
  bool switching = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await Session.getUser();
    if (mounted) setState(() => user = u);
  }

  Future<void> _switchRole(String role) async {
    if (switching) return;
    setState(() => switching = true);

    try {
      final res = await ApiService.post("/auth/switch-role", {"role": role});

      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"]);

      if (!mounted) return;
      Navigator.pop(context); // close drawer
      widget.onRoleSwitch();  // re-resolve RoleRouter
    } catch (e) {
      final msg = e.toString().replaceAll("Exception: ", "");

      if (msg.contains("Vehicle info required") || msg.contains("requiresVehicleInfo")) {
        if (!mounted) return;
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleInfoScreen(
              onCompleted: () async {
                // retry switch after vehicle info saved
                final res = await ApiService.post("/auth/switch-role", {"role": "rider"});
                await Session.saveToken(res["token"]);
                await Session.saveUser(res["user"]);
                widget.onRoleSwitch();
              },
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => switching = false);
  }

  Future<void> _logout() async {
    await Session.clearAll();
    if (mounted) Navigator.pop(context);
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final name = user?["name"] ?? "User";
    final email = user?["email"] ?? "";
    final activeRole = user?["role"] ?? "customer";
    final roles = List<String>.from(user?["roles"] ?? ["customer"]);

    // All switchable roles (always show all 3 so user can add new ones)
    final allRoles = ["customer", "rider", "vendor"];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      activeRole.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Switch Role Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Switch Role",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 8),

            ...allRoles.map((role) {
              final isActive = role == activeRole;
              final hasRole = roles.contains(role);
              final icon = role == "rider"
                  ? Icons.delivery_dining
                  : role == "vendor"
                      ? Icons.storefront
                      : Icons.person;

              return ListTile(
                leading: Icon(icon,
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey),
                title: Text(
                  role[0].toUpperCase() + role.substring(1),
                  style: TextStyle(
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
                  ),
                ),
                trailing: isActive
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 18)
                    : hasRole
                        ? const Icon(Icons.swap_horiz,
                            color: Colors.grey, size: 18)
                        : const Icon(Icons.add_circle_outline,
                            color: Colors.grey, size: 18),
                onTap: isActive || switching ? null : () => _switchRole(role),
              );
            }),

            const Divider(),
            const Spacer(),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}