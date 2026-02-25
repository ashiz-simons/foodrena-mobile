import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';
import '../../core/cart/cart_provider.dart';

import '../../screens/customer/customer_home.dart';
import '../../screens/customer/customer_search.dart';
import '../../screens/customer/customer_support.dart';
import '../../screens/customer/customer_profile.dart';
import '../../screens/customer/cart_screen.dart';

class CustomerNavShell extends StatefulWidget {
  const CustomerNavShell({super.key});

  @override
  State<CustomerNavShell> createState() => _CustomerNavShellState();
}

class _CustomerNavShellState extends State<CustomerNavShell> {
  int _currentIndex = 0;

  final screens = const [
    CustomerHome(),
    CustomerSearch(),
    CartScreen(),
    CustomerSupport(),
    CustomerProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: customerTheme,
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: "Search",
            ),
            BottomNavigationBarItem(
              icon: _cartIconWithBadge(context),
              activeIcon: _cartIconWithBadge(context, active: true),
              label: "Cart",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.support_agent_outlined),
              activeIcon: Icon(Icons.support_agent),
              label: "Support",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartIconWithBadge(BuildContext context, {bool active = false}) {
    final cart = CartProvider.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active
            ? Icons.shopping_cart
            : Icons.shopping_cart_outlined),
        if (cart.items.isNotEmpty)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                cart.items.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}