import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/customer_wallet_service.dart';
import '../../services/notification_store.dart';
import '../../core/theme/app_theme.dart';
import '../shared/chat_screen.dart';
import '../shared/incoming_call_screen.dart';
import '../../services/notification_service.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  final VoidCallback? onDone;

  const OrderStatusScreen({super.key, required this.orderId, this.onDone});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  String status = "pending";
  String _riderName = "Rider";
  int _unreadCount = 0;

  GoogleMapController? mapController;
  Marker? riderMarker;
  LatLng? riderPosition;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentStatus();
    _connectAndListen();
  }

  Future<void> _connectAndListen() async {
    await SocketService.connectToRoom("order_${widget.orderId}");

    // Listen for incoming calls
    SocketService.on(
      "call_invite",
      (data) {
        if (!mounted) return;
        final callOrderId = data["orderId"]?.toString() ?? "";
        if (callOrderId != widget.orderId) return;

        final callerName  = data["callerName"] ?? "Rider";
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
              senderRole:  "customer",
              channelName: channelName,
              appId:       appId,
              token:       token,
            ),
          ),
        );
      },
      handlerId: "order_status_${widget.orderId}",
    );

    // Listen for incoming chat messages
    SocketService.on(
      "receive_message",
      (data) {
        if (!mounted) return;
        final msgOrderId = data["orderId"]?.toString() ?? "";
        if (msgOrderId != widget.orderId) return;
        final senderRole = data["senderRole"] ?? "";
        if (senderRole == "customer") return;

        setState(() => _unreadCount++);

        NotificationStore.instance.add(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "New message from $_riderName",
          body: data["text"] ?? "New message",
          type: "chat",
          receivedAt: DateTime.now(),
        ));

        NotificationService.showChatNotification(
          title: "New message from $_riderName",
          body: data["text"] ?? "New message",
          orderId: widget.orderId,
        );
      },
      handlerId: "order_status_msg_${widget.orderId}",
    );

    SocketService.on(
      "order_status_update",
      (data) {
        if (!mounted) return;
        final incomingId =
            data["orderId"]?.toString() ?? data["_id"]?.toString();
        if (incomingId != widget.orderId) return;
        final newStatus = data["status"] as String?;
        if (newStatus != null) setState(() => status = newStatus);
      },
      handlerId: "order_status_update_${widget.orderId}",
    );

    SocketService.on(
      "rider_live_location",
      (data) {
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
      },
      handlerId: "order_status_loc_${widget.orderId}",
    );
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final res = await ApiService.get("/orders/${widget.orderId}");
      if (!mounted) return;
      if (res is Map) {
        setState(() {
          if (res["status"] != null) status = res["status"];
          final rider = res["rider"];
          if (rider is Map) {
            _riderName =
                rider["user"]?["name"] ?? rider["name"] ?? "Rider";
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel order?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "This order will be cancelled. If you paid online, the amount will be refunded to your wallet.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Keep order",
                style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, cancel"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      final res =
          await CustomerWalletService.cancelOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        status = 'cancelled';
        _cancelling = false;
      });
      final refunded = res['refunded'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refunded
              ? "Order cancelled. Refund sent to your wallet 💰"
              : "Order cancelled successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  @override
  void dispose() {
    SocketService.emit("leaveRoom", widget.orderId);
    SocketService.off("call_invite",
        handlerId: "order_status_${widget.orderId}");
    SocketService.off("receive_message",
        handlerId: "order_status_msg_${widget.orderId}");
    SocketService.off("order_status_update",
        handlerId: "order_status_update_${widget.orderId}");
    SocketService.off("rider_live_location",
        handlerId: "order_status_loc_${widget.orderId}");
    mapController?.dispose();
    super.dispose();
  }

  bool get _isTerminal =>
      status == "delivered" || status == "cancelled";

  bool get _isPending => status == "pending";

  void _openChat() {
    setState(() => _unreadCount = 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: widget.orderId,
          senderRole: "customer",
          recipientName: _riderName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRider = [
      "rider_assigned",
      "arrived_at_pickup",
      "picked_up",
      "on_the_way"
    ].contains(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Status"),
        automaticallyImplyLeading: false,
        leading: _isTerminal
            ? const SizedBox()
            : BackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: _isTerminal ? _terminalView() : _trackingView(),
      floatingActionButton: hasRider
          ? FloatingActionButton(
              onPressed: _openChat,
              backgroundColor: CustomerColors.primary,
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
            )
          : null,
    );
  }

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
                  : "This order was cancelled. Any refund has been sent to your wallet.",
              style:
                  const TextStyle(color: Colors.grey, fontSize: 14),
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
                onPressed: () {
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "Back to Home",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackingView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _progressSteps(),
        ),
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
                        style:
                            const TextStyle(color: Colors.grey),
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
                  markers:
                      riderMarker != null ? {riderMarker!} : {},
                  onMapCreated: (c) => mapController = c,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (_isPending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red),
                          )
                        : const Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 18),
                    label: Text(
                      _cancelling
                          ? "Cancelling..."
                          : "Cancel Order",
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Colors.red, width: 1.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                    onPressed:
                        _cancelling ? null : _confirmCancel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressSteps() {
    final steps = [
      {
        "status": "accepted",
        "label": "Accepted",
        "icon": Icons.thumb_up
      },
      {
        "status": "preparing",
        "label": "Preparing",
        "icon": Icons.restaurant
      },
      {
        "status": "on_the_way",
        "label": "On the way",
        "icon": Icons.directions_bike
      },
      {
        "status": "delivered",
        "label": "Delivered",
        "icon": Icons.done_all
      },
    ];

    final statusOrder = [
      "pending",
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
        final stepIndex =
            statusOrder.indexOf(step["status"] as String);
        final isDone = currentIndex >= stepIndex;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDone
                          ? Colors.green
                          : Colors.grey.shade200,
                      child: Icon(
                        step["icon"] as IconData,
                        size: 14,
                        color:
                            isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step["label"] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDone
                            ? Colors.green
                            : Colors.grey,
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
      case "pending":
        return "Waiting for the vendor to accept your order...";
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
      case "pending":
        return {
          "icon": Icons.hourglass_top,
          "color": Colors.orange,
          "label": "Awaiting vendor"
        };
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
      case "pending":
        return "Your order has been placed and is waiting for the vendor.";
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