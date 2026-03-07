import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import 'vendor_details_screen.dart';
import '../../core/theme/customer_theme.dart';
import '../../core/cart/cart_provider.dart';

class AllVendorsScreen extends StatelessWidget {
  final List<Vendor> vendors;

  const AllVendorsScreen({super.key, required this.vendors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All kitchens")),
      body: vendors.isEmpty
          ? const Center(child: Text("No vendors available"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vendors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _vendorRow(context, vendors[i]),
            ),
    );
  }

  Widget _vendorRow(BuildContext context, Vendor vendor) {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        vendor.isOpen
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 10,
                        color:
                            vendor.isOpen ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.isOpen ? "Open now" : "Closed",
                        style: TextStyle(
                          fontSize: 12,
                          color: vendor.isOpen
                              ? Colors.green
                              : Colors.red,
                        ),
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
      child: const Icon(Icons.storefront,
          color: Colors.grey, size: 28),
    );
  }
}