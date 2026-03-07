import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/customer_theme.dart';

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
    final q = query.toLowerCase();

    setState(() {
      _filteredVendors = _allVendors.where((v) {
        return v.businessName.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVendors.isEmpty
                    ? const Center(
                        child: Text(
                          "No kitchens found",
                          style: TextStyle(color: CustomerColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredVendors.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final vendor = _filteredVendors[i];
                          return ListTile(
                            leading: const Icon(Icons.store),
                            title: Text(vendor.businessName),
                            subtitle: Text(
                              vendor.isOpen ? "Open now" : "Closed",
                              style: TextStyle(
                                color: vendor.isOpen
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VendorDetailsScreen(vendor: vendor),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: "Search kitchens",
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
}
