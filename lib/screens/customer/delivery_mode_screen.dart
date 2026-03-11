import 'package:flutter/material.dart';
import '../../utils/session.dart';

const _kBlue = Color(0xFF1E3A5F);
const _kBlueLight = Color(0xFF2D5986);

class DeliveryModeScreen extends StatelessWidget {
  const DeliveryModeScreen({super.key});

  Future<void> _selectMode(BuildContext context, String mode) async {
    await Session.saveDeliveryMode(mode);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose delivery mode"),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: _kBlue),
            ),
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