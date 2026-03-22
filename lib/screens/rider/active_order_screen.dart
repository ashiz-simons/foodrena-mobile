import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/rider_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_store.dart';
import '../../core/theme/app_theme.dart';
import '../shared/chat_screen.dart';
import '../shared/incoming_call_screen.dart';

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
  int _unreadCount = 0;
  String _customerName = "Customer";

  GoogleMapController? mapController;
  LatLng? currentPosition;
  Marker? riderMarker;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _dark ? const Color(0xFF2A1E0C) : Colors.white;
  Color get _border => _dark ? Colors.grey.shade800 : Colors.grey.shade200;
  Color get _text => _dark ? Colors.white : Colors.black;
  Color get _sub => _dark ? Colors.grey.shade400 : Colors.grey;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    _customerName = order["user"]?["name"] ?? "Customer";
    _joinOrderRoom();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _updateRiderPosition(const LatLng(6.5244, 3.3792));
    });
  }

  Future<void> _joinOrderRoom() async {
    final roomOrderId = (order["_id"] ?? "").toString();
    if (roomOrderId.isEmpty) return;
    await SocketService.connectToRoom("order_$roomOrderId");

    SocketService.on(
      "call_invite",
      (data) {
        if (!mounted) return;
        final callOrderId = data["orderId"]?.toString() ?? "";
        if (callOrderId != roomOrderId) return;

        final callerName  = data["callerName"] ?? "Customer";
        final channelName = data["channelName"] ?? callOrderId;
        final appId       = data["appId"] ?? "e03b6ecb7bcf4e279d314411ec817e7e";
        final token       = data["token"];

        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallScreen(
              orderId:     callOrderId,
              callerName:  callerName,
              senderRole:  "rider",
              channelName: channelName,
              appId:       appId,
              token:       token,
            ),
          ),
        );
      },
      handlerId: "active_order_$roomOrderId",
    );

    SocketService.on(
      "receive_message",
      (data) {
        if (!mounted) return;
        final msgOrderId = data["orderId"]?.toString() ?? "";
        if (msgOrderId != roomOrderId) return;
        final senderRole = data["senderRole"] ?? "";
        if (senderRole == "rider") return;

        setState(() => _unreadCount++);

        NotificationStore.instance.add(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "New message from $_customerName",
          body: data["text"] ?? "New message",
          type: "chat",
          receivedAt: DateTime.now(),
        ));
      },
      handlerId: "active_order_msg_$roomOrderId",
    );
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
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Future<void> updateStatus(String action) async {
    setState(() => loading = true);
    try {
      if (action == "arrived")    await RiderService.arrived(order["_id"]);
      if (action == "start-trip") await RiderService.startTrip(order["_id"]);
      if (action == "complete")   await RiderService.complete(order["_id"]);
      if (mounted) setState(() {});
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    final orderId = (order["_id"] ?? "").toString();
    SocketService.off("call_invite",       handlerId: "active_order_$orderId");
    SocketService.off("receive_message",   handlerId: "active_order_msg_$orderId");
    SocketService.emit("leaveRoom", orderId);
    super.dispose();
  }

  Widget buildActionButton() {
    switch (order["status"]) {
      case "accepted":
        return _actionBtn("Mark Arrived", "arrived", Colors.blue);
      case "arrived":
        return _actionBtn("Start Trip", "start-trip", Colors.orange);
      case "in_transit":
        return _actionBtn("Complete Delivery", "complete", Colors.green);
      case "completed":
        return const Center(
          child: Text("Delivery Completed",
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)));
      default:
        return const SizedBox();
    }
  }

  Widget _actionBtn(String text, String action, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: loading ? null : () => updateStatus(action),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
    final customerName  = order["user"]?["name"] ?? "Customer";
    final customerPhone = order["user"]?["phone"] ?? "";
    final addrRaw = order["deliveryAddress"];
    String deliveryAddress = "No address provided";
    if (addrRaw is Map) {
      final parts = [addrRaw['street'], addrRaw['state'], addrRaw['city']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) deliveryAddress = parts.join(', ');
    } else if (addrRaw is String && addrRaw.isNotEmpty) {
      deliveryAddress = addrRaw;
    }
    final vendorName    = order["vendor"]?["businessName"] ??
        order["vendor"]?["name"] ?? "Vendor";
    final vendorAddress = order["pickupLocation"]?["address"] ?? "";
    final items = order["items"] is List ? order["items"] as List : [];
    final total       = order["total"] ?? 0;
    final deliveryFee = order["deliveryFee"] ?? 0;
    final orderId     = (order["_id"] ?? "").toString();
    final shortId     = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF1A1208) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Order #$shortId"),
        backgroundColor: dark ? const Color(0xFF1A1208) : null,
        foregroundColor: dark ? Colors.white : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() => _unreadCount = 0);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                orderId: orderId,
                senderRole: "rider",
                recipientName: _customerName,
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_rounded, color: Colors.white),
            if (_unreadCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadCount > 9 ? "9+" : "$_unreadCount",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MAPS_ENABLED
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition ??
                          const LatLng(6.5244, 3.3792),
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    markers:
                        riderMarker != null ? {riderMarker!} : {},
                    onMapCreated: (c) => mapController = c,
                  )
                : _MapPlaceholder(dark: dark),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoCard(
                    icon: Icons.person_outline,
                    iconColor: Colors.blue,
                    title: 'Customer',
                    dark: dark,
                    children: [
                      Text(customerName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _text)),
                      if (customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(customerPhone,
                            style:
                                TextStyle(fontSize: 13, color: _sub)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.orange,
                    title: 'Deliver to',
                    dark: dark,
                    children: [
                      Text(deliveryAddress,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _text)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    icon: Icons.store_outlined,
                    iconColor: Colors.green,
                    title: 'Pick up from',
                    dark: dark,
                    children: [
                      Text(vendorName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _text)),
                      if (vendorAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(vendorAddress.toString(),
                            style:
                                TextStyle(fontSize: 12, color: _sub)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: Colors.purple,
                    title:
                        'Order (${items.length} item${items.length == 1 ? '' : 's'})',
                    dark: dark,
                    children: [
                      ...items.map((item) {
                        final name = item['name'] ??
                            item['menuItem']?['name'] ??
                            'Item';
                        final qty   = item['quantity'] ?? 1;
                        final price = item['price'] ?? 0;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Text('${qty}x ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _text)),
                              Expanded(
                                  child: Text(name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _text))),
                              Text('₦$price',
                                  style: TextStyle(
                                      fontSize: 13, color: _text)),
                            ],
                          ),
                        );
                      }),
                      Divider(height: 16, color: _border),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery fee',
                              style: TextStyle(
                                  fontSize: 13, color: _sub)),
                          Text('₦$deliveryFee',
                              style: TextStyle(
                                  fontSize: 13, color: _text)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _text)),
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
    required bool dark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color:
                  Colors.black.withOpacity(dark ? 0.2 : 0.03),
              blurRadius: 4),
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
                        color: _sub,
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
  final bool dark;
  const _MapPlaceholder({this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: dark ? const Color(0xFF2A1E0C) : Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 60, color: Colors.orange),
          const SizedBox(height: 12),
          Text('Tracking delivery…',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black)),
          const SizedBox(height: 6),
          Text('Live map will activate shortly',
              style: TextStyle(
                  color: dark
                      ? Colors.grey.shade400
                      : Colors.black54)),
        ],
      ),
    );
  }
}