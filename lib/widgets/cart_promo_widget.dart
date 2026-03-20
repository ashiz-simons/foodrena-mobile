// ─────────────────────────────────────────────────────────────────────────────
// DROP THIS WIDGET into your cart_screen.dart
//
// 1. Add these fields to your cart screen State class:
//
//    final _promoCtrl = TextEditingController();
//    bool _applyingPromo = false;
//    String? _promoCode;       // applied code string
//    String? _promoId;         // promo _id from backend
//    String _promoType = "";   // "percent" | "free_delivery"
//    double _discountAmount = 0;
//    String _promoMessage = "";
//    String _promoError = "";
//
// 2. Add to dispose():
//    _promoCtrl.dispose();
//
// 3. In your total calculation, deduct _discountAmount from subtotal,
//    and if _promoType == "free_delivery" set deliveryFee = 0.
//
// 4. When building the order payload for checkout, include:
//    "promoCode": _promoCode,
//    "promoId":   _promoId,
//    "discount":  _discountAmount,
//
// 5. Place <CartPromoWidget ... /> just above your total summary row.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../services/promo_service.dart';

class CartPromoWidget extends StatelessWidget {
  final TextEditingController ctrl;
  final bool applying;
  final String? appliedCode;
  final String promoMessage;
  final String promoError;
  final double discountAmount;
  final String promoType;
  final VoidCallback onRemove;
  final Future<void> Function() onApply;

  const CartPromoWidget({
    super.key,
    required this.ctrl,
    required this.applying,
    required this.appliedCode,
    required this.promoMessage,
    required this.promoError,
    required this.discountAmount,
    required this.promoType,
    required this.onRemove,
    required this.onApply,
  });

  bool get _dark {
    // We can't use context directly in a non-BuildContext method,
    // so we pass dark as a param if needed — for now use light defaults.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dark   = Theme.of(context).brightness == Brightness.dark;
    final bg     = dark ? const Color(0xFF2C1010) : const Color(0xFFFFF0F0);
    final card   = dark ? const Color(0xFF1A0808) : Colors.white;
    final red    = const Color(0xFFDC2626);
    final muted  = dark ? Colors.grey.shade400 : const Color(0xFF888888);
    final text   = dark ? Colors.white : const Color(0xFF1A1A1A);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: appliedCode != null ? red.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount_outlined, color: red, size: 16),
              const SizedBox(width: 6),
              Text("Promo Code",
                  style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),

          if (appliedCode != null) ...[
            // Applied state
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appliedCode!,
                            style: TextStyle(
                                color: red,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 2),
                        Text(promoMessage,
                            style: TextStyle(color: red.withOpacity(0.8), fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: red),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Input state
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                        color: text, fontSize: 14, letterSpacing: 1.2, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "Enter code",
                      hintStyle: TextStyle(color: muted, fontSize: 13, letterSpacing: 0),
                      filled: true,
                      fillColor: dark ? const Color(0xFF2C1010) : const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: red, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: applying ? null : onApply,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: applying ? red.withOpacity(0.5) : red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: applying
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Apply",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (promoError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(promoError, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Helper function to call from your cart screen ────────────────────────
// Call this when user taps Apply:
//
// Future<void> _applyPromo() async {
//   final code = _promoCtrl.text.trim();
//   if (code.isEmpty) return;
//   setState(() { _applyingPromo = true; _promoError = ""; });
//   try {
//     final res = await PromoService.applyCode(
//       code: code,
//       orderTotal: _subtotal,   // your cart subtotal before discount
//     );
//     setState(() {
//       _promoCode      = res["promoId"];
//       _promoId        = res["promoId"];
//       _promoType      = res["type"];
//       _discountAmount = (res["discountAmount"] ?? 0).toDouble();
//       _promoMessage   = res["message"] ?? "";
//       _promoError     = "";
//     });
//   } catch (e) {
//     setState(() {
//       _promoError = e.toString().replaceAll("Exception: ", "");
//     });
//   } finally {
//     setState(() => _applyingPromo = false);
//   }
// }
//
// Call this when user taps the X to remove:
//
// void _removePromo() {
//   setState(() {
//     _promoCtrl.clear();
//     _promoCode      = null;
//     _promoId        = null;
//     _promoType      = "";
//     _discountAmount = 0;
//     _promoMessage   = "";
//     _promoError     = "";
//   });
// }