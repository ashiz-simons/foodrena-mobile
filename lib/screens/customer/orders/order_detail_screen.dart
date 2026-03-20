import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/customer_wallet_service.dart';
import '../../shared/chat_screen.dart';
import '../../shared/call_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _order;
  bool _hasRatedVendor = false;
  bool _hasRatedRider = false;
  bool _ratingLoading = false;
  bool _ratingChecked = false;
  bool _cancelling = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
    if ((_order['status'] ?? '') == 'delivered') {
      _checkExistingRatings();
    }
  }

  void _openChat() {
    final rider = _order['rider'];
    final riderName = rider is Map
        ? (rider['user']?['name'] ?? rider['name'] ?? 'Rider')
        : 'Rider';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: _order['_id'],
          senderRole: 'customer',
          recipientName: riderName,
        ),
      ),
    );
  }

  void _openCall() {
    final rider = _order['rider'];
    final riderName = rider is Map
        ? (rider['user']?['name'] ?? rider['name'] ?? 'Rider')
        : 'Rider';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          orderId: _order['_id'],
          senderRole: 'customer',
          recipientName: riderName,
        ),
      ),
    );
  }

  Widget _chatCallBar() {
    final status = _order['status'] ?? '';
    final hasRider = _order['rider'] != null;
    final activeStatuses = [
      'rider_assigned', 'arrived_at_pickup',
      'picked_up', 'on_the_way'
    ];
    if (!hasRider || !activeStatuses.contains(status)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF0F2828) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CustomerColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded,
              color: CustomerColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Contact your rider",
                style: TextStyle(
                    color: _dark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          // Chat
          GestureDetector(
            onTap: _openChat,
            child: Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: CustomerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: CustomerColors.primary, size: 18),
            ),
          ),
          // Call
          GestureDetector(
            onTap: _openCall,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.call_rounded,
                  color: Colors.green, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkExistingRatings() async {
    try {
      final orderId = _order['_id'];
      final res = await ApiService.get("/ratings/order/$orderId");
      if (!mounted) return;
      setState(() {
        _hasRatedVendor = res['hasRatedVendor'] == true;
        _hasRatedRider = res['hasRatedRider'] == true;
        _ratingChecked = true;
      });
      if (!_hasRatedVendor || !_hasRatedRider) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showRatingDialog());
      }
    } catch (_) {
      setState(() => _ratingChecked = true);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dark ? const Color(0xFF2C1010) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cancel order?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _dark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          "This order will be cancelled. If you paid online, the amount will be refunded to your wallet.",
          style: TextStyle(fontSize: 14, color: _dark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Keep order", style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, cancel"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _doCancel();
  }

  Future<void> _doCancel() async {
    setState(() => _cancelling = true);
    try {
      final res = await CustomerWalletService.cancelOrder(_order['_id']);
      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(_order)..['status'] = 'cancelled';
        _cancelling = false;
      });
      final refunded = res['refunded'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refunded
              ? "Order cancelled. Refund sent to your wallet 💰"
              : "Order cancelled successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  Future<void> _showRatingDialog() async {
    final order = _order;
    final vendor = order['vendor'];
    final rider = order['rider'];
    final hasVendor = vendor != null && !_hasRatedVendor;
    final hasRider = rider != null && !_hasRatedRider;
    if (!hasVendor && !hasRider) return;

    int vendorScore = 5;
    int riderScore = 5;
    final vendorCommentCtrl = TextEditingController();
    final riderCommentCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: _dark ? const Color(0xFF2C1010) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CustomerColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: CustomerColors.primary, size: 32),
                ),
                const SizedBox(height: 12),
                Text("Rate your experience",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _dark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text("Your feedback helps improve the service",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (hasVendor) ...[
                  _ratingSection(
                    icon: Icons.storefront_outlined,
                    label: vendor['businessName'] ?? vendor['name'] ?? 'Kitchen',
                    sublabel: "Food & service",
                    score: vendorScore,
                    commentCtrl: vendorCommentCtrl,
                    onScoreChanged: (s) => setDialogState(() => vendorScore = s),
                  ),
                  if (hasRider) const SizedBox(height: 16),
                ],
                if (hasRider) ...[
                  _ratingSection(
                    icon: Icons.delivery_dining_outlined,
                    label: "Delivery rider",
                    sublabel: "Speed & professionalism",
                    score: riderScore,
                    commentCtrl: riderCommentCtrl,
                    onScoreChanged: (s) => setDialogState(() => riderScore = s),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Skip", style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CustomerColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _ratingLoading
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _submitRating(
                                  vendorScore: hasVendor ? vendorScore : null,
                                  vendorComment: vendorCommentCtrl.text.trim(),
                                  riderScore: hasRider ? riderScore : null,
                                  riderComment: riderCommentCtrl.text.trim(),
                                );
                              },
                        child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingSection({
    required IconData icon,
    required String label,
    required String sublabel,
    required int score,
    required TextEditingController commentCtrl,
    required ValueChanged<int> onScoreChanged,
  }) {
    final dark = _dark;
    final sectionBg = dark ? const Color(0xFF3A1515) : Colors.grey.shade50;
    final borderColor = dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final labelColor = dark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CustomerColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: labelColor)),
                  Text(sublabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < score;
              return GestureDetector(
                onTap: () => onScoreChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : Colors.grey.shade300,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentCtrl,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Add a comment (optional)",
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.all(10),
              filled: true,
              fillColor: dark ? const Color(0xFF2C1010) : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CustomerColors.primary, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating({
    int? vendorScore,
    String vendorComment = '',
    int? riderScore,
    String riderComment = '',
  }) async {
    setState(() => _ratingLoading = true);
    try {
      await ApiService.post("/ratings", {
        "orderId": _order['_id'],
        if (vendorScore != null) "vendorScore": vendorScore,
        if (vendorComment.isNotEmpty) "vendorComment": vendorComment,
        if (riderScore != null) "riderScore": riderScore,
        if (riderComment.isNotEmpty) "riderComment": riderComment,
      });
      if (!mounted) return;
      setState(() {
        if (vendorScore != null) _hasRatedVendor = true;
        if (riderScore != null) _hasRatedRider = true;
        _ratingLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks for your feedback! ⭐"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _ratingLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark;
    final order = _order;
    final orderId = (order['_id'] ?? '').toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final status = order['status'] ?? '';
    final total = order['total'] ?? order['totalAmount'] ?? 0;
    final items = order['items'] is List ? order['items'] as List : [];
    final vendor = order['vendor'];
    final vendorName = vendor?['businessName'] ?? vendor?['name'] ?? 'Unknown';
    final vendorRating = vendor?['rating'];
    final rider = order['rider'];
    final riderRating = rider?['rating'];
    final createdAt =
        order['createdAt'] != null ? DateTime.tryParse(order['createdAt']) : null;
    final deliveryAddress =
        order['deliveryAddress'] ?? order['address'] ?? order['location']?['address'];
    final paymentMethod = order['paymentMethod'] ?? order['payment'] ?? '';
    final deliveryFee = order['deliveryFee'] ?? 0;
    final isDelivered = status == 'delivered';
    final isPending = status == 'pending';
    final isPackage = order['type'] == 'package';

    final bg = dark ? CustomerColors.backgroundDark : const Color(0xFFF7F7F7);
    final appBarBg = dark ? const Color(0xFF1A0808) : null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Order #$shortId'),
        backgroundColor: appBarBg,
        foregroundColor: dark ? Colors.white : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(status, createdAt, dark),
            const SizedBox(height: 16),

            if (!isPackage && vendor != null) ...[
              _infoCard(
                title: 'Kitchen',
                dark: dark,
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined, color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(vendorName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: dark ? Colors.white : Colors.black)),
                    ),
                    if (vendorRating != null && vendorRating > 0)
                      _ratingBadge(vendorRating.toDouble()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (rider != null) ...[
              _infoCard(
                title: 'Rider',
                dark: dark,
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_outlined, color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(rider['user']?['name'] ?? 'Rider',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: dark ? Colors.white : Colors.black)),
                    ),
                    if (riderRating != null && riderRating > 0)
                      _ratingBadge(riderRating.toDouble()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (isPackage)
              _packageDetailsCard(order['packageDetails'], dark)
            else
              _infoCard(
                title: 'Items ordered',
                dark: dark,
                child: Column(
                  children: [
                    ...items.map((item) => _itemRow(item, dark)),
                    const Divider(height: 20),
                    if (deliveryFee != 0) _summaryRow('Delivery fee', '₦$deliveryFee', dark: dark),
                    _summaryRow('Total', '₦$total', bold: true, dark: dark),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            if (deliveryAddress != null) ...[
              _infoCard(
                title: 'Delivery address',
                dark: dark,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_formatAddress(deliveryAddress),
                          style: TextStyle(fontSize: 14, color: dark ? Colors.white70 : Colors.black87)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (paymentMethod.toString().isNotEmpty) ...[
              _infoCard(
                title: 'Payment',
                dark: dark,
                child: Row(
                  children: [
                    const Icon(Icons.payment_outlined, color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(paymentMethod.toString(),
                        style: TextStyle(fontSize: 14, color: dark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

           // ── Chat & Call bar — active orders with rider ───────────────
            _chatCallBar(),

            if (isDelivered && _ratingChecked) _ratingStatusCard(order, dark),

            // ── Cancel button — pending orders only ──────────────────────
            if (isPending) ...[
              const SizedBox(height: 8),
              _cancelButton(dark),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _cancelButton(bool dark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _cancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
              )
            : const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
        label: Text(
          _cancelling ? "Cancelling..." : "Cancel Order",
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red.withOpacity(dark ? 0.08 : 0.04),
        ),
        onPressed: _cancelling ? null : _confirmCancel,
      ),
    );
  }

  String _formatAddress(dynamic addr) {
    if (addr is String) return addr;
    if (addr is Map) {
      final parts = [addr['street'], addr['city'], addr['state']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .toList();
      return parts.join(', ');
    }
    return addr.toString();
  }

  Widget _ratingStatusCard(Map<String, dynamic> order, bool dark) {
    final vendor = order['vendor'];
    final rider = order['rider'];
    final bothRated = _hasRatedVendor && _hasRatedRider;
    final canRateVendor = vendor != null && !_hasRatedVendor;
    final canRateRider = rider != null && !_hasRatedRider;
    final canRate = canRateVendor || canRateRider;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bothRated
            ? (dark ? Colors.green.shade900.withOpacity(0.4) : Colors.green.shade50)
            : (dark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bothRated
              ? (dark ? Colors.green.shade700 : Colors.green.shade200)
              : (dark ? Colors.amber.shade700 : Colors.amber.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            bothRated ? Icons.star_rounded : Icons.star_outline_rounded,
            color: bothRated ? Colors.green : Colors.amber,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bothRated ? "Thanks for rating this order!" : "How was your experience?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: bothRated
                    ? (dark ? Colors.green.shade300 : Colors.green.shade700)
                    : (dark ? Colors.amber.shade300 : Colors.amber.shade800),
              ),
            ),
          ),
          if (canRate)
            GestureDetector(
              onTap: _showRatingDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CustomerColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("Rate",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ratingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _packageDetailsCard(dynamic details, bool dark) {
    if (details == null) return const SizedBox();
    return _infoCard(
      title: 'Package details',
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details['description'] != null)
            _detailRow(Icons.inventory_2_outlined, details['description'], dark),
          if (details['sizeLabel'] != null)
            _detailRow(Icons.straighten_outlined, "Size: ${details['sizeLabel']}", dark),
          if (details['weight'] != null)
            _detailRow(Icons.monitor_weight_outlined, "Weight: ${details['weight']} kg", dark),
          if (details['transportLabel'] != null)
            _detailRow(Icons.local_shipping_outlined, details['transportLabel'], dark),
          if (details['recipientName'] != null)
            _detailRow(Icons.person_outline, "Recipient: ${details['recipientName']}", dark),
          if (details['recipientPhone'] != null)
            _detailRow(Icons.phone_outlined, details['recipientPhone'], dark),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: dark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }

  Widget _statusCard(String status, DateTime? createdAt, bool dark) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'delivered': color = Colors.green; icon = Icons.check_circle_outline; break;
      case 'cancelled': color = Colors.red; icon = Icons.cancel_outlined; break;
      case 'refunded': color = Colors.purple; icon = Icons.replay_outlined; break;
      case 'pending': color = Colors.orange; icon = Icons.hourglass_empty_outlined; break;
      default: color = Colors.blue; icon = Icons.local_shipping_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(dark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                  style: TextStyle(
                      fontSize: 12, color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child, required bool dark}) {
    final cardColor = dark ? const Color(0xFF2C1010) : Colors.white;
    final borderColor = dark ? Colors.grey.shade800 : Colors.grey.shade200;
    final titleColor = dark ? Colors.grey.shade400 : Colors.grey.shade500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _itemRow(dynamic item, bool dark) {
    final name = item['name'] ?? item['menuItem']?['name'] ?? 'Item';
    final qty = item['quantity'] ?? item['qty'] ?? 1;
    final price = item['price'] ?? item['unitPrice'] ?? 0;
    final textColor = dark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: CustomerColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$qty',
                  style: const TextStyle(
                      color: CustomerColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: TextStyle(fontSize: 14, color: textColor))),
          Text('₦$price',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, required bool dark}) {
    final labelColor = bold
        ? (dark ? Colors.white : Colors.black)
        : (dark ? Colors.grey.shade400 : Colors.grey.shade600);
    final valueColor = bold ? CustomerColors.primary : (dark ? Colors.white70 : Colors.black);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor)),
        ],
      ),
    );
  }
}