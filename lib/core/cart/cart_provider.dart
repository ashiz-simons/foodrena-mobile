import 'package:flutter/material.dart';
import 'cart_controller.dart';

class CartProvider extends InheritedNotifier<CartController> {
  const CartProvider({
    super.key,
    required CartController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static CartController of(BuildContext context) {
    final CartProvider? provider =
        context.dependOnInheritedWidgetOfExactType<CartProvider>();
    assert(provider != null, 'No CartProvider found in context');
    return provider!.notifier!;
  }
}