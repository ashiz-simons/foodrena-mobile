import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/customer_theme.dart';
import '../../core/cart/cart_provider.dart';

class CustomerSearch extends StatefulWidget {
  const CustomerSearch({super.key});

  @override
  State<CustomerSearch> createState() => _CustomerSearchState();
}

class _CustomerSearchState extends State<CustomerSearch> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Vendor> _allVendors = [];
  List<Vendor> _filteredVendors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    try {
      final vendors = await CustomerVendorService.getVendors();
      if (!mounted) return;
      setState(() {
        _allVendors = vendors;
        _filteredVendors = vendors;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredVendors = _allVendors;
      } else {
        _filteredVendors = _allVendors.where((v) {
          return v.businessName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openVendor(Vendor vendor) {
    if (!vendor.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This kitchen is currently closed")),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        backgroundColor: CustomerColors.background,
        elevation: 0,
        title: const Text(
          "Search Kitchens",
          style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
              fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVendors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isEmpty
                                  ? "No kitchens available"
                                  : "No results for \"${_searchCtrl.text}\"",
                              style: const TextStyle(
                                  color: CustomerColors.textMuted,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _filteredVendors.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final vendor = _filteredVendors[i];
                          return _vendorRow(vendor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _vendorRow(Vendor vendor) {
    final rating = vendor.rating ?? 0.0;
    return GestureDetector(
      onTap: () => _openVendor(vendor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 7,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 58,
                height: 58,
                child: vendor.logoUrl != null
                    ? Image.network(vendor.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _logoPlaceholder())
                    : _logoPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.businessName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: vendor.isOpen
                                  ? Colors.green.shade700
                                  : Colors.red.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        rating > 0
                            ? rating.toStringAsFixed(1)
                            : "New",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rating > 0
                                ? Colors.black87
                                : Colors.grey.shade500),
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

  Widget _logoPlaceholder() => Container(
        color: Colors.grey.shade100,
        child: const Icon(Icons.storefront,
            color: Colors.grey, size: 26),
      );

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search kitchens by name...",
          hintStyle:
              TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon:
              Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      size: 18, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: CustomerColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}