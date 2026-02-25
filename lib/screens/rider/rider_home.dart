import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/rider_service.dart';

import '../auth/login_screen.dart';
import 'rider_orders_screen.dart';
import 'rider_wallet_screen.dart';
import 'rider_profile_screen.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  bool online = false;
  bool loading = true;

  int ordersToday = 0;
  double earnings = 0.0;

  String? riderId;
  String riderName = "Rider";

  StreamSubscription<Position>? gpsStream;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    riderId = await Session.getUserId();
    riderName = await Session.getUserName() ?? "Rider";

    await loadStats();

    if (riderId != null) {
      SocketService.on("new_order", (_) {
        debugPrint("📦 New order received");
      });
    }
  }

  Future<void> loadStats() async {
    try {
      final res = await ApiService.get("/riders/dashboard");

      if (res != null) {
        setState(() {
          ordersToday = res["ordersToday"] ?? 0;
          earnings = (res["earnings"] ?? 0).toDouble();
          online = res["isAvailable"] ?? false;
        });

        if (online && riderId != null) {
          await SocketService.connect(riderId!);
          startTracking();
        }
      }
    } catch (e) {
      debugPrint("❌ Dashboard load failed: $e");
    }

    setState(() => loading = false);
  }

  Future<void> toggleOnline(bool value) async {
    if (riderId == null) return;

    setState(() => online = value);

    await RiderService.toggleAvailability(value);

    if (value) {
      await SocketService.connect(riderId!);
      startTracking();
    } else {
      await gpsStream?.cancel();
      gpsStream = null;
      SocketService.disconnect();
    }
  }

  Future<void> startTracking() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        debugPrint("❌ Location permission denied");
        return;
      }
    }

    gpsStream?.cancel();

    gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!online || riderId == null) return;

      SocketService.sendLocation(
        riderId: riderId!,
        lat: position.latitude,
        lng: position.longitude,
      );

      ApiService.sendRiderLocation(
        position.latitude,
        position.longitude,
      );
    });
  }

  Future<void> logout() async {
    await gpsStream?.cancel();
    gpsStream = null;

    SocketService.disconnect();
    await Session.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    gpsStream?.cancel();
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rider Dashboard"),
            Text("Hello, $riderName", style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const CircleAvatar(child: Icon(Icons.person)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "wallet", child: Text("Wallet")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RiderProfileScreen()),
                );
              } else if (value == "wallet") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RiderWalletScreen()),
                );
              } else {
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: online ? Colors.orange : Colors.grey.shade300,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          online ? "You are Online" : "You are Offline",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Switch(value: online, onChanged: toggleOnline),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _statCard("Orders Today", ordersToday.toString()),
                      const SizedBox(width: 12),
                      _statCard(
                        "Earnings",
                        "₦${earnings.toStringAsFixed(2)}",
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _actionButton(
                    title: "View Active Orders",
                    icon: Icons.delivery_dining,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RiderOrdersScreen()),
                      );
                    },
                  ),

                  _actionButton(
                    title: "Withdraw Earnings",
                    icon: Icons.account_balance_wallet,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RiderWalletScreen()),
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
          color: Colors.orange.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        leading: Icon(icon, color: Colors.orange),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
