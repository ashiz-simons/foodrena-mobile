import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/rider_service.dart';

/// 🔧 Feature flag
/// Turn this ON after Google Console payment + API key
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

    /// MVP GPS simulation (safe even when maps are disabled)
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _updateRiderPosition(const LatLng(6.5244, 3.3792)); // Lagos fallback
    });
  }

  void _updateRiderPosition(LatLng position) {
    currentPosition = position;

    if (!MAPS_ENABLED) return;

    setState(() {
      riderMarker = Marker(
        markerId: const MarkerId("rider"),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    });

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> updateStatus(String action) async {
    setState(() => loading = true);

    try {
      if (action == "arrived") {
        await RiderService.arrived(order["_id"]);
        order["status"] = "arrived";
      }

      if (action == "start-trip") {
        await RiderService.startTrip(order["_id"]);
        order["status"] = "in_transit";
      }

      if (action == "complete") {
        await RiderService.complete(order["_id"]);
        order["status"] = "completed";
      }

      if (mounted) setState(() {});
    } catch (_) {
      // Silent fail for MVP stability
    }

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
        return const Text(
          "Delivery Completed",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );

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
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Delivery")),
      body: Column(
        children: [
          /// MAP / PLACEHOLDER
          Expanded(
            flex: 3,
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
                        riderMarker != null ? {riderMarker!} : <Marker>{},
                    onMapCreated: (c) => mapController = c,
                  )
                : const _MapPlaceholder(),
          ),

          /// DETAILS + ACTIONS
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order ID: ${order["_id"]}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text("Status: ${order["status"]}"),
                  const Spacer(),
                  buildActionButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🧱 Safe placeholder while Maps is disabled
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
          Icon(Icons.location_on, size: 60),
          SizedBox(height: 12),
          Text(
            'Tracking delivery…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Live map will activate shortly',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}