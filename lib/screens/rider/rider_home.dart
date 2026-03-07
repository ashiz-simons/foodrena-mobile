import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../utils/session.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/rider_service.dart';
import '../../widgets/app_drawer.dart';

import 'rider_orders_screen.dart';
import 'rider_wallet_screen.dart';
import 'rider_profile_screen.dart';

class RiderHome extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onRoleSwitch;

  const RiderHome({super.key, this.onLogout, this.onRoleSwitch});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  bool online = false;
  bool loading = true;

  int ordersToday = 0;
  double earnings = 0.0;

  String? riderId;   // ✅ Rider._id — used for socket rooms
  String? userId;    // User._id — used for API auth
  String riderName = "Rider";

  StreamSubscription<Position>? gpsStream;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    // ✅ Use getRiderId() for socket room, getUserId() for everything else
    riderId = await Session.getRiderId();
    userId = await Session.getUserId();
    riderName = await Session.getUserName() ?? "Rider";
    await loadDashboard();
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadDashboard() async {
    try {
      final res = await ApiService.get("/riders/dashboard");
      if (res != null) {
        setState(() {
          ordersToday = res["ordersToday"] ?? 0;
          earnings = (res["earnings"] ?? 0).toDouble();
          online = res["isAvailable"] ?? false;
        });
        if (online && riderId != null) {
          await _connectSocket();
          startTracking();
        }
      }
    } catch (e) {
      debugPrint("❌ Dashboard load failed: $e");
    }
  }

  Future<void> _connectSocket() async {
    // ✅ Join rider_<Rider._id> so new_order notifications arrive correctly
    await SocketService.connectToRoom("rider_$riderId");
    SocketService.emit("rider_online", {"riderId": riderId});
    print("🟢 Joined rider room: rider_$riderId");
  }

  Future<void> toggleOnline(bool value) async {
    if (riderId == null) return;
    setState(() => online = value);
    await RiderService.toggleAvailability(value);
    if (value) {
      await _connectSocket();
      startTracking();
    } else {
      SocketService.emit("rider_offline", {"riderId": riderId});
      await gpsStream?.cancel();
      gpsStream = null;
      SocketService.disconnect();
    }
  }

  Future<void> startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    await gpsStream?.cancel();
    gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!online || riderId == null) return;

      // ✅ Use riderId (Rider._id) for socket emit
      SocketService.emit("rider_location_update", {
        "riderId": riderId,
        "lat": position.latitude,
        "lng": position.longitude,
      });

      // REST update — backend uses req.rider from token so no ID needed
      ApiService.patch("/riders/location", {
        "lat": position.latitude,
        "lng": position.longitude,
      });
    });
  }

  Future<void> logout() async {
    await gpsStream?.cancel();
    gpsStream = null;
    SocketService.disconnect();
    await Session.clearAll();
    widget.onLogout?.call();
  }

  @override
  void dispose() {
    gpsStream?.cancel();
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: AppDrawer(
        onRoleSwitch: widget.onRoleSwitch ?? () {},
        onLogout: logout,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard"),
            Text("Welcome, $riderName",
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "wallet", child: Text("Wallet")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const RiderProfileScreen()));
              } else if (value == "wallet") {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const RiderWalletScreen()));
              } else {
                logout();
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _statusCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                _statCard("Orders Today", ordersToday.toString()),
                const SizedBox(width: 12),
                _statCard("Earnings", "₦${earnings.toStringAsFixed(2)}"),
              ],
            ),
            const SizedBox(height: 24),
            _actionTile(
              icon: Icons.delivery_dining,
              title: "View Active Orders",
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const RiderOrdersScreen())),
            ),
            _actionTile(
              icon: Icons.account_balance_wallet,
              title: "Withdraw Earnings",
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const RiderWalletScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: online ? Colors.orange : Colors.grey.shade300,
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
          Text(online ? "You are Online" : "You are Offline",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Switch(value: online, onChanged: toggleOnline),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}