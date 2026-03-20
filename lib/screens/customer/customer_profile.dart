import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../screens/rider/vehicle_info_screen.dart';
import '../orders/order_history_screen.dart';
import '../../widgets/dark_mode_toggle.dart';

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
    widget.onLogout();
  }

  // ── Theme helpers ────────────────────────────────────────────────
  bool _dark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  Color _bg(BuildContext ctx) => _dark(ctx)
      ? CustomerColors.backgroundDark
      : CustomerColors.background;

  Color _card(BuildContext ctx) => _dark(ctx)
      ? CustomerColors.surfaceDark
      : CustomerColors.surface;

  Color _text(BuildContext ctx) => _dark(ctx)
      ? CustomerColors.textPrimaryDark
      : CustomerColors.textPrimary;

  Color _muted(BuildContext ctx) => _dark(ctx)
      ? CustomerColors.textMutedDark
      : CustomerColors.textMuted;

  Color _primary(BuildContext ctx) => _dark(ctx)
      ? CustomerColors.primaryDark
      : CustomerColors.primary;

  Color _border(BuildContext ctx) => _dark(ctx)
      ? Colors.white.withOpacity(0.08)
      : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    final name = user?["name"] ?? "Customer";
    final email = user?["email"] ?? "";
    final activeRole = user?["role"] ?? "customer";
    final roles = List<String>.from(user?["roles"] ?? ["customer"]);
    final allRoles = ["customer", "rider", "vendor"];
    final dark = _dark(context);
    final primary = _primary(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg(context),
        appBar: AppBar(
          backgroundColor: _bg(context),
          elevation: 0,
          title: Text("Profile",
              style: TextStyle(
                  color: _text(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          iconTheme: IconThemeData(color: _text(context)),
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
                    backgroundColor: primary.withOpacity(0.12),
                    child: Icon(Icons.person, size: 32, color: primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _text(context))),
                        if (email.isNotEmpty)
                          Text(email,
                              style: TextStyle(
                                  color: _muted(context), fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            activeRole.toUpperCase(),
                            style: TextStyle(
                                color: primary,
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

              // ── Appearance ────────────────────────────────
              _sectionLabel("APPEARANCE", context),
              const SizedBox(height: 8),
              const DarkModeToggle(),

              const SizedBox(height: 28),

              // ── Account Section ────────────────────────────
              _sectionLabel("ACCOUNT", context),
              const SizedBox(height: 8),
              _cardWidget(
                context: context,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.receipt_long, color: primary),
                  title: Text("My Orders",
                      style: TextStyle(
                          color: _text(context), fontWeight: FontWeight.w500)),
                  trailing: Icon(Icons.chevron_right, color: _muted(context)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OrderHistoryScreen()),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Switch Role Section ────────────────────────
              _sectionLabel("SWITCH ROLE", context),
              const SizedBox(height: 8),
              _cardWidget(
                context: context,
                child: Column(
                  children: allRoles.map((role) {
                    final isActive = role == activeRole;
                    final hasRole = roles.contains(role);
                    final icon = role == "rider"
                        ? Icons.delivery_dining
                        : role == "vendor"
                            ? Icons.storefront
                            : Icons.person;
                    final divider = role != allRoles.last;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Icon(icon,
                              color: isActive ? primary : _muted(context)),
                          title: Text(
                            role[0].toUpperCase() + role.substring(1),
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isActive ? primary : _text(context),
                            ),
                          ),
                          trailing: switching && !isActive
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : isActive
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green, size: 18)
                                  : hasRole
                                      ? Icon(Icons.swap_horiz,
                                          color: _muted(context), size: 18)
                                      : Icon(Icons.add_circle_outline,
                                          color: _muted(context), size: 18),
                          onTap: isActive || switching
                              ? null
                              : () => _switchRole(role),
                        ),
                        if (divider)
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: _border(context)),
                      ],
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
                    backgroundColor:
                        dark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Colors.red.withOpacity(dark ? 0.4 : 1),
                          width: 1),
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
      ),
    );
  }

  Widget _sectionLabel(String label, BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _muted(context),
            letterSpacing: 1.2));
  }

  Widget _cardWidget({required BuildContext context, required Widget child}) {
    final dark = _dark(context);
    final primary = _primary(context);
    return Container(
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? primary.withOpacity(0.3) : primary,
            width: dark ? 1 : 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
              blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}