import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/rider_service.dart';

const bool MAPS_ENABLED = false;

class ActiveOrderScreen extends StatefulWidget {
  final Map order;

  const ActiveOrderScreen({super.key, required this.order});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  late Map order;
  bool loading = false;

  GoogleMapController? mapController;
  LatLng? currentPosition;
  Marker? riderMarker;

  @override
  void initState() {
    super.initState();
    order = widget.order;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _updateRiderPosition(const LatLng(6.5244, 3.3792));
    });
  }

  void _updateRiderPosition(LatLng position) {
    currentPosition = position;
    if (!MAPS_ENABLED) return;

    setState(() {
      riderMarker = Marker(
        markerId: const MarkerId("rider"),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    });

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> updateStatus(String action) async {
    setState(() => loading = true);
    try {
      if (action == "arrived") await RiderService.arrived(order["_id"]);
      if (action == "start-trip") await RiderService.startTrip(order["_id"]);
      if (action == "complete") await RiderService.complete(order["_id"]);
      if (mounted) setState(() {});
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Widget buildActionButton() {
    switch (order["status"]) {
      case "accepted":
        return buildButton("Mark Arrived", "arrived");
      case "arrived":
        return buildButton("Start Trip", "start-trip");
      case "in_transit":
        return buildButton("Complete Delivery", "complete");
      case "completed":
        return const Text("Delivery Completed",
            style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16));
      default:
        return const SizedBox();
    }
  }

  Widget buildButton(String text, String action) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : () => updateStatus(action),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerName = order["user"]?["name"] ?? "Customer";
    final customerPhone = order["user"]?["phone"] ?? "";
    // deliveryAddress is an object {street, city, state, lat, lng}
    final _addr = order["deliveryAddress"];
    String deliveryAddress = "No address provided";
    if (_addr is Map) {
      final parts = [
        _addr['street'],
        _addr['state'],
        _addr['city'],
      ].where((p) => p != null && p.toString().isNotEmpty).toList();
      if (parts.isNotEmpty) deliveryAddress = parts.join(', ');
    } else if (_addr is String && _addr.isNotEmpty) {
      deliveryAddress = _addr;
    }
    final vendorName = order["vendor"]?["businessName"] ??
        order["vendor"]?["name"] ??
        "Vendor";
    final vendorAddress = order["pickupLocation"]?["address"] ?? "";
    final items = order["items"] is List ? order["items"] as List : [];
    final total = order["total"] ?? 0;
    final deliveryFee = order["deliveryFee"] ?? 0;
    final orderId = (order["_id"] ?? "").toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text("Order #$shortId")),
      body: Column(
        children: [
          // Map / placeholder
          Expanded(
            flex: 2,
            child: MAPS_ENABLED
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition ?? const LatLng(6.5244, 3.3792),
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    markers: riderMarker != null ? {riderMarker!} : {},
                    onMapCreated: (c) => mapController = c,
                  )
                : const _MapPlaceholder(),
          ),

          // Details panel
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer info
                  _infoCard(
                    icon: Icons.person_outline,
                    iconColor: Colors.blue,
                    title: 'Customer',
                    children: [
                      Text(customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(customerPhone,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Delivery address
                  _infoCard(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.orange,
                    title: 'Deliver to',
                    children: [
                      Text(deliveryAddress.toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pickup location
                  _infoCard(
                    icon: Icons.store_outlined,
                    iconColor: Colors.green,
                    title: 'Pick up from',
                    children: [
                      Text(vendorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      if (vendorAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(vendorAddress.toString(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Items
                  _infoCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: Colors.purple,
                    title: 'Order (${items.length} item${items.length == 1 ? '' : 's'})',
                    children: [
                      ...items.map((item) {
                        final name = item['name'] ??
                            item['menuItem']?['name'] ??
                            'Item';
                        final qty = item['quantity'] ?? 1;
                        final price = item['price'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Text('${qty}x ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Expanded(
                                  child: Text(name,
                                      style:
                                          const TextStyle(fontSize: 13))),
                              Text('₦$price',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery fee',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          Text('₦$deliveryFee',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₦$total',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  buildActionButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.location_on, size: 60, color: Colors.orange),
          SizedBox(height: 12),
          Text('Tracking delivery…',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Live map will activate shortly',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}