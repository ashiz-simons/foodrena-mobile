import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/vendor_service.dart';
import '../../services/socket_service.dart';

const _kBg   = Color(0xFFF0FAFA);
const _kCard = Color(0xFFFFFFFF);
const _kTeal = Color(0xFF00B4B4);
const _kText = Color(0xFF1A1A1A);
const _kMuted= Color(0xFF6B8A8A);

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
      loadOrders();
    });
  }

  @override
  void dispose() {
    SocketService.off("new_order");
    super.dispose();
  }

  Future<void> _updateStatus(String id, String status) async {
    HapticFeedback.mediumImpact();
    await VendorService.updateOrderStatus(id, status);
    await loadOrders();
  }

  List<_ActionButton> _actionsFor(Map order) {
    final status = order["status"] as String? ?? "";
    final id = order["_id"] as String;
    switch (status) {
      case "pending":
        return [
          _ActionButton(label: "Accept",  color: _kTeal,          icon: Icons.thumb_up_rounded,   onTap: () => _updateStatus(id, "accepted")),
          _ActionButton(label: "Reject",  color: Colors.redAccent, icon: Icons.cancel_rounded,     onTap: () => _updateStatus(id, "cancelled")),
        ];
      case "accepted":
        return [
          _ActionButton(label: "Start Preparing", color: Colors.orange, icon: Icons.restaurant_rounded, onTap: () => _updateStatus(id, "preparing")),
        ];
      case "preparing":
        return [
          _ActionButton(label: "Find Rider", color: const Color(0xFF00C48C), icon: Icons.delivery_dining_rounded, onTap: () => _updateStatus(id, "searching_rider")),
        ];
      default:
        return [];
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case "pending":           return Colors.orange;
      case "accepted":          return _kTeal;
      case "preparing":         return Colors.purple;
      case "searching_rider":   return Colors.teal;
      case "rider_assigned":    return Colors.indigo;
      case "arrived_at_pickup": return Colors.deepPurple;
      case "picked_up":         return Colors.cyan.shade700;
      case "on_the_way":        return Colors.green;
      case "delivered":         return Colors.green.shade700;
      case "cancelled":         return Colors.redAccent;
      default:                  return _kMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "pending":           return "Awaiting Acceptance";
      case "accepted":          return "Accepted";
      case "preparing":         return "Preparing";
      case "searching_rider":   return "Finding Rider";
      case "rider_assigned":    return "Rider Assigned";
      case "arrived_at_pickup": return "Rider at Pickup";
      case "picked_up":         return "Picked Up";
      case "on_the_way":        return "On the Way";
      case "delivered":         return "Delivered";
      case "cancelled":         return "Cancelled";
      default:                  return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Orders",
            style: TextStyle(
                color: _kText, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kTeal),
            onPressed: loadOrders,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 52, color: _kMuted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      const Text("No orders yet",
                          style: TextStyle(color: _kMuted, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kTeal,
                  onRefresh: loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _orderCard(orders[i]),
                  ),
                ),
    );
  }

  Widget _orderCard(Map order) {
    final status   = order["status"] as String? ?? "";
    final items    = order["items"] as List? ?? [];
    final total    = order["total"] ?? order["totalAmount"] ?? 0;
    final actions  = _actionsFor(order);
    final isActive = status != "delivered" && status != "cancelled";
    final color    = _statusColor(status);
    final orderId  = (order["_id"] as String);
    final shortId  = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.25)
              : Colors.teal.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? color.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order #$shortId",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kText)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.teal.withOpacity(0.08)),
            const SizedBox(height: 10),

            // Items
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kTeal.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        "${item["name"]} × ${item["quantity"]}",
                        style: const TextStyle(
                            fontSize: 13, color: _kText),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total",
                    style: TextStyle(color: _kMuted, fontSize: 13)),
                Text("₦${total.toString()}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kTeal)),
              ],
            ),

            // Action buttons
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: actions.map((a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: a.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: a.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: a.color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(a.icon, size: 15, color: a.color),
                            const SizedBox(width: 5),
                            Text(a.label,
                                style: TextStyle(
                                    color: a.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )).toList(),
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
  _ActionButton({required this.label, required this.color,
      required this.icon, required this.onTap});
}