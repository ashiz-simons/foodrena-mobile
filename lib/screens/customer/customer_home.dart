import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../services/api_service.dart';
import 'vendor_details_screen.dart';
import 'all_vendors_screen.dart';
import 'dish_detail_screen.dart';
import '../../shared/widgets/ad_banner.dart';
import '../../core/theme/customer_theme.dart';
import '../../core/cart/cart_provider.dart';
import '../../utils/session.dart';
import '../../services/notification_store.dart';
import 'notifications_screen.dart';
import '../customer/orders/customer_orders_screen.dart';
import '../package/package_delivery_screen.dart';
import 'customer_search.dart';

class CustomerHome extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onRoleSwitch;

  const CustomerHome({
    super.key,
    required this.onLogout,
    required this.onRoleSwitch,
  });

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  List<Vendor> allVendors = [];
  List<PopularDish> popularDishes = [];
  List<Map<String, dynamic>> recentOrders = [];
  bool loading = true;
  String? userName;
  Map<String, double> _distanceCache = {};

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      final name = await Session.getUserName();
      final results = await Future.wait([
        CustomerVendorService.getVendors(),
        _loadPopularDishes(),
        _loadRecentOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        userName = name;
        allVendors = results[0] as List<Vendor>;
        popularDishes = results[1] as List<PopularDish>;
        recentOrders = results[2] as List<Map<String, dynamic>>;
        loading = false;
      });
      _calculateDistances();
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _calculateDistances() async {
    try {
      // Try to get fresh GPS first
      double? userLat, userLng;

      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 6),
          );
          userLat = pos.latitude;
          userLng = pos.longitude;
          await Session.saveLocation(userLat, userLng);
        }
      } catch (_) {}

      // Fall back to last saved location if GPS failed
      if (userLat == null || userLng == null) {
        final loc = await Session.getLocation();
        userLat = loc?['lat'];
        userLng = loc?['lng'];
      }

      if (userLat == null || userLng == null) return;

      final cache = <String, double>{};
      for (final v in allVendors) {
        if (v.lat != null && v.lng != null) {
          cache[v.id] = _haversine(userLat!, userLng!, v.lat!, v.lng!);
        }
      }
      if (mounted) setState(() => _distanceCache = cache);
    } catch (_) {}
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
    if (km < 1) return "${(km * 1000).round()}m";
    return "${km.toStringAsFixed(1)}km";
  }

  Future<List<PopularDish>> _loadPopularDishes() async {
    try {
      final res = await ApiService.get("/vendors/popular-dishes?limit=10");
      if (res is! List) return [];
      return res.map((e) => PopularDish.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentOrders() async {
    try {
      final res = await ApiService.get("/orders/my");
      if (res is! List) return [];
      final all = List<Map<String, dynamic>>.from(res);
      all.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      return all.take(1).toList();
    } catch (_) {
      return [];
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      _searchBar(),
                      _adsSection(),
                      _packageDeliveryBanner(),
                      if (recentOrders.isNotEmpty) _recentOrdersSection(),
                      _vendorsSection(),
                      if (popularDishes.isNotEmpty) _popularDishesSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────
  Widget _header() {
    final greeting = _getGreeting();
    final firstName = userName?.split(' ').first ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      firstName.isNotEmpty ? firstName : "Welcome",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text("👋", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          // Notification bell
          ListenableBuilder(
            listenable: NotificationStore.instance,
            builder: (context, _) {
              final unread = NotificationStore.instance.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.notifications_outlined,
                            size: 22, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: CustomerColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 15, minHeight: 15),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          // Logo — constrained so it never dominates the header
          Image.asset('assets/images/foodrena_logo2.png', height: 26),
        ],
      ),
    );
  }

  // ── SEARCH BAR ───────────────────────────────────────────────────────────
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerSearch()),
        ),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AbsorbPointer(
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Search kitchens or dishes...",
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon:
                    Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: CustomerColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ADS ──────────────────────────────────────────────────────────────────
  Widget _adsSection() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const AdBanner(),
        ),
      ),
    );
  }

  // ── PACKAGE BANNER ───────────────────────────────────────────────────────
  Widget _packageDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PackageDeliveryScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2D5986)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send a Package',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Deliver anything across the city',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Send now',
                  style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── RECENT ORDERS ────────────────────────────────────────────────────────
  Widget _recentOrdersSection() {
    final latest = recentOrders.first;
    final orderId = (latest['_id'] ?? '').toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final status = latest['status'] ?? '';
    final total = latest['total'] ?? latest['totalAmount'] ?? 0;

    final items = latest['items'];
    String itemsSummary = '';
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      final name = first['name'] ?? first['menuItem']?['name'] ?? 'Item';
      itemsSummary =
          items.length > 1 ? '$name +${items.length - 1} more' : name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Recent order",
            onSeeMore: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerOrdersScreen()),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerOrdersScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: CustomerColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: CustomerColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #$shortId',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        if (itemsSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(itemsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _statusBadge(status),
                            const SizedBox(width: 8),
                            Text('₦${total.toString()}',
                                style: const TextStyle(
                                    color: CustomerColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── VENDORS ──────────────────────────────────────────────────────────────
  Widget _vendorsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Nearby kitchens",
            onSeeMore: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllVendorsScreen(vendors: allVendors),
              ),
            ),
          ),
          if (allVendors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("No vendors available")),
            )
          else
            SizedBox(
              height: 185,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: allVendors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _vendorCard(allVendors[i]),
              ),
            ),
        ],
      ),
    );
  }

  // ── POPULAR DISHES ───────────────────────────────────────────────────────
  Widget _popularDishesSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Most popular dishes"),
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: popularDishes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _dishCard(popularDishes[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onSeeMore}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          if (onSeeMore != null)
            GestureDetector(
              onTap: onSeeMore,
              child: Text("See all",
                  style: TextStyle(
                      fontSize: 12,
                      color: CustomerColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ── VENDOR CARD ──────────────────────────────────────────────────────────
  Widget _vendorCard(Vendor vendor) {
    final rating = vendor.rating ?? 0;
    final dist   = _distanceCache[vendor.id];

    return GestureDetector(
      onTap: () {
        if (!vendor.isOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vendor is currently closed")),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) {
              final cart = CartProvider.of(context);
              return CartProvider(
                controller: cart,
                child: VendorDetailsScreen(vendor: vendor),
              );
            },
          ),
        );
      },
      child: SizedBox(
        width: 140,
        height: 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image: fixed 110px ────────────────────────────
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: vendor.logoUrl != null
                      ? Image.network(
                          vendor.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _vendorPlaceholder(),
                        )
                      : _vendorPlaceholder(),
                ),

                // ── Info: remaining 105px ─────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Name
                        Text(
                          vendor.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),

                        // Open/Closed + Rating
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: vendor.isOpen
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                vendor.isOpen ? "Open" : "Closed",
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: vendor.isOpen
                                        ? Colors.green.shade700
                                        : Colors.red.shade700),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 11),
                            const SizedBox(width: 1),
                            Text(
                              rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : "New",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: rating > 0
                                      ? Colors.black87
                                      : Colors.grey.shade500),
                            ),
                          ],
                        ),

                        // Distance
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11,
                                color: dist != null
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade300),
                            const SizedBox(width: 2),
                            Text(
                              dist != null
                                  ? _formatDistance(dist)
                                  : "Locating...",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: dist != null
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vendorPlaceholder() => Container(
        color: Colors.grey.shade100,
        child: const Center(
            child: Icon(Icons.store, size: 30, color: Colors.grey)),
      );


  Widget _dishCard(PopularDish dish) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) {
            final cart = CartProvider.of(context);
            return CartProvider(
              controller: cart,
              child: DishDetailScreen(dish: dish),
            );
          },
        ),
      ),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: dish.imageUrl != null
                    ? Image.network(dish.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _DishPlaceholder())
                    : const _DishPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text("₦${dish.price.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: CustomerColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 1),
                  Text(dish.vendorName ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishPlaceholder extends StatelessWidget {
  const _DishPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.fastfood, color: Colors.grey, size: 28),
      ),
    );
  }
}