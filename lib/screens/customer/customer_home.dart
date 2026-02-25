import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import 'vendor_details_screen.dart';
import '../../shared/widgets/ad_banner.dart';
import '../../core/theme/customer_theme.dart';
import 'all_vendors_screen.dart';
import 'location_picker_screen.dart';
import '../../utils/session.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  List<Vendor> allVendors = [];
  bool loading = true;

  Map<String, double>? selectedLocation;

  @override
  void initState() {
    super.initState();
    loadVendors();
    loadLocation();
  }

  Future<void> loadLocation() async {
    final loc = await Session.getLocation();
    setState(() {
      selectedLocation = loc;
    });
  }

  Future<void> loadVendors() async {
    try {
      final vendors = await CustomerVendorService.getVendors();
      setState(() {
        allVendors = vendors;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    _searchBar(),
                    _adsSection(),
                    _vendorsSection(),
                    _popularSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Delivering to",
                style: TextStyle(fontSize: 12, color: CustomerColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                selectedLocation == null
                    ? "Choose location"
                    : "Location selected",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () async {
              final result = await Navigator.push<Map<String, double>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const LocationPickerScreen(),
                ),
              );

              if (result != null) {
                setState(() {
                  selectedLocation = result;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= SEARCH =================
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search kitchens or dishes",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: CustomerColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ================= ADS =================
  Widget _adsSection() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 300,
          child: AdBanner(),
        ),
      ),
    );
  }

  // ================= VENDORS =================
  Widget _vendorsSection() {
    if (allVendors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("No vendors available")),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Nearby kitchens",
            onSeeMore: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllVendorsScreen(),
                ),
              );
            },
          ),
          SizedBox(
            height: 160,
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

  // ================= POPULAR =================
  Widget _popularSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Most popular"),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Popular dishes coming soon 🔥",
              style: TextStyle(color: CustomerColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ================= REUSABLE =================
  Widget _sectionHeader(String title, {VoidCallback? onSeeMore}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (onSeeMore != null)
            TextButton(onPressed: onSeeMore, child: const Text("See more")),
        ],
      ),
    );
  }

  Widget _vendorCard(Vendor vendor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailsScreen(vendor: vendor),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Center(
                child: Icon(
                  Icons.store,
                  size: 40,
                  color: CustomerColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vendor.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              vendor.isOpen ? "Open now" : "Closed",
              style: TextStyle(
                fontSize: 12,
                color: vendor.isOpen ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}