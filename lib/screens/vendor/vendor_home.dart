import 'package:flutter/material.dart';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/vendor_service.dart';

import '../auth/login_screen.dart';
import 'vendor_orders_screen.dart';
import 'vendor_menu_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_wallet_screen.dart';
import 'vendor_bank_screen.dart';

class VendorHome extends StatefulWidget {
  const VendorHome({super.key});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  bool open = false;
  bool loading = true;

  int ordersToday = 0;
  int activeOrders = 0;

  String? vendorId;
  String vendorName = "Vendor";

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    vendorId = await Session.getUserId();
    vendorName = await Session.getUserName() ?? "Vendor";
    await loadStats();
  }

  Future<void> loadStats() async {
    try {
      final res = await ApiService.get("/vendors/dashboard");

      if (res != null) {
        setState(() {
          ordersToday = res["ordersToday"] ?? 0;
          activeOrders = res["activeOrders"] ?? 0;
          open = res["isOpen"] ?? false;
        });
      }
    } catch (e) {
      debugPrint("❌ Vendor dashboard load failed: $e");
    }

    setState(() => loading = false);
  }

  Future<void> toggleOpen(bool value) async {
    setState(() => open = value);

    await VendorService.toggleAvailability(value);

    if (value && vendorId != null) {
      await SocketService.connect(vendorId!);
    } else {
      SocketService.disconnect();
    }
  }

  Future<void> logout() async {
    SocketService.disconnect();
    await Session.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Vendor Dashboard"),
            Text(
              "Hello, $vendorName",
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const CircleAvatar(
              child: Icon(Icons.store),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "wallet", child: Text("Wallet")),
              PopupMenuItem(value: "bank", child: Text("Bank Details")), // ✅ NEW
              PopupMenuItem(value: "menu", child: Text("Manage Menu")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VendorProfileScreen()),
                );
              } else if (value == "wallet") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VendorWalletScreen()),
                );
              } else if (value == "bank") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VendorBankScreen()),
                );
              } else if (value == "menu") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VendorMenuScreen()),
                );
              } else if (value == "logout") {
                logout();
              }
            },
          ),


          const SizedBox(width: 10),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OPEN / CLOSED
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: open ? Colors.blue : Colors.grey.shade300,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          open ? "Store is Open" : "Store is Closed",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(value: open, onChanged: toggleOpen),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _statCard("Orders Today", ordersToday.toString()),
                      const SizedBox(width: 12),
                      _statCard("Active Orders", activeOrders.toString()),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _actionButton(
                    title: "View Orders",
                    icon: Icons.receipt_long,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VendorOrdersScreen(),
                        ),
                      );
                    },
                  ),

                  _actionButton(
                    title: "Manage Menu",
                    icon: Icons.restaurant_menu,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VendorMenuScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
