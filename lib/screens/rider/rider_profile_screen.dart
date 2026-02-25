import 'package:flutter/material.dart';
import '../../utils/session.dart';
import 'rider_bank_screen.dart';

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              "Rider",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // 🔹 Bank Details
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text("Bank Details"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RiderBankScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            // 🔹 Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await Session.clear();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/login",
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
