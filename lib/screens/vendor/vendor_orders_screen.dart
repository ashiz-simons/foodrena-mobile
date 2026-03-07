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
    _listenForOrders();
  }

  Future<void> loadOrders() async {
    final res = await VendorService.getOrders();
    if (mounted) setState(() { orders = res; loading = false; });
  }

  void _listenForOrders() {
    SocketService.on("new_order", (data) {
      if (!mounted) return;
      loadOrders(); // refresh full list so order has all fields
    });
  }

  @override
  void dispose() {
    SocketService.off("new_order");
    super.dispose();
  }

  Future<void> _updateStatus(String id, String status) async {
    await VendorService.updateOrderStatus(id, status);
    await loadOrders();
  }

  // ── What action buttons to show per status ──────────
  List<_ActionButton> _actionsFor(Map order) {
    final status = order["status"] as String? ?? "";
    final id = order["_id"] as String;

    switch (status) {
      case "pending":
        return [
          _ActionButton(
            label: "Accept Order",
            color: Colors.blue,
            icon: Icons.thumb_up,
            onTap: () => _updateStatus(id, "accepted"),
          ),
          _ActionButton(
            label: "Reject",
            color: Colors.red,
            icon: Icons.cancel,
            onTap: () => _updateStatus(id, "cancelled"),
          ),
        ];
      case "accepted":
        return [
          _ActionButton(
            label: "Start Preparing",
            color: Colors.orange,
            icon: Icons.restaurant,
            onTap: () => _updateStatus(id, "preparing"),
          ),
        ];
      case "preparing":
        return [
          _ActionButton(
            label: "Find Rider",
            color: Colors.green,
            icon: Icons.delivery_dining,
            onTap: () => _updateStatus(id, "searching_rider"),
          ),
        ];
      // Beyond this point rider handles progression
      case "searching_rider":
      case "rider_assigned":
      case "arrived_at_pickup":
      case "picked_up":
      case "on_the_way":
        return []; // rider is handling it, no vendor action needed
      default:
        return [];
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "pending": return Colors.orange;
      case "accepted": return Colors.blue;
      case "preparing": return Colors.purple;
      case "searching_rider": return Colors.teal;
      case "rider_assigned": return Colors.indigo;
      case "arrived_at_pickup": return Colors.deepPurple;
      case "picked_up": return Colors.cyan;
      case "on_the_way": return Colors.green;
      case "delivered": return Colors.green.shade700;
      case "cancelled": return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "pending": return "Awaiting Acceptance";
      case "accepted": return "Accepted";
      case "preparing": return "Preparing";
      case "searching_rider": return "Finding Rider";
      case "rider_assigned": return "Rider Assigned";
      case "arrived_at_pickup": return "Rider at Pickup";
      case "picked_up": return "Picked Up";
      case "on_the_way": return "On the Way";
      case "delivered": return "Delivered";
      case "cancelled": return "Cancelled";
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadOrders,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("No orders yet",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _orderCard(orders[i]),
                  ),
                ),
    );
  }

  Widget _orderCard(Map order) {
    final status = order["status"] as String? ?? "";
    final items = order["items"] as List? ?? [];
    final total = order["total"] ?? order["totalAmount"] ?? 0;
    final actions = _actionsFor(order);

    // Don't show delivered/cancelled orders prominently
    final isTerminal = status == "delivered" || status == "cancelled";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTerminal ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Order #${(order["_id"] as String).substring(0, 8)}...",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Items ─────────────────────────────────────
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    "• ${item["name"]} × ${item["quantity"]}",
                    style: const TextStyle(fontSize: 13),
                  ),
                )),

            const SizedBox(height: 8),

            Text(
              "Total: ₦${total.toString()}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),

            // ── Action Buttons ────────────────────────────
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: actions
                    .map((a) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: a.color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              icon: Icon(a.icon, size: 16),
                              label: Text(a.label,
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: a.onTap,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
}