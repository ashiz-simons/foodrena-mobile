import 'package:flutter/material.dart';
import '../../utils/session.dart';

class DeliveryModeScreen extends StatelessWidget {
  const DeliveryModeScreen({super.key});

  Future<void> _selectMode(BuildContext context, String mode) async {
    await Session.saveDeliveryMode(mode);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose delivery mode")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _modeCard(
              context,
              title: "Food Delivery",
              subtitle: "Meals from kitchens near you",
              icon: Icons.restaurant,
              onTap: () => _selectMode(context, "food"),
            ),
            const SizedBox(height: 16),
            _modeCard(
              context,
              title: "Package Delivery",
              subtitle: "Send items to any location",
              icon: Icons.local_shipping,
              onTap: () => _selectMode(context, "package"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}