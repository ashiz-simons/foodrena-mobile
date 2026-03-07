import 'package:flutter/material.dart';
import '../../../services/order_service.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  bool _isActive(String status) {
    return !['delivered', 'cancelled', 'refunded'].contains(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: OrderService.fetchMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No orders yet"));
          }

          final activeOrders =
              snapshot.data!.where((o) => _isActive(o['status'])).toList();
          final historyOrders =
              snapshot.data!.where((o) => !_isActive(o['status'])).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeOrders.isNotEmpty) ...[
                const Text("Active Orders",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...activeOrders.map(_orderTile),
                const SizedBox(height: 24),
              ],
              if (historyOrders.isNotEmpty) ...[
                const Text("Order History",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...historyOrders.map(_orderTile),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _orderTile(Map order) {
    return Card(
      child: ListTile(
        title: Text("₦${order['total']}"),
        subtitle: Text(
          "${order['vendor']?['name'] ?? ''} • ${order['status']}",
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}