import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Your Role")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Continue as",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            _roleCard(
              context,
              title: "Customer",
              icon: Icons.shopping_bag,
              onTap: () {
                // TODO: Navigate to Customer Home
              },
            ),

            _roleCard(
              context,
              title: "Rider",
              icon: Icons.delivery_dining,
              onTap: () {
                // TODO: Navigate to Rider Home
              },
            ),

            _roleCard(
              context,
              title: "Vendor",
              icon: Icons.store,
              onTap: () {
                // TODO: Navigate to Vendor Dashboard
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(BuildContext context,
      {required String title, required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.orange),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
