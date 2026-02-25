import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/rider_service.dart';
import 'active_order_screen.dart';
import '../../services/socket_service.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> {
  bool loading = true;
  String error = "";
  List orders = [];

  bool hasNewOrders = false;
  Timer? refreshTimer;

 @override
  void initState() {
    super.initState();
    loadOrders();

    SocketService.on("new_order", (_) {
      setState(() => hasNewOrders = true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadOrders() async {
    setState(() => loading = true);

    try {
      final data = await RiderService.getMyOrders();

      setState(() {
        orders = data;
        loading = false;
        error = data.isEmpty ? "No active orders" : "";
        hasNewOrders = false;
      });
    } catch (_) {
      setState(() {
        loading = false;
        error = "Failed to load orders";
      });
    }
  }

  Future<void> checkForNewOrders() async {
    try {
      final data = await RiderService.getMyOrders();
      if (data.length > orders.length) {
        setState(() => hasNewOrders = true);
      }
    } catch (_) {}
  }

  Future<void> handleAction(
      Future Function() action, String successMessage) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
      await loadOrders();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Action failed")),
      );
    }
  }

  Widget buildActionButtons(Map order) {
    final status = (order["status"] ?? "").toString();

    // 1️⃣ Rider Assigned → Accept / Reject
    if (status == "rider_assigned") {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => handleAction(
                () => RiderService.accept(order["_id"]),
                "Order accepted",
              ),
              child: const Text("Accept"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => handleAction(
                () => RiderService.reject(order["_id"]),
                "Order rejected",
              ),
              child: const Text("Reject"),
            ),
          ),
        ],
      );
    }

    // 2️⃣ Arrived At Pickup → Confirm Pickup
    if (status == "arrived_at_pickup") {
      return ElevatedButton(
        onPressed: () => handleAction(
          () => RiderService.arrived(order["_id"]),
          "Pickup confirmed",
        ),
        child: const Text("Confirm Pickup"),
      );
    }

    // 3️⃣ Picked Up → Start Trip
    if (status == "picked_up") {
      return ElevatedButton(
        onPressed: () => handleAction(
          () => RiderService.startTrip(order["_id"]),
          "Trip started",
        ),
        child: const Text("Start Trip"),
      );
    }

    // 4️⃣ On The Way → Complete Delivery
    if (status == "on_the_way") {
      return ElevatedButton(
        onPressed: () => handleAction(
          () => RiderService.complete(order["_id"]),
          "Delivery completed",
        ),
        child: const Text("Complete Delivery"),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Orders")),
      body: Column(
        children: [
          if (hasNewOrders)
            GestureDetector(
              onTap: loadOrders,
              child: Container(
                width: double.infinity,
                color: Colors.orange,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  "New orders available — Tap to refresh",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(child: Text(error))
                    : orders.isEmpty
                        ? const Center(child: Text("No active orders"))
                        : RefreshIndicator(
                            onRefresh: loadOrders,
                            child: ListView.builder(
                              itemCount: orders.length,
                              itemBuilder: (context, i) {
                                final order = orders[i];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Order #${order["_id"]}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text("Status: ${order["status"]}"),
                                        const SizedBox(height: 10),
                                        buildActionButtons(order),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ActiveOrderScreen(
                                                          order: order),
                                                ),
                                              );
                                            },
                                            child: const Text("View Details"),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
