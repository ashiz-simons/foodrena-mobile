import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'core/cart/cart_provider.dart';
import 'core/cart/cart_controller.dart';

void main() {
  runApp(
    CartProvider(
      controller: CartController(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}