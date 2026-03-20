import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/vendor_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/rider_service.dart';
import 'preferred_riders_screen.dart';

const _kTeal = Color(0xFF00B4B4);

class VendorOrdersScreen extends StatefulWidget {
  VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  bool loading = true;
  List orders = [];

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
  Color get _card => _dark ? const Color(0xFF0F2828) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);
  Color get _divider => _dark ? Colors.teal.withOpacity(0.15) : Colors.teal.withOpacity(0.08);

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
          _ActionButton(label: "Accept", color: _kTeal, icon: Icons.thumb_up_rounded, onTap: () => _updateStatus(id, "accepted")),
          _ActionButton(label: "Reject", color: Colors.redAccent, icon: Icons.cancel_rounded, onTap: () => _updateStatus(id, "cancelled")),
        ];
      case "accepted":
        return [
          _ActionButton(label: "Start Preparing", color: Colors.orange, icon: Icons.restaurant_rounded, onTap: () => _updateStatus(id, "preparing")),
        ];
      case "preparing":
        return [
          _ActionButton(label: "Find Rider", color: const Color(0xFF00C48C), icon: Icons.delivery_dining_rounded, onTap: () => _showFindRiderSheet(order)),
        ];
      default:
        return [];
    }
  }

  Future<void> _showFindRiderSheet(Map order) async {
    final id = order["_id"] as String;
    final pickup = order["pickupLocation"];
    final double? lat = pickup?["lat"]?.toDouble();
    final double? lng = pickup?["lng"]?.toDouble();

    List preferredRiderIds = [];
    List allRiders = [];
    bool loadingRiders = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            if (loadingRiders) {
              Future.wait([
                VendorService.getPreferredRiders(),
                if (lat != null && lng != null)
                  RiderService.getNearbyRiders(lat, lng)
                else
                  Future.value(<dynamic>[]),
              ]).then((results) {
                final prefRes = results[0] as Map<String, dynamic>;
                final nearbyRes = results[1] as List<dynamic>;
                final prefList = prefRes['preferredRiders'] as List? ?? [];
                final prefIds = prefList.map((r) => r['_id'].toString()).toSet();

                setSheet(() {
                  preferredRiderIds = prefIds.toList();
                  // Merge: preferred first (marked), then others not in preferred list
                  final preferred = nearbyRes
                      .where((r) => prefIds.contains(r['_id'].toString()))
                      .toList();
                  final others = nearbyRes
                      .where((r) => !prefIds.contains(r['_id'].toString()))
                      .toList();
                  allRiders = [...preferred, ...others];
                  loadingRiders = false;
                });
              });
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _muted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text("Find a Rider",
                      style: TextStyle(
                          color: _text, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("Choose a preferred rider or let the app auto-assign",
                      style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 20),

                  if (loadingRiders)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(color: _kTeal)),
                    )
                  else if (allRiders.isEmpty) ...[
                    // No riders found — show auto-assign only
                    _autoAssignTile(ctx, id),
                    const SizedBox(height: 12),
                    _managePreferredLink(ctx),
                  ] else ...[
                    // Section header
                    if (preferredRiderIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text("AVAILABLE RIDERS",
                            style: TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2)),
                      ),

                    // Rider list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allRiders.length,
                        itemBuilder: (_, i) {
                          final rider = allRiders[i];
                          final isPreferred = preferredRiderIds
                              .contains(rider['_id'].toString());
                          final name = rider['user']?['name'] ??
                              rider['name'] ?? 'Unknown';
                          final phone = rider['user']?['phone'] ??
                              rider['phone'] ?? '';
                          final imageUrl =
                              rider['profileImage']?['url'];
                          final riderId = rider['_id'] ?? '';
                          final distanceKm =
                              rider['distanceKm']?.toDouble() ?? 0.0;
                          final rating =
                              (rider['rating'] ?? 0).toDouble();
                          final ratingCount =
                              rider['ratingCount'] ?? 0;

                          return GestureDetector(
                            onTap: () async {
                              Navigator.pop(ctx);
                              // Directly assign this rider
                              try {
                                await ApiService.post(
                                    '/riders/assign/${order["_id"]}',
                                    {'riderId': riderId});
                                await loadOrders();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceAll('Exception: ', '')),
                                    backgroundColor: Colors.redAccent,
                                  ));
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isPreferred
                                      ? _kTeal.withOpacity(0.4)
                                      : _divider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            _kTeal.withOpacity(0.15),
                                        backgroundImage: imageUrl != null
                                            ? NetworkImage(imageUrl)
                                            : null,
                                        child: imageUrl == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                color: _kTeal,
                                                size: 20)
                                            : null,
                                      ),
                                      if (isPreferred)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: _kTeal,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.star_rounded,
                                                color: Colors.white,
                                                size: 10),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(name,
                                              style: TextStyle(
                                                  color: _text,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 14)),
                                          if (isPreferred) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _kTeal.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text("Preferred",
                                                  style: TextStyle(
                                                      color: _kTeal,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ],
                                        ]),
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          Icon(Icons.location_on_rounded,
                                              size: 11, color: _muted),
                                          const SizedBox(width: 2),
                                          Text(
                                              "${distanceKm.toStringAsFixed(1)} km away",
                                              style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 11)),
                                          if (rating > 0) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.star_rounded,
                                                size: 11,
                                                color: Color(0xFFFFC542)),
                                            const SizedBox(width: 2),
                                            Text(
                                                "${rating.toStringAsFixed(1)} ($ratingCount)",
                                                style: TextStyle(
                                                    color: _muted,
                                                    fontSize: 11)),
                                          ],
                                        ]),
                                        if (phone.isNotEmpty)
                                          Text(phone,
                                              style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 13, color: _muted),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    Divider(color: _muted.withOpacity(0.2)),
                    const SizedBox(height: 8),

                    // Auto-assign fallback
                    _autoAssignTile(ctx, id),
                    const SizedBox(height: 12),
                    _managePreferredLink(ctx),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _autoAssignTile(BuildContext ctx, String orderId) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(ctx);
        await _updateStatus(orderId, "searching_rider");
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00C48C).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00C48C).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C48C).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delivery_dining_rounded,
                  color: Color(0xFF00C48C), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Auto-Assign",
                      style: TextStyle(
                          color: _text, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text("Let the app find the nearest available rider",
                      style: TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _managePreferredLink(BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PreferredRidersScreen()));
      },
      child: Center(
        child: Text("Manage preferred riders",
            style: TextStyle(
                color: _kTeal,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: _kTeal)),
      ),
    );
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
      default:                  return const Color(0xFF6B8A8A);
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Orders",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
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
                      Icon(Icons.receipt_long_rounded, size: 52, color: _muted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text("No orders yet", style: TextStyle(color: _muted, fontSize: 15)),
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
    final status  = order["status"] as String? ?? "";
    final items   = order["items"] as List? ?? [];
    final total   = order["total"] ?? order["totalAmount"] ?? 0;
    final actions = _actionsFor(order);
    final isActive = status != "delivered" && status != "cancelled";
    final color   = _statusColor(status);
    final orderId = order["_id"] as String;
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.25) : Colors.teal.withOpacity(_dark ? 0.15 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? color.withOpacity(0.08) : Colors.black.withOpacity(_dark ? 0.15 : 0.03),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order #$shortId",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _text)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: _divider),
            const SizedBox(height: 10),

            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kTeal.withOpacity(0.5),
                        ),
                      ),
                      Text("${item["name"]} × ${item["quantity"]}",
                          style: TextStyle(fontSize: 13, color: _text)),
                    ],
                  ),
                )),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total", style: TextStyle(color: _muted, fontSize: 13)),
                Text("₦${total.toString()}",
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kTeal)),
              ],
            ),

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
                          border: Border.all(color: a.color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(a.icon, size: 15, color: a.color),
                            const SizedBox(width: 5),
                            Text(a.label,
                                style: TextStyle(color: a.color, fontSize: 12, fontWeight: FontWeight.w600)),
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
  _ActionButton({required this.label, required this.color, required this.icon, required this.onTap});
}