import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/order_alert_service.dart';
import '../../services/rider_service.dart';

class OrderAlertScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final VoidCallback? onAccepted;
  final VoidCallback? onRejected;

  const OrderAlertScreen({
    super.key,
    required this.orderData,
    this.onAccepted,
    this.onRejected,
  });

  @override
  State<OrderAlertScreen> createState() => _OrderAlertScreenState();
}

class _OrderAlertScreenState extends State<OrderAlertScreen>
    with SingleTickerProviderStateMixin {
  bool _responding = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _kGreen  = Color(0xFF00D97E);
  static const _kRed    = Color(0xFFFF4757);
  static const _kAmber  = Color(0xFFFFC542);
  static const _kBg     = Color(0xFF0A1628);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_responding) return;
    HapticFeedback.heavyImpact();
    setState(() => _responding = true);

    try {
      await OrderAlertService.stopAlert();
      await RiderService.accept(widget.orderData["_id"]);
      if (mounted) {
        widget.onAccepted?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _responding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: _kRed,
          ),
        );
      }
    }
  }

  Future<void> _reject() async {
    if (_responding) return;
    HapticFeedback.mediumImpact();
    setState(() => _responding = true);

    try {
      await OrderAlertService.stopAlert();
      await RiderService.reject(widget.orderData["_id"]);
      if (mounted) {
        widget.onRejected?.call();
        Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _responding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: _kRed,
          ),
        );
      }
    }
  }

  String _formatAddress(dynamic addr) {
    if (addr is String) return addr;
    if (addr is Map) {
      final parts = [addr['street'], addr['city'], addr['state']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .toList();
      return parts.join(', ');
    }
    return "Address not available";
  }

  @override
  Widget build(BuildContext context) {
    final order        = widget.orderData;
    final deliveryFee  = order["deliveryFee"] ?? 0;
    final total        = order["total"] ?? 0;
    final items        = order["items"] is List ? order["items"] as List : [];
    final vendorName   = order["vendor"]?["businessName"] ??
        order["vendor"]?["name"] ?? "Vendor";
    final deliveryAddr = _formatAddress(order["deliveryAddress"]);
    final orderId      = (order["_id"] ?? "").toString();
    final shortId      = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final isPackage = order["type"] == "package";

    return PopScope(
      canPop: false, // prevent back button dismissal
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),

                // ── Pulsing icon ────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kGreen.withOpacity(0.15),
                        border: Border.all(
                            color: _kGreen.withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: _kGreen,
                        size: 48,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Title ───────────────────────────────────────
                const Text(
                  "New Order!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Order #$shortId",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Order details card ──────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Delivery fee highlight
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _kGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _kGreen.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "₦$deliveryFee",
                                style: const TextStyle(
                                  color: _kGreen,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                "Delivery earnings",
                                style: TextStyle(
                                  color: _kGreen,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Details rows
                        _detailRow(
                          icon: Icons.storefront_rounded,
                          label: "Pickup from",
                          value: vendorName,
                        ),
                        const SizedBox(height: 10),
                        _detailRow(
                          icon: Icons.location_on_rounded,
                          label: "Deliver to",
                          value: deliveryAddr,
                        ),
                        const SizedBox(height: 10),

                        if (isPackage)
                          _detailRow(
                            icon: Icons.inventory_2_rounded,
                            label: "Type",
                            value: "Package delivery",
                          )
                        else
                          _detailRow(
                            icon: Icons.receipt_long_rounded,
                            label: "Items",
                            value: "${items.length} item${items.length == 1 ? '' : 's'} • ₦$total",
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Accept / Reject buttons ─────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _responding
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: _kGreen))
                      : Row(
                          children: [
                            // Reject
                            Expanded(
                              child: GestureDetector(
                                onTap: _reject,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  decoration: BoxDecoration(
                                    color: _kRed.withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    border: Border.all(
                                        color: _kRed.withOpacity(0.4)),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.close_rounded,
                                          color: _kRed, size: 28),
                                      SizedBox(height: 4),
                                      Text("Reject",
                                          style: TextStyle(
                                              color: _kRed,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Accept
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: _accept,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  decoration: BoxDecoration(
                                    color: _kGreen,
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _kGreen.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: Colors.white,
                                          size: 28),
                                      SizedBox(height: 4),
                                      Text("Accept",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kAmber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}