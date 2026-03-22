import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/api_service.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cart/cart_provider.dart';

class CustomerSearch extends StatefulWidget {
  const CustomerSearch({super.key});

  @override
  State<CustomerSearch> createState() => _CustomerSearchState();
}

class _CustomerSearchState extends State<CustomerSearch> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Vendor> _vendorResults = [];
  List<Map<String, dynamic>> _dishResults = [];
  bool _loading = false;
  bool _searched = false;
  String? _selectedCategory;

  static const _categories = [
    "Swallow", "Drinks", "Snacks", "Soups", "Pasta",
    "Burgers", "Shawarma", "Rice", "Cakes", "Grills",
  ];

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty && _selectedCategory == null) {
      setState(() {
        _vendorResults = [];
        _dishResults = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 400),
        () => _runSearch(query.trim()));
  }

  Future<void> _runSearch(String q) async {
    setState(() { _loading = true; _searched = true; });
    try {
      String url = "/vendors/search?";
      if (q.isNotEmpty) url += "q=${Uri.encodeComponent(q)}&";
      if (_selectedCategory != null) {
        url += "category=${Uri.encodeComponent(_selectedCategory!)}&";
      }
      final res = await ApiService.get(url);
      if (!mounted) return;
      final vendors = (res['vendors'] as List? ?? [])
          .map((e) => Vendor.fromJson(e))
          .toList();
      final dishes =
          List<Map<String, dynamic>>.from(res['dishes'] ?? []);
      setState(() {
        _vendorResults = vendors;
        _dishResults = dishes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory = _selectedCategory == cat ? null : cat;
    });
    _debounce?.cancel();
    _runSearch(_searchCtrl.text.trim());
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
              child: VendorDetailsScreen(vendor: vendor)),
        ));
  }

  void _openVendorFromDish(Map<String, dynamic> dish) {
    final isOpen = dish['vendorIsOpen'] == true;
    if (!isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This kitchen is currently closed")),
      );
      return;
    }
    final vendor = Vendor.fromJson({
      '_id': dish['vendorId'],
      'businessName': dish['vendorName'],
      'isOpen': dish['vendorIsOpen'],
      'logo': dish['vendorLogo'],
    });
    final cart = CartProvider.of(context);
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartProvider(
              controller: cart,
              child: VendorDetailsScreen(vendor: vendor)),
        ));
  }

  bool get _hasResults =>
      _vendorResults.isNotEmpty || _dishResults.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
    final bg = dark
        ? CustomerColors.backgroundDark
        : CustomerColors.background;
    final titleColor = dark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text("Search",
            style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: Column(
        children: [
          _searchBar(dark),
          _categoryChips(dark),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: CustomerColors.primary))
                : !_searched
                    ? _emptyPrompt()
                    : !_hasResults
                        ? _noResults()
                        : _results(dark),
          ),
        ],
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────
  Widget _categoryChips(bool dark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => _selectCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? CustomerColors.primary
                    : (dark
                        ? const Color(0xFF2C1010)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? CustomerColors.primary
                      : (dark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _results(bool dark) {
    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (_vendorResults.isNotEmpty) ...[
          _sectionHeader(Icons.storefront_outlined, "Kitchens",
              _vendorResults.length, dark),
          const SizedBox(height: 8),
          ..._vendorResults.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _vendorRow(v, dark),
              )),
          const SizedBox(height: 8),
        ],
        if (_dishResults.isNotEmpty) ...[
          _sectionHeader(Icons.restaurant_menu_outlined, "Dishes",
              _dishResults.length, dark),
          const SizedBox(height: 8),
          ..._dishResults.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dishRow(d, dark),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(
      IconData icon, String label, int count, bool dark) {
    final labelColor = dark ? Colors.white : const Color(0xFF1A1A1A);
    return Row(
      children: [
        Icon(icon, size: 15, color: CustomerColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: labelColor)),
        const SizedBox(width: 6),
        Text("($count)",
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _vendorRow(Vendor vendor, bool dark) {
    final rating = vendor.rating ?? 0.0;
    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor =
        dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final nameColor = dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () => _openVendor(vendor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: vendor.logoUrl != null
                    ? Image.network(vendor.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _logoPlaceholder(dark))
                    : _logoPlaceholder(dark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor.businessName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: nameColor)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _openBadge(vendor.isOpen),
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
                                ? (dark
                                    ? Colors.white70
                                    : Colors.black87)
                                : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color:
                    dark ? Colors.grey.shade500 : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _dishRow(Map<String, dynamic> dish, bool dark) {
    final dishName = dish['dishName'] ?? '';
    final vendorName = dish['vendorName'] ?? '';
    final price = dish['dishPrice'] ?? 0;
    final imageUrl = dish['dishImage']?['url'];
    final isOpen = dish['vendorIsOpen'] == true;
    final category = dish['dishCategory'] ?? '';
    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor =
        dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final nameColor = dark ? Colors.white : Colors.black;
    final subColor =
        dark ? Colors.grey.shade400 : Colors.grey.shade500;

    return GestureDetector(
      onTap: () => _openVendorFromDish(dish),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _dishPlaceholder(dark))
                    : _dishPlaceholder(dark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(dishName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: nameColor)),
                      ),
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CustomerColors.primary
                                .withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Text(category,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: CustomerColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text("by $vendorName",
                      style:
                          TextStyle(fontSize: 11, color: subColor)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("₦${price.toString()}",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.primary)),
                      const SizedBox(width: 8),
                      _openBadge(isOpen),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color:
                    dark ? Colors.grey.shade500 : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _openBadge(bool isOpen) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(isOpen ? "Open" : "Closed",
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOpen
                  ? Colors.green.shade700
                  : Colors.red.shade700)),
    );
  }

  Widget _emptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("Search kitchens or dishes",
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text("or pick a category above",
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _noResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.isNotEmpty
                ? "No results for \"${_searchCtrl.text}\""
                : "No results for ${_selectedCategory ?? 'this category'}",
            style: const TextStyle(
                color: CustomerColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text("Try a different search or category",
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _logoPlaceholder(bool dark) => Container(
        color: dark
            ? const Color(0xFF3A1515)
            : Colors.grey.shade100,
        child: Icon(Icons.storefront,
            color:
                dark ? Colors.grey.shade600 : Colors.grey,
            size: 24));

  Widget _dishPlaceholder(bool dark) => Container(
        color: dark
            ? const Color(0xFF3A1515)
            : Colors.grey.shade100,
        child: Icon(Icons.restaurant_menu,
            color:
                dark ? Colors.grey.shade600 : Colors.grey,
            size: 24));

  Widget _searchBar(bool dark) {
    final fillColor =
        dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor =
        dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hintColor = Colors.grey.shade500;
    final textColor = dark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        autofocus: true,
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          hintText: "Search kitchens or dishes...",
          hintStyle: TextStyle(fontSize: 13, color: hintColor),
          prefixIcon:
              Icon(Icons.search, size: 20, color: hintColor),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon:
                      Icon(Icons.clear, size: 18, color: hintColor),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: CustomerColors.primary, width: 1.5)),
        ),
      ),
    );
  }
}