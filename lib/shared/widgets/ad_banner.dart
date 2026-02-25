import 'package:flutter/material.dart';
import '../../core/theme/customer_theme.dart';

class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: const [
          Icon(Icons.campaign, color: CustomerColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "🔥 Promo: Free delivery on your first order",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: CustomerColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
