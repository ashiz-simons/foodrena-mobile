import 'package:flutter/material.dart';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/vendor_service.dart';
import '../../widgets/app_drawer.dart';

import 'vendor_orders_screen.dart';
import 'vendor_menu_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_wallet_screen.dart';
import 'vendor_bank_screen.dart';

class VendorHome extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onRoleSwitch;

  const VendorHome({super.key, this.onLogout, this.onRoleSwitch});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  bool open = false;
  bool loading = true;

  int ordersToday = 0;
  int activeOrders = 0;

  String? vendorId;   // ✅ Vendor._id — used for socket room
  String vendorName = "Vendor";

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    vendorName = await Session.getUserName() ?? "Vendor";
    await loadStats();
  }

  Future<void> loadStats() async {
    try {
      final res = await ApiService.get("/vendors/dashboard");
      if (res != null && mounted) {
        setState(() {
          ordersToday = res["ordersToday"] ?? 0;
          activeOrders = res["activeOrders"] ?? 0;
          open = res["isOpen"] ?? false;
          // ✅ Get Vendor._id from dashboard response
          vendorId = res["vendorId"]?.toString() ?? res["_id"]?.toString();
        });
      }

      // ✅ Connect socket as soon as vendor loads — not just when toggling open
      // Vendor needs to receive new_order notifications at all times
      if (vendorId != null) {
        await SocketService.connectToRoom("vendor_$vendorId");
        _listenForOrders();
      }
    } catch (e) {
      debugPrint("Vendor dashboard load failed: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  void _listenForOrders() {
    SocketService.on("new_order", (data) {
      if (!mounted) return;
      // Show a notification banner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.white),
              SizedBox(width: 10),
              Text("New order received!"),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: "View",
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VendorOrdersScreen()),
            ),
          ),
        ),
      );
      // Refresh stats
      loadStats();
    });
  }

  Future<void> toggleOpen(bool value) async {
    setState(() => open = value);
    await VendorService.toggleAvailability(value);
  }

  Future<void> logout() async {
    SocketService.disconnect();
    await Session.clearAll();
    widget.onLogout?.call();
  }

  @override
  void dispose() {
    SocketService.off("new_order");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: AppDrawer(
        onRoleSwitch: widget.onRoleSwitch ?? () {},
        onLogout: logout,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard"),
            Text("Welcome, $vendorName",
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "wallet", child: Text("Wallet")),
              PopupMenuItem(value: "bank", child: Text("Bank Details")),
              PopupMenuItem(value: "menu", child: Text("Manage Menu")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const VendorProfileScreen()));
              } else if (value == "wallet") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const VendorWalletScreen()));
              } else if (value == "bank") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const VendorBankScreen()));
              } else if (value == "menu") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const VendorMenuScreen()));
              } else {
                logout();
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStats,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _availabilityCard(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _statCard("Orders Today", ordersToday.toString()),
                      const SizedBox(width: 12),
                      _statCard("Active Orders", activeOrders.toString()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _actionTile(
                    icon: Icons.receipt_long,
                    title: "View Orders",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => VendorOrdersScreen()),
                    ),
                  ),
                  _actionTile(
                    icon: Icons.restaurant_menu,
                    title: "Manage Menu",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VendorMenuScreen()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _availabilityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: open ? Colors.blue : Colors.grey.shade300,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(open ? "Store is Open" : "Store is Closed",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Switch(value: open, onChanged: toggleOpen),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}