import 'package:flutter/material.dart';
import '../../core/cart/cart_provider.dart';
import '../../core/cart/cart_controller.dart';
import '../../services/api_service.dart';
import '../../services/order_service.dart';
import '../../services/promo_service.dart';
import '../../services/customer_wallet_service.dart';
import 'payment_screen.dart';
import 'order_status_screen.dart';
import 'delivery_address_screen.dart';
import '../../core/theme/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _activeOrdersFuture;
  bool _checkingOut = false;
  bool _payWithWallet = false;
  double _walletBalance = 0;
  Map<String, dynamic>? _deliveryAddress;

  // ── Promo state ────────────────────────────────────────────────────────────
  final _promoCtrl    = TextEditingController();
  bool   _applyingPromo  = false;
  String? _appliedCode;
  String? _appliedPromoId;
  String  _promoType     = "";   // "percent" | "free_delivery"
  double  _discountAmount = 0;
  String  _promoMessage  = "";
  String  _promoError    = "";
  // ──────────────────────────────────────────────────────────────────────────

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF1A0808) : const Color(0xFFFFF0F0);
  Color get _card => _dark ? const Color(0xFF2C1010) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : Colors.grey;
  Color get _red  => CustomerColors.primary; // DC2626

  @override
  void initState() {
    super.initState();
    _activeOrdersFuture = OrderService.fetchActiveOrders();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final balance = await CustomerWalletService.getBalance();
      if (mounted) setState(() => _walletBalance = balance);
    } catch (_) {}
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  // ── Promo helpers ──────────────────────────────────────────────────────────
  Future<void> _applyPromo(double subtotal) async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _applyingPromo = true; _promoError = ""; });
    try {
      final res = await PromoService.applyCode(code: code, orderTotal: subtotal);
      setState(() {
        _appliedCode    = code;
        _appliedPromoId = res["promoId"]?.toString();
        _promoType      = res["type"] ?? "";
        _discountAmount = (res["discountAmount"] ?? 0).toDouble();
        _promoMessage   = res["message"] ?? "";
        _promoError     = "";
      });
    } catch (e) {
      setState(() {
        _promoError = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  void _removePromo() {
    setState(() {
      _promoCtrl.clear();
      _appliedCode    = null;
      _appliedPromoId = null;
      _promoType      = "";
      _discountAmount = 0;
      _promoMessage   = "";
      _promoError     = "";
    });
  }
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pickAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryAddressScreen()),
    );
    if (result != null) setState(() => _deliveryAddress = result);
  }

  Future<void> _checkout(CartController cart) async {
    if (_checkingOut) return;
    if (cart.vendorId == null) return;

    if (_deliveryAddress == null) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryAddressScreen()),
      );
      if (result == null) return;
      setState(() => _deliveryAddress = result);
    }

    setState(() => _checkingOut = true);

    try {
      final orderRes = await ApiService.post(
        "/orders",
        {
          "vendorId": cart.vendorId,
          "items": cart.items
              .map((e) => {
                    "menuItemId": e.item.id,
                    "name":       e.item.name,
                    "price":      e.item.price,
                    "quantity":   e.quantity,
                    "addOns": e.selectedAddOns
                        .map((a) => {"name": a.name, "price": a.price})
                        .toList(),
                  })
              .toList(),
          "deliveryAddress": {
            "street": _deliveryAddress!['street'] ?? '',
            "city":   _deliveryAddress!['city']   ?? '',
            "state":  _deliveryAddress!['area']   ?? '',
            "lat":    _deliveryAddress!['lat'],
            "lng":    _deliveryAddress!['lng'],
          },
          "deliveryLocation": {
            "lat": _deliveryAddress!['lat'],
            "lng": _deliveryAddress!['lng'],
          },
          if (_appliedCode    != null) "promoCode":  _appliedCode,
          if (_appliedPromoId != null) "promoId":    _appliedPromoId,
          if (_discountAmount  > 0)   "discount":   _discountAmount,
          if (_promoType == "free_delivery") "freeDelivery": true,
        },
      );

      if (!mounted) return;

      if (orderRes == null || orderRes["order"] == null) {
        _showError("Failed to create order. Please try again.");
        return;
      }

      final orderId = orderRes["order"]["_id"] as String;

      // ── Wallet payment path ──────────────────────────────────
      if (_payWithWallet) {
        try {
          await CustomerWalletService.payWithWallet(orderId);
          cart.clear();
          if (!mounted) return;
          await _loadWalletBalance();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => OrderStatusScreen(orderId: orderId),
            ),
            (route) => route.isFirst,
          );
          return;
        } catch (e) {
          _showError(e.toString().replaceAll("Exception: ", ""));
          return;
        }
      }

      // ── Paystack payment path ────────────────────────────────
      final paymentInit = await ApiService.post(
        "/payments/initiate",
        {"orderId": orderId},
      );

      if (!mounted) return;

      if (paymentInit == null || paymentInit["authorization_url"] == null) {
        _showError("Failed to initiate payment. Please try again.");
        return;
      }

      final reference = paymentInit["reference"] as String;
      cart.clear();

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            authorizationUrl: paymentInit["authorization_url"],
            orderId: orderId,
            reference: reference,
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final cart     = CartProvider.of(context);
    final subtotal = cart.total;
    final discount = _discountAmount;
    final totalAfterDiscount = (subtotal - discount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text("Your Cart", style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: _text),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: _card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text("Clear cart?", style: TextStyle(color: _text)),
                    content: Text("This will remove all items from your cart.",
                        style: TextStyle(color: _muted)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel", style: TextStyle(color: _muted))),
                      TextButton(
                        onPressed: () { cart.clear(); _removePromo(); Navigator.pop(context); },
                        child: const Text("Clear", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Clear", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Active order banner ─────────────────────────────────────────
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _activeOrdersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
              final order   = snapshot.data!.first;
              final orderId = order["_id"] as String? ?? "";
              final status  = order["status"] as String? ?? "pending";
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: orderId)),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _dark ? const Color(0xFF0A1828) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, color: Colors.blue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Active Order",
                                style: TextStyle(fontWeight: FontWeight.bold, color: _text, fontSize: 13)),
                            Text("Status: $status",
                                style: TextStyle(color: _muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.blue),
                    ],
                  ),
                ),
              );
            },
          ),

          if (cart.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 52, color: _muted.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text("Your cart is empty",
                        style: TextStyle(fontSize: 16, color: _muted)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  // ── Cart items ────────────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final entry = cart.items[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(_dark ? 0.15 : 0.04),
                                  blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.item.name,
                                        style: TextStyle(fontWeight: FontWeight.w600, color: _text)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₦${entry.item.price.toStringAsFixed(0)} each",
                                      style: TextStyle(color: _muted, fontSize: 12),
                                    ),
                                    if (entry.selectedAddOns.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...entry.selectedAddOns.map((a) => Text(
                                            "+ ${a.name}  ₦${a.price.toStringAsFixed(0)}",
                                            style: TextStyle(
                                                color: _red.withOpacity(0.8),
                                                fontSize: 11),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _qtyBtn(icon: Icons.remove, onTap: () => cart.remove(entry.item.id)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text("${entry.quantity}",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                                  ),
                                  _qtyBtn(icon: Icons.add, onTap: () => cart.add(entry.item, cart.vendorId!)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₦${entry.lineTotal.toStringAsFixed(0)}",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _text),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => cart.removeAll(entry.item.id),
                                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Footer ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    decoration: BoxDecoration(
                      color: _card,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(_dark ? 0.3 : 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Delivery address ────────────────────────────────
                        GestureDetector(
                          onTap: _pickAddress,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _dark ? const Color(0xFF1A0808) : const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _deliveryAddress != null
                                    ? CustomerColors.primary
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    color: _deliveryAddress != null
                                        ? CustomerColors.primary
                                        : Colors.grey,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _deliveryAddress != null
                                        ? _deliveryAddress!['fullAddress']
                                        : 'Add delivery address',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _deliveryAddress != null ? _text : Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.edit_outlined, color: Colors.grey.shade400, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                       // ── Wallet payment toggle ───────────────────────────
                        _walletSection(totalAfterDiscount),
                        const SizedBox(height: 12),

                        // ── Promo code input ────────────────────────────────
                        _promoSection(subtotal),
                        const SizedBox(height: 12),

                        // ── Price summary ───────────────────────────────────
                        _priceSummary(subtotal, discount, totalAfterDiscount),
                        const SizedBox(height: 14),

                        // ── Checkout button ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CustomerColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _checkingOut ? null : () => _checkout(cart),
                            child: _checkingOut
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _payWithWallet
                                        ? "Pay with Wallet  ₦${totalAfterDiscount.toStringAsFixed(0)}"
                                        : "Checkout  ₦${totalAfterDiscount.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Wallet section widget ──────────────────────────────────────────────────
  Widget _walletSection(double orderTotal) {
    final hasEnough = _walletBalance >= orderTotal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF1A0808) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _payWithWallet
              ? CustomerColors.primary.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: CustomerColors.primary, size: 15),
              const SizedBox(width: 6),
              Text("Pay with Wallet",
                  style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              Switch(
                value: _payWithWallet,
                onChanged: hasEnough
                    ? (val) => setState(() => _payWithWallet = val)
                    : null,
                activeColor: CustomerColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                "Balance: ₦${_walletBalance.toStringAsFixed(0)}",
                style: TextStyle(
                    color: hasEnough ? Colors.green : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (!hasEnough) ...[
                const SizedBox(width: 8),
                Text(
                  "Insufficient for this order",
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Promo section widget ───────────────────────────────────────────────────
  Widget _promoSection(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF1A0808) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _appliedCode != null
              ? _red.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount_outlined, color: _red, size: 15),
              const SizedBox(width: 6),
              Text("Promo Code",
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),

          if (_appliedCode != null) ...[
            // ── Applied state ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_appliedCode!,
                            style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(_promoMessage,
                            style: TextStyle(color: _red.withOpacity(0.8), fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _removePromo,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 14, color: _red),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Input state ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                        color: _text, fontSize: 14,
                        letterSpacing: 1.2, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "Enter code",
                      hintStyle: TextStyle(color: _muted, fontSize: 13, letterSpacing: 0),
                      filled: true,
                      fillColor: _dark ? const Color(0xFF2C1010) : Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _red, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _applyingPromo ? null : () => _applyPromo(subtotal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _applyingPromo ? _red.withOpacity(0.5) : _red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _applyingPromo
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Apply",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (_promoError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_promoError, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ],
      ),
    );
  }

  // ── Price summary ──────────────────────────────────────────────────────────
  Widget _priceSummary(double subtotal, double discount, double total) {
    final hasDiscount = discount > 0 || _promoType == "free_delivery";
    return Column(
      children: [
        _summaryRow("Subtotal", "₦${subtotal.toStringAsFixed(0)}"),
        if (_promoType == "free_delivery")
          _summaryRow("Delivery fee", "FREE 🎉",
              valueColor: Colors.green, strikethrough: false),
        if (discount > 0)
          _summaryRow("Promo discount", "−₦${discount.toStringAsFixed(0)}",
              valueColor: Colors.green),
        if (hasDiscount) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: Colors.grey.withOpacity(0.15), height: 1),
          ),
          _summaryRow("Total",
            "₦${total.toStringAsFixed(0)}",
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _text),
            valueStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _red),
          ),
        ] else
          _summaryRow("Total",
            "₦${subtotal.toStringAsFixed(0)}",
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _text),
            valueStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _red),
          ),
        Text("+ delivery fee calculated at checkout",
            style: TextStyle(color: _muted, fontSize: 11)),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    Color? valueColor,
    bool strikethrough = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle ?? TextStyle(color: _muted, fontSize: 13)),
          Text(value,
              style: valueStyle ??
                  TextStyle(
                    color: valueColor ?? _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: strikethrough ? TextDecoration.lineThrough : null,
                  )),
        ],
      ),
    );
  }

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _dark ? Colors.grey.shade800 : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: _text),
      ),
    );
  }
}