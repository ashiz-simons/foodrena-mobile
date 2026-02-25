import 'package:flutter/material.dart';
import '../../core/cart/cart_provider.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import 'payment_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
      ),
      body: cart.isEmpty
          ? const Center(
              child: Text(
                "Your cart is empty",
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                // =======================
                // CART ITEMS
                // =======================
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final entry = cart.items[i];

                      return ListTile(
                        title: Text(entry.item.name),
                        subtitle: Text("Qty: ${entry.quantity}"),
                        trailing: Text(
                          "₦${(entry.item.price * entry.quantity).toStringAsFixed(0)}",
                        ),
                      );
                    },
                  ),
                ),

                // =======================
                // CHECKOUT BAR
                // =======================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total: ₦${cart.total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final token = await Session.getToken();
                          if (token == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please login to continue"),
                              ),
                            );
                            return;
                          }

                          // =======================
                          // CREATE ORDER
                          // =======================
                          final orderBody = {
                            "vendorId": cart.vendorId,
                            "items": cart.items
                                .map((e) => {
                                      "menuItemId": e.item.id,
                                      "quantity": e.quantity,
                                    })
                                .toList(),
                            "deliveryAddress": "User default address",
                          };

                          final orderRes =
                              await ApiService.post("/orders", orderBody);

                          if (orderRes == null ||
                              orderRes["order"] == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to create order"),
                              ),
                            );
                            return;
                          }

                          final String orderId =
                              orderRes["order"]["_id"];

                          // =======================
                          // INITIATE PAYMENT
                          // =======================
                          final paymentInit = await ApiService.post(
                            "/payments/initiate",
                            {"orderId": orderId},
                          );

                          if (paymentInit == null ||
                              paymentInit["authorization_url"] == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Payment initialization failed"),
                              ),
                            );
                            return;
                          }

                          // =======================
                          // OPEN PAYSTACK WEBVIEW
                          // =======================
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentScreen(
                                authorizationUrl:
                                    paymentInit["authorization_url"],
                                orderId: orderId,
                              ),
                            ),
                          );

                          // =======================
                          // CLEAR CART (MVP)
                          // =======================
                          cart.clear();
                        },
                        child: const Text("Checkout"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}