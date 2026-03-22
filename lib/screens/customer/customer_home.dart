import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../services/api_service.dart';
import '../../services/customer_wallet_service.dart';
import 'vendor_details_screen.dart';
import 'all_vendors_screen.dart';
import 'dish_detail_screen.dart';
import '../../shared/widgets/ad_banner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cart/cart_provider.dart';
import '../../utils/session.dart';
import '../customer/orders/customer_orders_screen.dart';
import '../package/package_delivery_screen.dart';
import 'customer_wallet_screen.dart';
import '../../widgets/notification_bell.dart';

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
  double? _walletBalance;
  Map<String, double> _distanceCache = {};
  int _selectedCategory = -1;

  static const _categories = [
    {"label": "Swallow",  "icon": "🍲"},
    {"label": "Drinks",   "icon": "🥤"},
    {"label": "Snacks",   "icon": "🍿"},
    {"label": "Soups",    "icon": "🍜"},
    {"label": "Pasta",    "icon": "🍝"},
    {"label": "Burgers",  "icon": "🍔"},
    {"label": "Shawarma", "icon": "🌯"},
    {"label": "Rice",     "icon": "🍚"},
    {"label": "Cakes",    "icon": "🎂"},
    {"label": "Grills",   "icon": "🍖"},
  ];

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      final name = await Session.getUserName();
      double? lat, lng;
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
          lat = pos.latitude;
          lng = pos.longitude;
          await Session.saveLocation(lat, lng);
        }
      } catch (_) {
        final loc = await Session.getLocation();
        lat = loc?['lat'];
        lng = loc?['lng'];
      }

      final results = await Future.wait([
        CustomerVendorService.getVendors(
          lat: lat,
          lng: lng,
          category: _selectedCategory == -1
              ? null
              : _categories[_selectedCategory]["label"],
        ),
        _loadPopularDishes(),
        _loadRecentOrders(),
        CustomerWalletService.getBalance(),
      ]);
      if (!mounted) return;
      setState(() {
        userName = name;
        allVendors = results[0] as List<Vendor>;
        popularDishes = results[1] as List<PopularDish>;
        recentOrders = results[2] as List<Map<String, dynamic>>;
        _walletBalance = results[3] as double;
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
      double? userLat, userLng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 6),
        );
        userLat = pos.latitude;
        userLng = pos.longitude;
        await Session.saveLocation(userLat, userLng);
      } catch (_) {}

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

  Future<void> _reloadVendors() async {
    try {
      double? lat, lng;
      final loc = await Session.getLocation();
      lat = loc?['lat'];
      lng = loc?['lng'];
      final category = _selectedCategory == -1
          ? null
          : _categories[_selectedCategory]["label"];
      debugPrint("🔍 Loading vendors with category: $category");
      final vendors = await CustomerVendorService.getVendors(
          lat: lat, lng: lng, category: category);
      debugPrint("✅ Got ${vendors.length} vendors for category: $category");
      if (!mounted) return;
      setState(() => allVendors = vendors);
      _calculateDistances();
    } catch (e) {
      debugPrint("❌ _reloadVendors error: $e");
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? CustomerColors.backgroundDark : CustomerColors.background;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(
                color: CustomerColors.primary))
            : RefreshIndicator(
                color: CustomerColors.primary,
                onRefresh: loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      _adsSection(),
                      const SizedBox(height: 14),
                      _packageDeliveryBanner(),
                      const SizedBox(height: 20),
                      _categoriesSection(),
                      if (recentOrders.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _recentOrdersSection(),
                      ],
                      const SizedBox(height: 20),
                      if (popularDishes.isNotEmpty) _popularDishesSection(),
                      const SizedBox(height: 20),
                      _vendorsSection(),
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
    final dark = _isDark;
    final nameColor = dark ? Colors.white : const Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: nameColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text("👋", style: TextStyle(fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          _walletChip(dark),
          const SizedBox(width: 10),
          NotificationBell(
            color: dark ? Colors.white : const Color(0xFF1A1A1A),
            badgeColor: CustomerColors.primary,
            fullScreen: true,
          ),
          const SizedBox(width: 8),
          Image.asset('assets/images/foodrena_logo2.png', height: 26),
        ],
      ),
    );
  }

  Widget _walletChip(bool dark) {
    final balance = _walletBalance ?? 0;
    final chipBg = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor = dark ? Colors.grey.shade700 : Colors.grey.shade200;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerWalletScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: CustomerColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 11),
            ),
            const SizedBox(width: 5),
            Text(
              balance > 0 ? "₦${balance.toStringAsFixed(0)}" : "₦0",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: balance > 0
                    ? CustomerColors.primary
                    : (dark ? Colors.grey.shade500 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ADS ──────────────────────────────────────────────────────────────────
  Widget _adsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const AdBanner(),
      ),
    );
  }

  // ── PACKAGE BANNER ───────────────────────────────────────────────────────
  Widget _packageDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            borderRadius: BorderRadius.circular(16),
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
                    const Text('Send a Package',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Deliver anything across the city',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Send now',
                    style: TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CATEGORIES ───────────────────────────────────────────────────────────
  Widget _categoriesSection() {
    final dark = _isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text("Categories",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : Colors.black)),
        ),
        SizedBox(
          height: 66,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == i;
              return GestureDetector(
                onTap: () async {
                  final newCategory = _selectedCategory == i ? -1 : i;
                  setState(() => _selectedCategory = newCategory);
                  await _reloadVendors();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CustomerColors.primary
                        : (dark
                            ? const Color(0xFF2C1010)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? CustomerColors.primary
                          : (dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat["icon"]!,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        cat["label"]!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (dark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── RECENT ORDERS ────────────────────────────────────────────────────────
  Widget _recentOrdersSection() {
    final dark = _isDark;
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
      itemsSummary = items.length > 1 ? '$name +${items.length - 1} more' : name;
    }

    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor = dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final subtextColor = dark ? Colors.grey.shade400 : Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Recent order",
            onSeeMore: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CustomerOrdersScreen())),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CustomerOrdersScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
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
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: dark ? Colors.white : Colors.black)),
                        if (itemsSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(itemsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: subtextColor)),
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
                  Icon(Icons.chevron_right,
                      color: dark ? Colors.grey.shade500 : Colors.grey,
                      size: 20),
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
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  /// ── POPULAR DISHES — horizontal scroll ───────────────────────────────────
  Widget _popularDishesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionHeader("Most popular dishes"),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: popularDishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 140,
              child: _dishCard(popularDishes[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── NEARBY KITCHENS ──────────────────────────────────────────────────────
  Widget _vendorsSection() {
    // Filter vendors by selected category if one is active
    final filtered = _selectedCategory == -1
        ? allVendors
        : allVendors.where((v) {
            // vendor has at least one menu item in this category
            // since vendor model may not carry menuItems on list endpoint,
            // we fall back to showing all if no category data
            return true; // backend already filters via getVendors with category
          }).toList();

    final selectedLabel = _selectedCategory == -1
        ? "Nearby kitchens"
        : "${_categories[_selectedCategory]["label"]} kitchens";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionHeader(
            selectedLabel,
            onSeeMore: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AllVendorsScreen(vendors: allVendors)),
            ),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    "No kitchens for this category",
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _vendorCard(filtered[i]),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onSeeMore}) {
    final dark = _isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : Colors.black)),
          if (onSeeMore != null)
            GestureDetector(
              onTap: onSeeMore,
              child: const Text("See all",
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
    final dark = _isDark;
    final rating = vendor.rating ?? 0;
    final dist = _distanceCache[vendor.id];
    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor = dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final nameColor = dark ? Colors.white : Colors.black;
    final distColor = dark ? Colors.grey.shade400 : Colors.grey.shade500;

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
                  child: VendorDetailsScreen(vendor: vendor));
            },
          ),
        );
      },
      child: SizedBox(
        width: 155,
        height: 150,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cardColor,
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: vendor.logoUrl != null
                      ? Image.network(vendor.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _vendorPlaceholder(dark))
                      : _vendorPlaceholder(dark),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vendor.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: nameColor)),
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
                                      ? (dark
                                          ? Colors.white70
                                          : Colors.black87)
                                      : distColor),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: distColor),
                            const SizedBox(width: 2),
                            Text(
                              dist != null
                                  ? _formatDistance(dist)
                                  : "Locating...",
                              style:
                                  TextStyle(fontSize: 10, color: distColor),
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

  Widget _vendorPlaceholder(bool dark) => Container(
        color: dark ? const Color(0xFF3A1515) : Colors.grey.shade100,
        child: Center(
            child: Icon(Icons.store,
                size: 30,
                color: dark ? Colors.grey.shade600 : Colors.grey)),
      );

  Widget _dishCard(PopularDish dish) {
    final dark = _isDark;
    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor = dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final nameColor = dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) {
            final cart = CartProvider.of(context);
            return CartProvider(
                controller: cart, child: DishDetailScreen(dish: dish));
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cardColor,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: SizedBox(
                  width: double.infinity,
                  child: dish.imageUrl != null
                      ? Image.network(dish.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _DishPlaceholder(dark: dark))
                      : _DishPlaceholder(dark: dark),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: nameColor)),
                  const SizedBox(height: 1),
                  Text("₦${dish.price.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: CustomerColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  Text(dish.vendorName ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 9)),
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
  final bool dark;
  const _DishPlaceholder({this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? const Color(0xFF3A1515) : Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.fastfood,
            color: dark ? Colors.grey.shade600 : Colors.grey, size: 24),
      ),
    );
  }
}