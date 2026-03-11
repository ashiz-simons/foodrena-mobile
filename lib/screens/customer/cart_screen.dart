import 'package:flutter/material.dart';
import '../../core/cart/cart_provider.dart';
import '../../core/cart/cart_controller.dart';
import '../../services/api_service.dart';
import '../../services/order_service.dart';
import 'payment_screen.dart';
import 'order_status_screen.dart';
import 'delivery_address_screen.dart';
import '../../core/theme/customer_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _activeOrdersFuture;
  bool _checkingOut = false;
  Map<String, dynamic>? _deliveryAddress;

  @override
  void initState() {
    super.initState();
    _activeOrdersFuture = OrderService.fetchActiveOrders();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryAddressScreen()),
    );
    if (result != null) {
      setState(() => _deliveryAddress = result);
    }
  }

  Future<void> _checkout(CartController cart) async {
    if (_checkingOut) return;
    if (cart.vendorId == null) return;

    // Require address before checkout
    if (_deliveryAddress == null) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryAddressScreen()),
      );
      if (result == null) return; // user cancelled
      setState(() => _deliveryAddress = result);
    }

    setState(() => _checkingOut = true);

    try {
      final orderRes = await ApiService.post(
        "/orders",
        {
          "vendorId": cart.vendorId,
          "items": cart.items
              .map((e) => {
                    "menuItemId": e.item.id,
                    "quantity": e.quantity,
                  })
              .toList(),
          "deliveryAddress": {
            "street": _deliveryAddress!['street'] ?? '',
            "city": _deliveryAddress!['city'] ?? '',
            "state": _deliveryAddress!['area'] ?? '',
            "lat": _deliveryAddress!['lat'],
            "lng": _deliveryAddress!['lng'],
          },
          "deliveryLocation": {
            "lat": _deliveryAddress!['lat'],
            "lng": _deliveryAddress!['lng'],
          },
        },
      );

      if (!mounted) return;

      if (orderRes == null || orderRes["order"] == null) {
        _showError("Failed to create order. Please try again.");
        return;
      }

      final orderId = orderRes["order"]["_id"] as String;

      final paymentInit = await ApiService.post(
        "/payments/initiate",
        {"orderId": orderId},
      );

      if (!mounted) return;

      if (paymentInit == null || paymentInit["authorization_url"] == null) {
        _showError("Failed to initiate payment. Please try again.");
        return;
      }

      final reference = paymentInit["reference"] as String;
      cart.clear();

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            authorizationUrl: paymentInit["authorization_url"],
            orderId: orderId,
            reference: reference,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Clear cart?"),
                    content: const Text(
                        "This will remove all items from your cart."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel")),
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          Navigator.pop(context);
                        },
                        child: const Text("Clear",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Clear", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Active order banner
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _activeOrdersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }
              final order = snapshot.data!.first;
              final orderId = order["_id"] as String? ?? "";
              final status = order["status"] as String? ?? "pending";

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderStatusScreen(orderId: orderId),
                  ),
                ),
                child: Card(
                  margin: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.delivery_dining,
                        color: Colors.blue),
                    title: const Text("Active Order",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Status: $status"),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.blue),
                  ),
                ),
              );
            },
          ),

          if (cart.isEmpty)
            const Expanded(
              child: Center(
                child: Text("Your cart is empty",
                    style: TextStyle(fontSize: 16)),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final entry = cart.items[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₦${entry.item.price.toStringAsFixed(0)} each",
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _qtyBtn(
                                    icon: Icons.remove,
                                    onTap: () => cart.remove(entry.item.id),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text("${entry.quantity}",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  _qtyBtn(
                                    icon: Icons.add,
                                    onTap: () =>
                                        cart.add(entry.item, cart.vendorId!),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₦${(entry.item.price * entry.quantity).toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        cart.removeAll(entry.item.id),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Delivery address + checkout footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Delivery address row
                        GestureDetector(
                          onTap: _pickAddress,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _deliveryAddress != null
                                    ? CustomerColors.primary
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: _deliveryAddress != null
                                      ? CustomerColors.primary
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _deliveryAddress != null
                                        ? _deliveryAddress!['fullAddress']
                                        : 'Add delivery address',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _deliveryAddress != null
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.edit_outlined,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Subtotal",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                Text(
                                  "₦${cart.total.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text("+ delivery fee at checkout",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _checkingOut
                                  ? null
                                  : () => _checkout(cart),
                              child: _checkingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text("Checkout",
                                      style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}