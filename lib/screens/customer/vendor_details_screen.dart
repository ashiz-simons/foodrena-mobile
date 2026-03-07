import 'package:flutter/material.dart';
import '../../models/vendor_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/customer_vendor_service.dart';
import '../../core/cart/cart_provider.dart';
import 'dish_detail_screen.dart';

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
    menuFuture = CustomerVendorService.getVendorMenu(widget.vendor.id);
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.vendor.businessName)),
      body: FutureBuilder<List<MenuItem>>(
        future: menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString(),
                  textAlign: TextAlign.center),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No menu available"));
          }

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () {
                    // Convert MenuItem to PopularDish for DishDetailScreen
                    final dish = PopularDish(
                      id: item.id,
                      name: item.name,
                      price: item.price,
                      orderCount: 0,
                      imageUrl: item.imageUrl,
                      vendorId: widget.vendor.id,
                      vendorName: widget.vendor.businessName,
                      vendorLogoUrl: widget.vendor.logoUrl,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CartProvider(
                          controller: cart,
                          child: DishDetailScreen(dish: dish),
                        ),
                      ),
                    );
                  },
                  leading: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            item.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.fastfood),
                          ),
                        )
                      : const Icon(Icons.fastfood),
                  title: Text(item.name),
                  subtitle:
                      Text("₦${item.price.toStringAsFixed(0)}"),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}