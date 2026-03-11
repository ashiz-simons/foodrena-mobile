import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/customer_theme.dart';
import '../../../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _hasRatedVendor = false;
  bool _hasRatedRider = false;
  bool _ratingLoading = false;
  bool _ratingChecked = false;

  @override
  void initState() {
    super.initState();
    if ((widget.order['status'] ?? '') == 'delivered') {
      _checkExistingRatings();
    }
  }

  Future<void> _checkExistingRatings() async {
    try {
      final orderId = widget.order['_id'];
      final res = await ApiService.get("/ratings/order/$orderId");
      if (!mounted) return;
      setState(() {
        _hasRatedVendor = res['hasRatedVendor'] == true;
        _hasRatedRider = res['hasRatedRider'] == true;
        _ratingChecked = true;
      });
      // Auto-show popup if not yet rated
      if (!_hasRatedVendor || !_hasRatedRider) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showRatingDialog());
      }
    } catch (_) {
      setState(() => _ratingChecked = true);
    }
  }

  Future<void> _showRatingDialog() async {
    final order = widget.order;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CustomerColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: CustomerColors.primary, size: 32),
                ),
                const SizedBox(height: 12),
                const Text("Rate your experience",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Your feedback helps improve the service",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),

                // Vendor rating
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

                // Rider rating
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
                        child: Text("Skip",
                            style: TextStyle(color: Colors.grey.shade500)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                        child: const Text("Submit",
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(sublabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
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
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Add a comment (optional)",
              hintStyle:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: CustomerColors.primary, width: 1.5),
              ),
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
        "orderId": widget.order['_id'],
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
        const SnackBar(
          content: Text("Thanks for your feedback! ⭐"),
          backgroundColor: Colors.green,
        ),
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
    final order = widget.order;
    final orderId = (order['_id'] ?? '').toString();
    final shortId = orderId.length > 8
        ? orderId.substring(orderId.length - 8).toUpperCase()
        : orderId.toUpperCase();
    final status = order['status'] ?? '';
    final total = order['total'] ?? order['totalAmount'] ?? 0;
    final items = order['items'] is List ? order['items'] as List : [];
    final vendor = order['vendor'];
    final vendorName =
        vendor?['businessName'] ?? vendor?['name'] ?? 'Unknown';
    final vendorRating = vendor?['rating'];
    final rider = order['rider'];
    final riderRating = rider?['rating'];
    final createdAt = order['createdAt'] != null
        ? DateTime.tryParse(order['createdAt'])
        : null;
    final deliveryAddress = order['deliveryAddress'] ??
        order['address'] ??
        order['location']?['address'];
    final paymentMethod = order['paymentMethod'] ?? order['payment'] ?? '';
    final deliveryFee = order['deliveryFee'] ?? 0;
    final isDelivered = status == 'delivered';
    final isPackage = order['type'] == 'package';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: Text('Order #$shortId')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(status, createdAt),
            const SizedBox(height: 16),

            // Vendor (food orders only)
            if (!isPackage && vendor != null) ...[
              _infoCard(
                title: 'Kitchen',
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined,
                        color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(vendorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    if (vendorRating != null && vendorRating > 0)
                      _ratingBadge(vendorRating.toDouble()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Rider (if assigned)
            if (rider != null) ...[
              _infoCard(
                title: 'Rider',
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_outlined,
                        color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rider['user']?['name'] ?? 'Rider',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    if (riderRating != null && riderRating > 0)
                      _ratingBadge(riderRating.toDouble()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Items / Package details
            if (isPackage)
              _packageDetailsCard(order['packageDetails'])
            else
              _infoCard(
                title: 'Items ordered',
                child: Column(
                  children: [
                    ...items.map((item) => _itemRow(item)),
                    const Divider(height: 20),
                    if (deliveryFee != 0)
                      _summaryRow('Delivery fee', '₦$deliveryFee'),
                    _summaryRow('Total', '₦$total', bold: true),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Delivery address
            if (deliveryAddress != null) ...[
              _infoCard(
                title: 'Delivery address',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatAddress(deliveryAddress),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Payment
            if (paymentMethod.toString().isNotEmpty) ...[
              _infoCard(
                title: 'Payment',
                child: Row(
                  children: [
                    const Icon(Icons.payment_outlined,
                        color: CustomerColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(paymentMethod.toString(),
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Rating section (delivered orders)
            if (isDelivered && _ratingChecked)
              _ratingStatusCard(order),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatAddress(dynamic addr) {
    if (addr is String) return addr;
    if (addr is Map) {
      final parts = [
        addr['street'],
        addr['city'],
        addr['state'],
      ].where((p) => p != null && p.toString().isNotEmpty).toList();
      return parts.join(', ');
    }
    return addr.toString();
  }

  Widget _ratingStatusCard(Map<String, dynamic> order) {
    final vendor = order['vendor'];
    final rider = order['rider'];
    final bothRated = _hasRatedVendor && _hasRatedRider;
    final canRateVendor = vendor != null && !_hasRatedVendor;
    final canRateRider = rider != null && !_hasRatedRider;
    final canRate = canRateVendor || canRateRider;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bothRated ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bothRated
              ? Colors.green.shade200
              : Colors.amber.shade200,
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
              bothRated
                  ? "Thanks for rating this order!"
                  : "How was your experience?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: bothRated
                    ? Colors.green.shade700
                    : Colors.amber.shade800,
              ),
            ),
          ),
          if (canRate)
            GestureDetector(
              onTap: _showRatingDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CustomerColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Rate",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
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
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _packageDetailsCard(dynamic details) {
    if (details == null) return const SizedBox();
    return _infoCard(
      title: 'Package details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details['description'] != null)
            _detailRow(Icons.inventory_2_outlined, details['description']),
          if (details['sizeLabel'] != null)
            _detailRow(Icons.straighten_outlined, "Size: ${details['sizeLabel']}"),
          if (details['weight'] != null)
            _detailRow(Icons.monitor_weight_outlined, "Weight: ${details['weight']} kg"),
          if (details['transportLabel'] != null)
            _detailRow(Icons.local_shipping_outlined, details['transportLabel']),
          if (details['recipientName'] != null)
            _detailRow(Icons.person_outline, "Recipient: ${details['recipientName']}"),
          if (details['recipientPhone'] != null)
            _detailRow(Icons.phone_outlined, details['recipientPhone']),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _statusCard(String status, DateTime? createdAt) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green; icon = Icons.check_circle_outline; break;
      case 'cancelled':
        color = Colors.red; icon = Icons.cancel_outlined; break;
      case 'refunded':
        color = Colors.purple; icon = Icons.replay_outlined; break;
      case 'pending':
        color = Colors.orange; icon = Icons.hourglass_empty_outlined; break;
      default:
        color = Colors.blue; icon = Icons.local_shipping_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
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
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _itemRow(dynamic item) {
    final name = item['name'] ?? item['menuItem']?['name'] ?? 'Item';
    final qty = item['quantity'] ?? item['qty'] ?? 1;
    final price = item['price'] ?? item['unitPrice'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: CustomerColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$qty',
                  style: TextStyle(
                      color: CustomerColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          Text('₦$price',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: bold ? Colors.black : Colors.grey.shade600,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: bold ? CustomerColors.primary : Colors.black)),
        ],
      ),
    );
  }
}