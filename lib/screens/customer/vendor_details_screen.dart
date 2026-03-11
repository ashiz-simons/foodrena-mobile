import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../core/cart/cart_provider.dart';
import '../../core/theme/customer_theme.dart';
import '../../utils/session.dart';
import 'dart:math' as math;
import 'dish_detail_screen.dart';

class VendorDetailsScreen extends StatefulWidget {
  final Vendor vendor;
  const VendorDetailsScreen({super.key, required this.vendor});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  late Future<List<MenuItem>> menuFuture;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    menuFuture = CustomerVendorService.getVendorMenu(widget.vendor.id);
    _calculateDistance();
  }

  Future<void> _calculateDistance() async {
    try {
      final loc = await Session.getLocation();
      if (loc == null) return;
      final userLat = loc['lat'] as double?;
      final userLng = loc['lng'] as double?;
      if (userLat == null || userLng == null) return;

      final v = widget.vendor;
      if (v.lat == null || v.lng == null) return;

      final d = _haversine(userLat, userLng, v.lat!, v.lng!);
      if (mounted) setState(() => _distanceKm = d);
    } catch (_) {}
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  String _formatDistance(double km) {
    if (km < 1) return "${(km * 1000).round()} m away";
    return "${km.toStringAsFixed(1)} km away";
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartProvider.of(context);
    final vendor = widget.vendor;
    final rating = vendor.rating ?? 0.0;
    final ratingCount = vendor.ratingCount ?? 0;

    return Scaffold(
      backgroundColor: CustomerColors.background,
      body: FutureBuilder<List<MenuItem>>(
        future: menuFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              // ── AppBar with vendor info ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      vendor.logoUrl != null
                          ? Image.network(vendor.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _logoPlaceholder())
                          : _logoPlaceholder(),
                      // Gradient overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                      // Vendor info overlay
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor.businessName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Open/closed badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: vendor.isOpen
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    vendor.isOpen ? "Open" : "Closed",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Rating badge
                                if (rating > 0) ...[
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 3),
                                  Text(
                                    "${rating.toStringAsFixed(1)} ($ratingCount)",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Distance badge
                                if (_distanceKm != null) ...[
                                  const Icon(Icons.location_on_outlined,
                                      color: Colors.white70, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatDistance(_distanceKm!),
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Menu content ──
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(snapshot.error.toString(),
                        textAlign: TextAlign.center),
                  ),
                )
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text("No menu available")),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final item = snapshot.data![i];
                        return _menuItemCard(item, cart);
                      },
                      childCount: snapshot.data!.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _menuItemCard(MenuItem item, dynamic cart) {
    return GestureDetector(
      onTap: () {
        final dish = PopularDish(
          id: item.id,
          name: item.name,
          price: item.price,
          orderCount: 0,
          imageUrl: item.imageUrl,
          vendorId: widget.vendor.id,
          vendorName: widget.vendor.businessName,
          vendorLogoUrl: widget.vendor.logoUrl,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CartProvider(
              controller: cart,
              child: DishDetailScreen(dish: dish),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _itemPlaceholder())
                  : _itemPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("₦${item.price.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: CustomerColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() => Container(
        color: Colors.grey.shade200,
        child: const Center(
            child: Icon(Icons.store, size: 60, color: Colors.grey)),
      );

  Widget _itemPlaceholder() => Container(
        width: 64,
        height: 64,
        color: Colors.grey.shade100,
        child: const Center(
            child: Icon(Icons.fastfood, color: Colors.grey, size: 28)),
      );
}