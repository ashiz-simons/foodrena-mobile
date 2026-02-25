import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderMapScreen extends StatelessWidget {
  final double lat;
  final double lng;

  const RiderMapScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Map")),

      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId("rider"),
            position: LatLng(lat, lng),
          )
        },
      ),
    );
  }
}
