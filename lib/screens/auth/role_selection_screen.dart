import 'package:flutter/material.dart';
import 'register_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final VoidCallback? onLogin;

  const RoleSelectionScreen({super.key, this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join as"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How would you\nlike to use Foodrena?",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
            const SizedBox(height: 8),
            const Text(
              "You can always switch roles later.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            _roleCard(
              context,
              role: "customer",
              title: "Customer",
              subtitle: "Order food and packages",
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFFDC2626),
            ),

            const SizedBox(height: 14),

            _roleCard(
              context,
              role: "rider",
              title: "Rider",
              subtitle: "Deliver orders and earn money",
              icon: Icons.delivery_dining_outlined,
              color: Colors.orange,
            ),

            const SizedBox(height: 14),

            _roleCard(
              context,
              role: "vendor",
              title: "Vendor",
              subtitle: "Sell your food to customers",
              icon: Icons.storefront_outlined,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(
            role: role,
            onRegister: onLogin,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}