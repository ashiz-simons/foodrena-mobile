import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../core/cart/cart_provider.dart';

class VendorDetailsScreen extends StatefulWidget {
  final Vendor vendor;
  const VendorDetailsScreen({super.key, required this.vendor});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  late Future<List<MenuItem>> menuFuture;

  @override
  void initState() {
    super.initState();
    menuFuture =
        CustomerVendorService.getVendorMenu(widget.vendor.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vendor.businessName)),
      body: FutureBuilder<List<MenuItem>>(
        future: menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("No menu available"));
          }

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              return ListTile(
                title: Text(item.name),
                subtitle:
                    Text("₦${item.price.toStringAsFixed(0)}"),
                trailing: ElevatedButton(
                  onPressed: () {
                    final cart = CartProvider.of(context);
                    cart.add(item, widget.vendor.id);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${item.name} added to cart"),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text("Add"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}