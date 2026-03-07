import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../services/api_service.dart';
import 'vendor_details_screen.dart';
import 'all_vendors_screen.dart';
import 'dish_detail_screen.dart';
import '../../shared/widgets/ad_banner.dart';
import '../../core/theme/customer_theme.dart';
import 'location_picker_screen.dart';
import '../../utils/session.dart';
import '../../core/cart/cart_provider.dart';

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
  bool loading = true;
  Map<String, double>? selectedLocation;

  @override
  void initState() {
    super.initState();
    loadLocation();
    loadAll();
  }

  Future<void> loadLocation() async {
    final loc = await Session.getLocation();
    if (!mounted) return;
    setState(() => selectedLocation = loc);
  }

  Future<void> loadAll() async {
    try {
      final results = await Future.wait([
        CustomerVendorService.getVendors(),
        _loadPopularDishes(),
      ]);
      if (!mounted) return;
      setState(() {
        allVendors = results[0] as List<Vendor>;
        popularDishes = results[1] as List<PopularDish>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<List<PopularDish>> _loadPopularDishes() async {
    try {
      final res = await ApiService.get("/vendors/popular-dishes?limit=10");
      if (res is! List) return [];
      return res.map((e) => PopularDish.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Foodrena"),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        // Profile icon removed — accessible via bottom nav "Profile" tab
      ),
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
                      _vendorsSection(),
                      if (popularDishes.isNotEmpty) _popularDishesSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Delivering to",
                  style: TextStyle(fontSize: 12, color: CustomerColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                selectedLocation == null ? "Choose location" : "Location selected",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () async {
              final result = await Navigator.push<Map<String, double>>(
                context,
                MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
              );
              if (result != null) setState(() => selectedLocation = result);
            },
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search kitchens or dishes",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CustomerColors.primary, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CustomerColors.primary, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CustomerColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _adsSection() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(width: 300, child: AdBanner()),
      ),
    );
  }

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
              height: 170,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onSeeMore != null)
            GestureDetector(
              onTap: onSeeMore,
              child: Text("See all",
                  style: TextStyle(
                      fontSize: 13,
                      color: CustomerColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _vendorCard(Vendor vendor) {
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
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: CustomerColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: vendor.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(vendor.logoUrl!,
                          fit: BoxFit.cover, width: double.infinity),
                    )
                  : const Center(child: Icon(Icons.store, size: 40)),
            ),
            const SizedBox(height: 8),
            Text(vendor.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              vendor.isOpen ? "Open now" : "Closed",
              style: TextStyle(
                  fontSize: 12,
                  color: vendor.isOpen ? Colors.green : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

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
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: CustomerColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: dish.imageUrl != null
                    ? Image.network(dish.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _DishPlaceholder())
                    : const _DishPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text("₦${dish.price.toStringAsFixed(0)}",
                      style: TextStyle(
                          color: CustomerColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(dish.vendorName ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
        child: Icon(Icons.fastfood, color: Colors.grey, size: 32),
      ),
    );
  }
}