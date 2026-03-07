import 'package:flutter/material.dart';

import '../../services/vendor_service.dart';
import '../../services/socket_service.dart';

class VendorOrdersScreen extends StatefulWidget {
  VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  bool loading = true;
  List orders = [];

  @override
  void initState() {
    super.initState();
    loadOrders();
    listenForOrders();
  }

  Future<void> loadOrders() async {
    final res = await VendorService.getOrders();
    setState(() {
      orders = res;
      loading = false;
    });
  }

  void listenForOrders() {
    SocketService.on("new_order", (data) {
        if (!mounted) return;

        setState(() {
        orders.insert(0, data);
        });
    });
    }

  @override
    void dispose() {
    SocketService.off("new_order");
    super.dispose();
    }

  Future<void> acceptOrder(String id) async {
    await VendorService.updateOrderStatus(id, "accepted");
    loadOrders();
    }

 Future<void> rejectOrder(String id) async {
    await VendorService.updateOrderStatus(id, "rejected");
    loadOrders();
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        backgroundColor: Colors.blue,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text("No orders yet"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final order = orders[i];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order #${order["_id"]}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("Items: ${order["items"].length}"),
                            Text("Status: ${order["status"]}"),
                            const SizedBox(height: 12),

                            if (order["status"] == "pending")
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          acceptOrder(order["_id"]),
                                      child: const Text("Accept"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          rejectOrder(order["_id"]),
                                      child: const Text("Reject"),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
