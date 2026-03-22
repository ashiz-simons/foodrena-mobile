import 'package:flutter/material.dart';
import '../../core/cart/cart_provider.dart';
import '../../core/theme/app_theme.dart';
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
  final List<AddOn> addOns;

  const PopularDish({
    required this.id,
    required this.name,
    required this.price,
    required this.orderCount,
    this.imageUrl,
    this.vendorId,
    this.vendorName,
    this.vendorLogoUrl,
    this.addOns = const [],
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
        addOns: (j["addOns"] as List? ?? [])
            .map((a) => AddOn.fromJson(a))
            .toList(),
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

  double get _baseTotal => widget.dish.price * qty;

  void _addToCart() {
    final dish = widget.dish;
    if (dish.vendorId == null) return;

    if (dish.addOns.isEmpty) {
      _confirmAdd([]);
    } else {
      _showAddOnsSheet();
    }
  }

  void _confirmAdd(List<AddOn> selectedAddOns) {
    final dish = widget.dish;
    if (dish.vendorId == null) return;

    final cart = CartProvider.of(context);
    final menuItem = MenuItem(
      id: dish.id,
      name: dish.name,
      price: dish.price,
      imageUrl: dish.imageUrl,
      addOns: dish.addOns,
    );

    for (int i = 0; i < qty; i++) {
      cart.add(menuItem, dish.vendorId!, selectedAddOns: selectedAddOns);
    }

    final addOnsTotal =
        selectedAddOns.fold(0.0, (sum, a) => sum + a.price);
    final linePrice = (dish.price + addOnsTotal) * qty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "$qty × ${dish.name} added to cart  •  ₦${linePrice.toStringAsFixed(0)}"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  void _showAddOnsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOnsSheet(
        dish: widget.dish,
        qty: qty,
        onConfirm: (selected) {
          Navigator.pop(context);
          _confirmAdd(selected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CustomerColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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
                        Text("${dish.orderCount} orders",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  if (dish.vendorName != null) ...[
                    const Text("From",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 13)),
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
                        Text(dish.vendorName!,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],

                  // Add-ons preview
                  if (dish.addOns.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.add_circle_outline,
                            size: 16,
                            color: CustomerColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "${dish.addOns.length} add-on${dish.addOns.length > 1 ? 's' : ''} available",
                          style: const TextStyle(
                              fontSize: 13,
                              color: CustomerColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dish.addOns.map((a) => a.name).join(", "),
                      style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],

                  // Qty selector
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomerColors.primary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _addToCart,
                      child: Text(
                        dish.addOns.isNotEmpty
                            ? "Choose add-ons  •  from ₦${_baseTotal.toStringAsFixed(0)}"
                            : "Add to cart  •  ₦${_baseTotal.toStringAsFixed(0)}",
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

  Widget _qtyBtn(
      {required IconData icon, required VoidCallback onTap}) {
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

// ── Add-ons bottom sheet ──────────────────────────────────────────────────
class _AddOnsSheet extends StatefulWidget {
  final PopularDish dish;
  final int qty;
  final Function(List<AddOn> selected) onConfirm;

  const _AddOnsSheet({
    required this.dish,
    required this.qty,
    required this.onConfirm,
  });

  @override
  State<_AddOnsSheet> createState() => _AddOnsSheetState();
}

class _AddOnsSheetState extends State<_AddOnsSheet> {
  final Set<int> _selected = {};

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

  double get _addOnsTotal => _selected.fold(
      0.0, (sum, i) => sum + widget.dish.addOns[i].price);

  double get _lineTotal =>
      (widget.dish.price + _addOnsTotal) * widget.qty;

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
    final bg = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF1A1A1A);
    final muted =
        dark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardBg = dark
        ? const Color(0xFF2C2C2C)
        : Colors.grey.shade50;
    final borderColor =
        dark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text("Add-ons",
              style: TextStyle(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text("Select any extras (optional)",
              style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 16),

          ...widget.dish.addOns.asMap().entries.map((entry) {
            final i = entry.key;
            final addon = entry.value;
            final isSelected = _selected.contains(i);

            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selected.remove(i);
                } else {
                  _selected.add(i);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CustomerColors.primary.withOpacity(0.08)
                      : cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? CustomerColors.primary
                        : borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? CustomerColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? CustomerColors.primary
                              : muted.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 13)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(addon.name,
                          style: TextStyle(
                              color: text,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      "+₦${addon.price.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: isSelected
                            ? CustomerColors.primary
                            : muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total${widget.qty > 1 ? ' (×${widget.qty})' : ''}",
                style: TextStyle(color: muted, fontSize: 13),
              ),
              Text(
                "₦${_lineTotal.toStringAsFixed(0)}",
                style: const TextStyle(
                    color: CustomerColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomerColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final selected = _selected
                    .map((i) => widget.dish.addOns[i])
                    .toList();
                widget.onConfirm(selected);
              },
              child: Text(
                _selected.isEmpty
                    ? "Add to cart  •  ₦${_lineTotal.toStringAsFixed(0)}"
                    : "Add with ${_selected.length} add-on${_selected.length > 1 ? 's' : ''}  •  ₦${_lineTotal.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
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