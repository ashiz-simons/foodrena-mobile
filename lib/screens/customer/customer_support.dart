import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';

class CustomerSupport extends StatelessWidget {
  const CustomerSupport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Support"),
      ),
      body: const Center(
        child: Text(
          "Support & help center coming soon",
          style: TextStyle(color: CustomerColors.textMuted),
        ),
      ),
    );
  }
}
