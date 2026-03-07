import 'package:flutter/material.dart';
import 'cart_controller.dart';

class CartProvider extends InheritedNotifier<CartController> {
  const CartProvider({
    super.key,
    required CartController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static CartController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CartProvider>();

    if (provider == null || provider.notifier == null) {
      throw FlutterError('CartProvider not found in widget tree');
    }

    return provider.notifier!;
  }
}