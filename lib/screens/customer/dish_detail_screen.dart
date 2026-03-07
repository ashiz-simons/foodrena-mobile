import 'package:flutter/material.dart';
import '../../core/cart/cart_provider.dart';
import '../../core/theme/customer_theme.dart';
import '../../models/menu_item_model.dart';

class PopularDish {
  final String id;
  final String name;
  final double price;
  final int orderCount;
  final String? imageUrl;
  final String? vendorId;
  final String? vendorName;
  final String? vendorLogoUrl;

  const PopularDish({
    required this.id,
    required this.name,
    required this.price,
    required this.orderCount,
    this.imageUrl,
    this.vendorId,
    this.vendorName,
    this.vendorLogoUrl,
  });

  factory PopularDish.fromJson(Map<String, dynamic> j) => PopularDish(
        id: j["_id"] ?? "",
        name: j["name"] ?? "",
        price: (j["price"] ?? 0).toDouble(),
        orderCount: j["orderCount"] ?? 0,
        imageUrl: j["imageUrl"],
        vendorId: j["vendorId"]?.toString(),
        vendorName: j["vendorName"],
        vendorLogoUrl: j["vendorLogoUrl"],
      );
}

class DishDetailScreen extends StatefulWidget {
  final PopularDish dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final cart = CartProvider.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: dish.imageUrl != null
                  ? Image.network(dish.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _PlaceholderImage())
                  : const _PlaceholderImage(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(dish.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        "₦${dish.price.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CustomerColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Order count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "${dish.orderCount} orders",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Vendor info
                  if (dish.vendorName != null) ...[
                    const Text("From",
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: dish.vendorLogoUrl != null
                              ? NetworkImage(dish.vendorLogoUrl!)
                              : null,
                          child: dish.vendorLogoUrl == null
                              ? const Icon(Icons.storefront, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          dish.vendorName!,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],

                  // Qty selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Quantity",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          _qtyBtn(
                            icon: Icons.remove,
                            onTap: () {
                              if (qty > 1) setState(() => qty--);
                            },
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text("$qty",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          _qtyBtn(
                            icon: Icons.add,
                            onTap: () => setState(() => qty++),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Add to cart button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomerColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (dish.vendorId == null) return;
                        final menuItem = MenuItem(
                          id: dish.id,
                          name: dish.name,
                          price: dish.price,
                          imageUrl: dish.imageUrl,
                        );
                        for (int i = 0; i < qty; i++) {
                          cart.add(menuItem, dish.vendorId!);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("$qty × ${dish.name} added to cart"),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Add to cart  •  ₦${(dish.price * qty).toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: CustomerColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: CustomerColors.primary),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.fastfood, size: 60, color: Colors.grey),
      ),
    );
  }
}