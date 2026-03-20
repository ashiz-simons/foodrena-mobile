import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/rider_service.dart';
import '../../services/socket_service.dart';
import '../../core/theme/app_theme.dart';

const _kOnline = Color(0xFF00D97E);
const _kAmber = Color(0xFFFFC542);

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  bool _loading = true;
  bool _claiming = false;
  List _orders = [];
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getLocation();
    await _loadOrders();
    _listenForNewOrders();
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _loadOrders() async {
    try {
      final res = await RiderService.getAvailableOrders(
        lat: _lat,
        lng: _lng,
      );
      if (mounted) setState(() => _orders = res);
    } catch (e) {
      _showError("Failed to load orders");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForNewOrders() {
    SocketService.on("new_order_available", (data) {
      if (!mounted) return;
      _loadOrders();
      HapticFeedback.lightImpact();
    });
  }

  Future<void> _claimOrder(Map order) async {
    if (_claiming) return;
    final orderId = order["_id"] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Claim Order"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Delivery fee: ₦${order["deliveryFee"] ?? 0}"),
            const SizedBox(height: 4),
            Text("Deliver to: ${order["deliveryAddress"] ?? ""}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Claim",
                style: TextStyle(color: _kOnline, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _claiming = true);
    try {
      await RiderService.claimOrder(orderId);
      _showSnack("Order claimed! Head to pickup.");
      if (mounted) setState(() => _orders.removeWhere((o) => o["_id"] == orderId));
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _kOnline),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    SocketService.off("new_order_available");
    super.dispose();
  }

  bool _dark() => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final dark = _dark();
    final bg = dark ? RiderColors.backgroundDark : RiderColors.background;
    final card = dark ? RiderColors.surfaceDark : RiderColors.surface;
    final text = dark ? RiderColors.textDark : RiderColors.text;
    final muted = dark ? RiderColors.mutedDark : RiderColors.muted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Available Orders",
            style: TextStyle(
                color: text, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kOnline),
            onPressed: () {
              setState(() => _loading = true);
              _loadOrders();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOnline))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delivery_dining_rounded,
                          size: 56, color: muted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text("No available orders nearby",
                          style: TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text("Pull to refresh or wait for new orders",
                          style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadOrders();
                        },
                        icon: const Icon(Icons.refresh_rounded,
                            color: _kOnline),
                        label: const Text("Refresh",
                            style: TextStyle(color: _kOnline)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kOnline,
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _orderCard(
                      order: _orders[i],
                      card: card,
                      text: text,
                      muted: muted,
                    ),
                  ),
                ),
    );
  }

  Widget _orderCard({
    required Map order,
    required Color card,
    required Color text,
    required Color muted,
  }) {
    final orderId = order["_id"] as String? ?? "";
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final deliveryFee = order["deliveryFee"] ?? 0;
    final deliveryAddress = order["deliveryAddress"] ?? "";
    final items = order["items"] as List? ?? [];
    final vendor = order["vendor"];
    final vendorName = vendor is Map
        ? (vendor["businessName"] ?? vendor["name"] ?? "Vendor")
        : "Vendor";
    final distanceKm = (order["distanceKm"] ?? 0).toDouble();
    final isPackage = order["type"] == "package";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kOnline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_dark() ? 0.15 : 0.04),
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
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(
                    isPackage
                        ? Icons.inventory_2_rounded
                        : Icons.receipt_long_rounded,
                    size: 15,
                    color: _kOnline,
                  ),
                  const SizedBox(width: 6),
                  Text("Order #$shortId",
                      style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ]),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kOnline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("₦$deliveryFee",
                      style: const TextStyle(
                          color: _kOnline,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Vendor & distance
            Row(children: [
              Icon(Icons.storefront_rounded, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(vendorName,
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(width: 12),
              Icon(Icons.location_on_rounded, size: 13, color: muted),
              const SizedBox(width: 4),
              Text("${distanceKm.toStringAsFixed(1)} km away",
                  style: TextStyle(color: muted, fontSize: 12)),
            ]),

            const SizedBox(height: 8),

            // Items or package
            if (isPackage)
              Text("📦 Package delivery",
                  style: TextStyle(color: text, fontSize: 13))
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kOnline.withOpacity(0.5),
                        ),
                      ),
                      Text("${item["name"]} × ${item["quantity"]}",
                          style: TextStyle(color: text, fontSize: 13)),
                    ]),
                  )),

            const SizedBox(height: 8),

            // Delivery address
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.place_rounded, size: 13, color: muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(deliveryAddress,
                    style: TextStyle(color: muted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),

            const SizedBox(height: 14),

            // Claim button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _claiming ? null : () => _claimOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOnline,
                  disabledBackgroundColor: _kOnline.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _claiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(_claiming ? "Claiming..." : "Claim Order",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}