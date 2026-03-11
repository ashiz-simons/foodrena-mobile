import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../customer/orders/customer_orders_screen.dart';

class PackagePricingScreen extends StatefulWidget {
  final Map<String, dynamic> pickupAddress;
  final Map<String, dynamic> deliveryAddress;
  final String recipientName;
  final String recipientPhone;
  final String description;
  final Map<String, dynamic> size;
  final double weight;
  final Map<String, dynamic> transport;
  final File? packagePhoto;

  const PackagePricingScreen({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.description,
    required this.size,
    required this.weight,
    required this.transport,
    this.packagePhoto,
  });

  @override
  State<PackagePricingScreen> createState() => _PackagePricingScreenState();
}

class _PackagePricingScreenState extends State<PackagePricingScreen> {
  bool _placing = false;
  String _error = '';

  static const Color _primary = Color(0xFFDC2626);

  // ── Haversine distance ──────────────────────────────
  double _distanceKm() {
    final pickupLat = widget.pickupAddress['lat'];
    final pickupLng = widget.pickupAddress['lng'];
    final deliveryLat = widget.deliveryAddress['lat'];
    final deliveryLng = widget.deliveryAddress['lng'];

    if (pickupLat == null || pickupLng == null ||
        deliveryLat == null || deliveryLng == null) return 5.0; // fallback

    const R = 6371.0;
    final dLat = _deg2rad(deliveryLat - pickupLat);
    final dLng = _deg2rad(deliveryLng - pickupLng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(pickupLat)) *
            cos(_deg2rad(deliveryLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // ── Pricing breakdown ───────────────────────────────
  Map<String, dynamic> _calcPricing() {
    final distKm = _distanceKm();
    final baseFare = (widget.transport['base'] as int).toDouble();
    final multiplier = widget.size['multiplier'] as double;
    final weight = widget.weight;

    // Distance surcharge: ₦100/km after first 3km
    final distSurcharge = distKm > 3 ? (distKm - 3) * 100 : 0.0;

    // Weight surcharge: ₦50/kg after 5kg
    final weightSurcharge = weight > 5 ? (weight - 5) * 50 : 0.0;

    // Size-adjusted base
    final sizeAdjusted = baseFare * multiplier;

    final total = (sizeAdjusted + distSurcharge + weightSurcharge).clamp(500, 15000);

    return {
      'baseFare': sizeAdjusted.round(),
      'distanceKm': distKm,
      'distSurcharge': distSurcharge.round(),
      'weightSurcharge': weightSurcharge.round(),
      'total': total.round(),
    };
  }

  Future<void> _placeOrder() async {
    setState(() { _placing = true; _error = ''; });

    try {
      final pricing = _calcPricing();

      final body = {
        "type": "package",
        "deliveryFee": pricing['total'],
        "total": pricing['total'],
        "subtotal": 0,
        "items": [],
        "packageDetails": {
          "description": widget.description,
          "size": widget.size['id'],
          "sizeLabel": widget.size['label'],
          "weight": widget.weight,
          "transportMode": widget.transport['id'],
          "transportLabel": widget.transport['label'],
          "recipientName": widget.recipientName,
          "recipientPhone": widget.recipientPhone,
        },
        "pickupLocation": {
          "address": widget.pickupAddress['fullAddress'],
          "lat": widget.pickupAddress['lat'],
          "lng": widget.pickupAddress['lng'],
        },
        "deliveryAddress": {
          "street": widget.deliveryAddress['street'] ?? '',
          "city": widget.deliveryAddress['city'] ?? '',
          "state": widget.deliveryAddress['area'] ?? '',
          "lat": widget.deliveryAddress['lat'],
          "lng": widget.deliveryAddress['lng'],
        },
        "deliveryLocation": {
          "lat": widget.deliveryAddress['lat'],
          "lng": widget.deliveryAddress['lng'],
        },
        "distanceKm": pricing['distanceKm'],
        "paymentStatus": "unpaid",
      };

      await ApiService.post("/orders", body);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Package order placed! Finding a rider...'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to orders screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricing = _calcPricing();
    final distKm = pricing['distanceKm'] as double;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Price Breakdown'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route card
                  _infoCard(
                    child: Column(
                      children: [
                        _routeRow(
                          icon: Icons.radio_button_checked,
                          color: Colors.green,
                          label: 'Pickup',
                          address: widget.pickupAddress['fullAddress'] ?? '',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Container(
                              height: 24, width: 2, color: Colors.grey.shade200),
                        ),
                        _routeRow(
                          icon: Icons.location_on,
                          color: _primary,
                          label: 'Deliver to',
                          address: widget.deliveryAddress['fullAddress'] ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recipient
                  _infoCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recipient',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(widget.recipientName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(widget.recipientPhone,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Package summary
                  _infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(widget.size['icon'] as IconData,
                                  color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.description,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${widget.size['label']} · ${widget.transport['label']}${widget.weight > 0 ? ' · ${widget.weight}kg' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.packagePhoto != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(widget.packagePhoto!,
                                height: 100, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing breakdown
                  _infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Price Breakdown',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _priceRow('Base fare (${widget.size['label']} · ${widget.transport['label']})',
                            '₦${pricing['baseFare']}'),
                        _priceRow('Distance (${distKm.toStringAsFixed(1)} km)',
                            pricing['distSurcharge'] > 0
                                ? '₦${pricing['distSurcharge']}'
                                : 'Included'),
                        if (pricing['weightSurcharge'] > 0)
                          _priceRow('Weight surcharge', '₦${pricing['weightSurcharge']}'),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('₦${pricing['total']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _primary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error,
                            style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Confirm button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _placing ? null : _placeOrder,
                child: _placing
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Confirm & Pay ₦${pricing['total']}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(address,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: child,
    );
  }
}