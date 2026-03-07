import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  String status = "accepted";

  GoogleMapController? mapController;
  Marker? riderMarker;
  LatLng? riderPosition;

  @override
  void initState() {
    super.initState();
    _fetchCurrentStatus();
    _connectAndListen();
  }

  Future<void> _connectAndListen() async {
    await SocketService.connectToRoom("order_${widget.orderId}");

    SocketService.on("order_status_update", (data) {
      if (!mounted) return;
      final incomingId =
          data["orderId"]?.toString() ?? data["_id"]?.toString();
      if (incomingId != widget.orderId) return;
      final newStatus = data["status"] as String?;
      if (newStatus != null) setState(() => status = newStatus);
    });

    SocketService.on("rider_live_location", (data) {
      if (!mounted) return;
      final incomingId = data["orderId"]?.toString();
      if (incomingId != null && incomingId != widget.orderId) return;

      final lat = data["lat"];
      final lng = data["lng"];
      if (lat == null || lng == null) return;

      final position = LatLng(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );

      setState(() {
        riderPosition = position;
        riderMarker = Marker(
          markerId: const MarkerId("rider"),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: "Your rider"),
        );
      });

      mapController?.animateCamera(CameraUpdate.newLatLng(position));
    });
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final res = await ApiService.get("/orders/${widget.orderId}");
      if (!mounted) return;
      if (res is Map && res["status"] != null) {
        setState(() => status = res["status"]);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SocketService.emit("leaveRoom", widget.orderId);
    SocketService.off("order_status_update");
    SocketService.off("rider_live_location");
    mapController?.dispose();
    super.dispose();
  }

  bool get _isTerminal =>
      status == "delivered" || status == "cancelled";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Status"),
        // ✅ Hide back button while order is active so user doesn't get lost
        automaticallyImplyLeading: _isTerminal,
      ),
      body: _isTerminal ? _terminalView() : _trackingView(),
    );
  }

  // ── Delivered / Cancelled full screen ────────────
  Widget _terminalView() {
    final delivered = status == "delivered";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: delivered
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                delivered ? Icons.check_circle : Icons.cancel,
                size: 60,
                color: delivered ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              delivered ? "Order Delivered!" : "Order Cancelled",
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              delivered
                  ? "Your order has been delivered. Enjoy your meal!"
                  : "This order was cancelled. You will be refunded if payment was made.",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      delivered ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(
                  delivered ? "Back to Home" : "Back to Home",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active tracking view ──────────────────────────
  Widget _trackingView() {
    return Column(
      children: [
        // ── Progress steps ──────────────────────────
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _progressSteps(),
        ),

        // ── Map ─────────────────────────────────────
        Expanded(
          flex: 3,
          child: riderPosition == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _waitingText(),
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: riderPosition!,
                    zoom: 15,
                  ),
                  markers: riderMarker != null ? {riderMarker!} : {},
                  onMapCreated: (c) => mapController = c,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
        ),

        // ── Status Panel ────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusWidget(),
              const SizedBox(height: 8),
              Text(
                _statusDescription(),
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step progress indicator ───────────────────────
  Widget _progressSteps() {
    final steps = [
      {"status": "accepted", "label": "Accepted", "icon": Icons.thumb_up},
      {"status": "preparing", "label": "Preparing", "icon": Icons.restaurant},
      {"status": "on_the_way", "label": "On the way", "icon": Icons.directions_bike},
      {"status": "delivered", "label": "Delivered", "icon": Icons.done_all},
    ];

    final statusOrder = [
      "accepted",
      "preparing",
      "searching_rider",
      "rider_assigned",
      "arrived_at_pickup",
      "picked_up",
      "on_the_way",
      "delivered",
    ];

    final currentIndex = statusOrder.indexOf(status);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final stepIndex = statusOrder.indexOf(step["status"] as String);
        final isDone = currentIndex >= stepIndex;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          isDone ? Colors.green : Colors.grey.shade200,
                      child: Icon(
                        step["icon"] as IconData,
                        size: 14,
                        color: isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step["label"] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDone ? Colors.green : Colors.grey,
                        fontWeight: isDone
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentIndex > stepIndex
                        ? Colors.green
                        : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _waitingText() {
    switch (status) {
      case "searching_rider":
        return "Finding a rider near the vendor...";
      case "rider_assigned":
        return "Rider assigned — waiting for location...";
      default:
        return "Waiting for rider location...";
    }
  }

  Widget _statusWidget() {
    final config = _statusConfig();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(config["icon"] as IconData,
            size: 30, color: config["color"] as Color),
        const SizedBox(width: 10),
        Text(
          config["label"] as String,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Map<String, dynamic> _statusConfig() {
    switch (status) {
      case "accepted":
        return {
          "icon": Icons.thumb_up,
          "color": Colors.blue,
          "label": "Order accepted"
        };
      case "preparing":
        return {
          "icon": Icons.restaurant,
          "color": Colors.orange,
          "label": "Preparing your food"
        };
      case "searching_rider":
        return {
          "icon": Icons.search,
          "color": Colors.orange,
          "label": "Finding a rider"
        };
      case "rider_assigned":
        return {
          "icon": Icons.delivery_dining,
          "color": Colors.blue,
          "label": "Rider heading to vendor"
        };
      case "arrived_at_pickup":
        return {
          "icon": Icons.store,
          "color": Colors.purple,
          "label": "Rider at vendor"
        };
      case "picked_up":
        return {
          "icon": Icons.shopping_bag,
          "color": Colors.indigo,
          "label": "Order picked up"
        };
      case "on_the_way":
        return {
          "icon": Icons.directions_bike,
          "color": Colors.green,
          "label": "On the way to you"
        };
      default:
        return {
          "icon": Icons.hourglass_top,
          "color": Colors.grey,
          "label": "Waiting..."
        };
    }
  }

  String _statusDescription() {
    switch (status) {
      case "accepted":
        return "The vendor has received your order.";
      case "preparing":
        return "The vendor is preparing your food.";
      case "searching_rider":
        return "We're finding the closest rider to your vendor.";
      case "rider_assigned":
        return "A rider has been assigned and is heading to the vendor.";
      case "arrived_at_pickup":
        return "Your rider has arrived at the vendor and is collecting your order.";
      case "picked_up":
        return "Your order has been picked up and is on its way.";
      case "on_the_way":
        return "Your rider is on the way to your location.";
      default:
        return "";
    }
  }
}