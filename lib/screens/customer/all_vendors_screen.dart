import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../models/vendor_model.dart';
import '../../utils/session.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cart/cart_provider.dart';

class AllVendorsScreen extends StatefulWidget {
  final List<Vendor> vendors;
  const AllVendorsScreen({super.key, required this.vendors});

  @override
  State<AllVendorsScreen> createState() => _AllVendorsScreenState();
}

class _AllVendorsScreenState extends State<AllVendorsScreen> {
  Map<String, double> _distanceCache = {};

  @override
  void initState() {
    super.initState();
    _calculateDistances();
  }

  Future<void> _calculateDistances() async {
    double? userLat;
    double? userLng;

    // 1. Try live GPS first (same as home screen)
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        userLat = pos.latitude;
        userLng = pos.longitude;
        // Save for future use
        await Session.saveLocation(userLat, userLng);
      }
    } catch (_) {}

    // 2. Fall back to saved location if GPS failed
    if (userLat == null || userLng == null) {
      final saved = await Session.getLocation();
      userLat = saved?['lat'];
      userLng = saved?['lng'];
    }

    if (userLat == null || userLng == null) return;

    final cache = <String, double>{};
    for (final v in widget.vendors) {
      if (v.lat != null && v.lng != null) {
        cache[v.id] = _haversine(userLat, userLng, v.lat!, v.lng!);
      }
    }
    if (mounted) setState(() => _distanceCache = cache);
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatDistance(double km) {
    if (km < 1) return "${(km * 1000).round()}m away";
    return "${km.toStringAsFixed(1)}km away";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All kitchens")),
      body: widget.vendors.isEmpty
          ? const Center(child: Text("No vendors available"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.vendors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _vendorRow(context, widget.vendors[i]),
            ),
    );
  }

  Widget _vendorRow(BuildContext context, Vendor vendor) {
    final rating = vendor.rating ?? 0.0;
    final ratingCount = vendor.ratingCount ?? 0;
    final distance = _distanceCache[vendor.id];

    return GestureDetector(
      onTap: () {
        if (!vendor.isOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("This kitchen is currently closed")),
          );
          return;
        }
        final cart = CartProvider.of(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartProvider(
              controller: cart,
              child: VendorDetailsScreen(vendor: vendor),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: vendor.logoUrl != null
                    ? Image.network(vendor.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _LogoPlaceholder())
                    : const _LogoPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor.businessName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: vendor.isOpen
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vendor.isOpen ? "Open" : "Closed",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: vendor.isOpen
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                      if (rating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 13),
                        const SizedBox(width: 2),
                        Text(
                          "${rating.toStringAsFixed(1)} ($ratingCount)",
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A)),
                        ),
                      ],
                    ],
                  ),
                  // Distance — shows "Locating..." until GPS resolves
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        distance != null
                            ? _formatDistance(distance)
                            : (vendor.lat != null
                                ? "Locating..."
                                : "Distance unavailable"),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: const Icon(Icons.storefront, color: Colors.grey, size: 28),
    );
  }
}