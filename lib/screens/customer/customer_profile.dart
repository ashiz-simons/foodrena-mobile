import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';
import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../screens/rider/vehicle_info_screen.dart';
import '../orders/order_history_screen.dart';

class CustomerProfile extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onRoleSwitch;

  const CustomerProfile({
    super.key,
    required this.onLogout,
    required this.onRoleSwitch,
  });

  @override
  State<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfile> {
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

      // ✅ Just call onRoleSwitch — no Navigator.pop needed.
      // RoleRouter._resolveHome() will rebuild the whole tree.
      widget.onRoleSwitch();
    } catch (e) {
      final msg = e.toString().replaceAll("Exception: ", "");

      if (msg.contains("Vehicle info required") ||
          msg.contains("requiresVehicleInfo")) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleInfoScreen(
              onCompleted: () async {
                final res = await ApiService.post(
                    "/auth/switch-role", {"role": "rider"});
                await Session.saveToken(res["token"]);
                await Session.saveUser(res["user"]);
                widget.onRoleSwitch(); // ✅ same here
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
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final name = user?["name"] ?? "Customer";
    final email = user?["email"] ?? "";
    final activeRole = user?["role"] ?? "customer";
    final roles = List<String>.from(user?["roles"] ?? ["customer"]);
    final allRoles = ["customer", "rider", "vendor"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + Name ──────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: CustomerColors.primary.withOpacity(0.12),
                  child: const Icon(Icons.person,
                      size: 32, color: CustomerColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                color: CustomerColors.textMuted,
                                fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: CustomerColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activeRole.toUpperCase(),
                          style: const TextStyle(
                              color: CustomerColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Account Section ────────────────────────────
            _sectionLabel("Account"),
            const SizedBox(height: 8),
            _card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.receipt_long,
                    color: CustomerColors.primary),
                title: const Text("My Orders"),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OrderHistoryScreen()),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Switch Role Section ────────────────────────
            _sectionLabel("Switch Role"),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: allRoles.map((role) {
                  final isActive = role == activeRole;
                  final hasRole = roles.contains(role);
                  final icon = role == "rider"
                      ? Icons.delivery_dining
                      : role == "vendor"
                          ? Icons.storefront
                          : Icons.person;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(icon,
                        color: isActive
                            ? CustomerColors.primary
                            : Colors.grey),
                    title: Text(
                      role[0].toUpperCase() + role.substring(1),
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? CustomerColors.primary
                            : Colors.black87,
                      ),
                    ),
                    trailing: switching && !isActive
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isActive
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 18)
                            : hasRole
                                ? const Icon(Icons.swap_horiz,
                                    color: Colors.grey, size: 18)
                                : const Icon(Icons.add_circle_outline,
                                    color: Colors.grey, size: 18),
                    onTap: isActive || switching
                        ? null
                        : () => _switchRole(role),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // ── Logout ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.red, width: 1),
                  ),
                ),
                onPressed: _logout,
                child: const Text("Logout",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CustomerColors.textMuted));
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}