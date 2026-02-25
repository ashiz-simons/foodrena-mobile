import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../services/customer_vendor_service.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/customer_theme.dart';

class AllVendorsScreen extends StatefulWidget {
  const AllVendorsScreen({super.key});

  @override
  State<AllVendorsScreen> createState() => _AllVendorsScreenState();
}

class _AllVendorsScreenState extends State<AllVendorsScreen> {
  List<Vendor> vendors = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final res = await CustomerVendorService.getVendors();
    setState(() {
      vendors = res;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All kitchens"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : vendors.isEmpty
              ? const Center(child: Text("No vendors available"))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vendors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _vendorRow(vendors[i]),
                ),
    );
  }

  Widget _vendorRow(Vendor vendor) {
    return ListTile(
      contentPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      tileColor: Colors.white,
      leading: const Icon(Icons.store, color: CustomerColors.primary),
      title: Text(
        vendor.businessName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        vendor.isOpen ? "Open now" : "Closed",
        style: TextStyle(
          color: vendor.isOpen ? Colors.green : Colors.red,
          fontSize: 12,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailsScreen(vendor: vendor),
          ),
        );
      },
    );
  }
}
