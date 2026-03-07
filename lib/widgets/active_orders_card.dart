import 'package:flutter/material.dart';
import '../services/order_service.dart';

class ActiveOrdersCard extends StatefulWidget {
  const ActiveOrdersCard({super.key});

  @override
  State<ActiveOrdersCard> createState() => _ActiveOrdersCardState();
}

class _ActiveOrdersCardState extends State<ActiveOrdersCard> {
  late Future<List<dynamic>> ordersFuture;

  @override
  void initState() {
    super.initState();
    ordersFuture = OrderService.getMyOrders();
  }

  bool isActive(String status) {
    return status != "completed" && status != "cancelled";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final activeOrders =
            snapshot.data!.where((o) => isActive(o["status"])).toList();

        if (activeOrders.isEmpty) return const SizedBox();

        return Card(
          margin: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Active Order",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Status: ${activeOrders[0]["status"]}"),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // later → navigate to order details / tracking
                    },
                    child: const Text("View Order"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}