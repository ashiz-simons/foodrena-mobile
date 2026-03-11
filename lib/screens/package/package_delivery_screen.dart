import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../customer/delivery_address_screen.dart';
import 'package_pricing_screen.dart';

// Transport modes
const List<Map<String, dynamic>> kTransportModes = [
  {'id': 'motorcycle', 'label': 'Motorcycle', 'icon': Icons.two_wheeler, 'base': 500},
  {'id': 'car', 'label': 'Car', 'icon': Icons.directions_car_outlined, 'base': 1000},
  {'id': 'van', 'label': 'Van / Truck', 'icon': Icons.local_shipping_outlined, 'base': 2000},
];

// Package sizes
const List<Map<String, dynamic>> kPackageSizes = [
  {'id': 'small', 'label': 'Small', 'sub': 'Envelope / Documents', 'icon': Icons.mail_outline, 'multiplier': 1.0},
  {'id': 'medium', 'label': 'Medium', 'sub': 'Shoebox', 'icon': Icons.inventory_2_outlined, 'multiplier': 1.5},
  {'id': 'large', 'label': 'Large', 'sub': 'Bag / Box', 'icon': Icons.shopping_bag_outlined, 'multiplier': 2.0},
  {'id': 'xl', 'label': 'Extra Large', 'sub': 'Furniture / Appliance', 'icon': Icons.weekend_outlined, 'multiplier': 3.0},
];

class PackageDeliveryScreen extends StatefulWidget {
  const PackageDeliveryScreen({super.key});

  @override
  State<PackageDeliveryScreen> createState() => _PackageDeliveryScreenState();
}

class _PackageDeliveryScreenState extends State<PackageDeliveryScreen> {
  // Step tracker
  int _step = 0; // 0=addresses, 1=recipient, 2=package, 3=transport

  // Address
  Map<String, dynamic>? _pickupAddress;
  Map<String, dynamic>? _deliveryAddress;

  // Recipient
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  // Package
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _selectedSize = 'small';
  File? _packagePhoto;

  // Transport
  String _selectedTransport = 'motorcycle';

  bool _loading = false;
  String _error = '';

  static const Color _primary = Color(0xFFDC2626);

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAddress(bool isPickup) async {
    // Pass existing address to pre-fill, but ensure each opens independently
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const DeliveryAddressScreen(),
        settings: RouteSettings(name: isPickup ? 'pickup' : 'delivery'),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isPickup) {
          _pickupAddress = result;
          // Do NOT copy to delivery — user must fill separately
        } else {
          _deliveryAddress = result;
        }
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() => _packagePhoto = File(picked.path));
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0: return _pickupAddress != null && _deliveryAddress != null;
      case 1: return _recipientNameCtrl.text.trim().isNotEmpty &&
          _recipientPhoneCtrl.text.trim().isNotEmpty;
      case 2: return _descCtrl.text.trim().isNotEmpty;
      case 3: return true;
      default: return false;
    }
  }

  void _next() {
    if (_step < 3) {
      setState(() { _step++; _error = ''; });
    } else {
      _goToPricing();
    }
  }

  void _goToPricing() {
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    final size = kPackageSizes.firstWhere((s) => s['id'] == _selectedSize);
    final transport = kTransportModes.firstWhere((t) => t['id'] == _selectedTransport);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackagePricingScreen(
          pickupAddress: _pickupAddress!,
          deliveryAddress: _deliveryAddress!,
          recipientName: _recipientNameCtrl.text.trim(),
          recipientPhone: _recipientPhoneCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          size: size,
          weight: weight,
          transport: transport,
          packagePhoto: _packagePhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Send a Package'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: _stepIndicator(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: [
                _stepAddresses(),
                _stepRecipient(),
                _stepPackage(),
                _stepTransport(),
              ][_step],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    final labels = ['Addresses', 'Recipient', 'Package', 'Transport'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: List.generate(4, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done
                          ? Colors.green
                          : active
                              ? _primary
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? _primary
                          : done
                              ? Colors.green
                              : Colors.grey.shade400,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Step 0: Addresses ──────────────────────────────
  Widget _stepAddresses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Where to pick up from?'),
        _addressCard(
          label: 'Pickup Location',
          address: _pickupAddress,
          icon: Icons.radio_button_checked,
          iconColor: Colors.green,
          onTap: () => _pickAddress(true),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Where to deliver to?'),
        _addressCard(
          label: 'Delivery Location',
          address: _deliveryAddress,
          icon: Icons.location_on,
          iconColor: _primary,
          onTap: () => _pickAddress(false),
        ),
      ],
    );
  }

  // ── Step 1: Recipient ──────────────────────────────
  Widget _stepRecipient() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Recipient's details"),
        const Text('Who will receive this package?',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),
        _inputField('Recipient Name', _recipientNameCtrl,
            icon: Icons.person_outline),
        const SizedBox(height: 14),
        _inputField('Recipient Phone', _recipientPhoneCtrl,
            icon: Icons.phone_outlined,
            inputType: TextInputType.phone),
      ],
    );
  }

  // ── Step 2: Package details ────────────────────────
  Widget _stepPackage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Package details'),
        _inputField('What are you sending?', _descCtrl,
            icon: Icons.description_outlined, maxLines: 2),
        const SizedBox(height: 14),
        _inputField('Weight (kg) — optional', _weightCtrl,
            icon: Icons.monitor_weight_outlined,
            inputType: TextInputType.number),
        const SizedBox(height: 20),
        _sectionTitle('Package size'),
        const SizedBox(height: 10),
        ...kPackageSizes.map((size) => _sizeCard(size)),
        const SizedBox(height: 20),
        _sectionTitle('Photo of package (optional)'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _packagePhoto != null ? _primary : Colors.grey.shade300,
                  style: BorderStyle.solid),
            ),
            child: _packagePhoto != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_packagePhoto!,
                            width: double.infinity, height: 120, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _packagePhoto = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Tap to take photo',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Step 3: Transport mode ─────────────────────────
  Widget _stepTransport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Choose transport'),
        const Text('Select based on your package size and urgency',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        ...kTransportModes.map((t) => _transportCard(t)),
        const SizedBox(height: 20),
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _summaryRow('From', _pickupAddress?['fullAddress'] ?? ''),
              _summaryRow('To', _deliveryAddress?['fullAddress'] ?? ''),
              _summaryRow('Recipient', '${_recipientNameCtrl.text} · ${_recipientPhoneCtrl.text}'),
              _summaryRow('Package', _descCtrl.text),
              _summaryRow('Size', kPackageSizes.firstWhere((s) => s['id'] == _selectedSize)['label']),
              if (_weightCtrl.text.isNotEmpty)
                _summaryRow('Weight', '${_weightCtrl.text} kg'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _sizeCard(Map<String, dynamic> size) {
    final selected = _selectedSize == size['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedSize = size['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _primary : Colors.grey.shade200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(size['icon'] as IconData,
                color: selected ? _primary : Colors.grey, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(size['label'],
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? _primary : Colors.black87)),
                  Text(size['sub'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _transportCard(Map<String, dynamic> transport) {
    final selected = _selectedTransport == transport['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedTransport = transport['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _primary : Colors.grey.shade200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? _primary.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(transport['icon'] as IconData,
                  color: selected ? _primary : Colors.grey, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transport['label'],
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? _primary : Colors.black87)),
                  Text('Base fare: ₦${transport['base']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _addressCard({
    required String label,
    required Map<String, dynamic>? address,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: address != null ? iconColor.withOpacity(0.4) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: address != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address['area'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(address['fullAddress'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    )
                  : Text(label,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {IconData? icon, TextInputType? inputType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          if (_step > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onPressed: () => setState(() { _step--; _error = ''; }),
                child: const Text('Back', style: TextStyle(color: Colors.black54)),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceed() ? _primary : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _canProceed() ? _next : null,
              child: Text(
                _step == 3 ? 'See Price & Confirm' : 'Continue',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}