import 'package:flutter/material.dart';
import '../../../services/order_service.dart';
import '../../../core/theme/customer_theme.dart';
import 'order_detail_screen.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  bool _isActive(String status) {
    return !['delivered', 'cancelled', 'refunded'].contains(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: const Text("My Orders")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: OrderService.fetchMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No orders yet",
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          final activeOrders = snapshot.data!
              .where((o) => _isActive(o['status'] ?? ''))
              .toList();
          final historyOrders = snapshot.data!
              .where((o) => !_isActive(o['status'] ?? ''))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeOrders.isNotEmpty) ...[
                const Text("Active Orders",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...activeOrders.map((o) => _orderTile(context, o)),
                const SizedBox(height: 24),
              ],
              if (historyOrders.isNotEmpty) ...[
                const Text("Order History",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...historyOrders.map((o) => _orderTile(context, o)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _orderTile(BuildContext context, Map<String, dynamic> order) {
    final orderId = (order['_id'] ?? '').toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final status = order['status'] ?? '';
    final total = order['total'] ?? order['totalAmount'] ?? 0;
    final vendor = order['vendor'];
    final vendorName =
        vendor?['businessName'] ?? vendor?['name'] ?? 'Unknown';

    // Items summary
    final items = order['items'] is List ? order['items'] as List : [];
    String itemsSummary = '';
    if (items.isNotEmpty) {
      final first = items.first;
      final name = first['name'] ??
          first['menuItem']?['name'] ??
          first['item']?['name'] ??
          'Item';
      itemsSummary =
          items.length > 1 ? '$name +${items.length - 1} more' : name;
    }

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'refunded':
        statusColor = Colors.purple;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CustomerColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long,
                  color: CustomerColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #$shortId',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text('₦$total',
                          style: TextStyle(
                              color: CustomerColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(vendorName,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  if (itemsSummary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(itemsSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}