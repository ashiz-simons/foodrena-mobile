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

  @override
  void initState() {
    super.initState();
    loadOrders();

    SocketService.on("new_order", (data) {
      if (!mounted) return;
      setState(() => hasNewOrders = true);
      loadOrders();
    });
  }

  @override
  void dispose() {
    SocketService.off("new_order");
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

  Future<void> handleAction(
      Future Function() action, String successMsg) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg)),
        );
      }
      await loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceAll("Exception: ", "")),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget buildActionButtons(Map order) {
    final status = (order["status"] ?? "").toString();

    switch (status) {
      case "rider_assigned":
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text("Accept"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => handleAction(
                  () => RiderService.accept(order["_id"]),
                  "Order accepted — head to vendor",
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text("Reject"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => handleAction(
                  () => RiderService.reject(order["_id"]),
                  "Order rejected",
                ),
              ),
            ),
          ],
        );

      case "arrived_at_pickup":
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.store),
            label: const Text("I've arrived at vendor"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => handleAction(
              () => RiderService.arrived(order["_id"]),
              "Arrival confirmed — collect the order",
            ),
          ),
        );

      case "picked_up":
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag),
            label: const Text("Start Trip"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => handleAction(
              () => RiderService.startTrip(order["_id"]),
              "Trip started — deliver to customer",
            ),
          ),
        );

      case "on_the_way":
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text("Complete Delivery"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => handleAction(
              () => RiderService.complete(order["_id"]),
              "Delivery completed!",
            ),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Orders"),
        backgroundColor: Colors.orange,
      ),
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
                  "🔔 New order assigned — tap to refresh",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty && orders.isEmpty
                    ? Center(child: Text(error))
                    : orders.isEmpty
                        ? const Center(child: Text("No active orders"))
                        : RefreshIndicator(
                            onRefresh: loadOrders,
                            child: ListView.builder(
                              itemCount: orders.length,
                              itemBuilder: (context, i) {
                                final order = orders[i];
                                final status = order["status"] ?? "";
                                final vendorName =
                                    order["vendor"]?["businessName"] ??
                                        order["vendor"]?["name"] ??
                                        "Vendor";
                                final customerName =
                                    order["user"]?["name"] ?? "Customer";
                                final _addr = order["deliveryAddress"];
                                String deliveryAddress = "";
                                if (_addr is Map) {
                                  final parts = [_addr['street'], _addr['state'], _addr['city']]
                                      .where((p) => p != null && p.toString().isNotEmpty).toList();
                                  deliveryAddress = parts.join(', ');
                                } else if (_addr is String) {
                                  deliveryAddress = _addr;
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              vendorName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                            _statusChip(status),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Customer name
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline,
                                                size: 15,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              customerName,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        // Delivery address
                                        if (deliveryAddress
                                            .toString()
                                            .isNotEmpty)
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 15,
                                                  color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  deliveryAddress.toString(),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 4),

                                        Text(
                                          "₦${order["total"] ?? 0}  •  ${order["items"]?.length ?? 0} item(s)",
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(height: 12),
                                        buildActionButtons(order),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ActiveOrderScreen(
                                                        order: order),
                                              ),
                                            ),
                                            child:
                                                const Text("View Details"),
                                          ),
                                        ),
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

  Widget _statusChip(String status) {
    final color = {
          "rider_assigned": Colors.blue,
          "arrived_at_pickup": Colors.orange,
          "picked_up": Colors.indigo,
          "on_the_way": Colors.green,
          "delivered": Colors.grey,
        }[status] ??
        Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.replaceAll("_", " "),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}