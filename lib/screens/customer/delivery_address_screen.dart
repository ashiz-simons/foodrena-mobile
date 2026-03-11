import 'package:flutter/material.dart';
import '../../utils/session.dart';

const _kBlue = Color(0xFF1E3A5F);

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  bool _saving = false;

  static const _presets = {
    'Ikeja': {'lat': 6.6059, 'lng': 3.3491},
    'Lekki Phase 1': {'lat': 6.4698, 'lng': 3.5852},
    'Yaba': {'lat': 6.5095, 'lng': 3.3711},
    'Surulere': {'lat': 6.4969, 'lng': 3.3486},
    'Ajah': {'lat': 6.4690, 'lng': 3.6218},
    'Victoria Island': {'lat': 6.4281, 'lng': 3.4219},
    'Ikoyi': {'lat': 6.4550, 'lng': 3.4376},
    'Ojota': {'lat': 6.5833, 'lng': 3.3833},
    'Magodo': {'lat': 6.6167, 'lng': 3.3833},
    'Gbagada': {'lat': 6.5500, 'lng': 3.3833},
  };

  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final user = await Session.getUser();
    if (!mounted) return;
    if (user?['lastDeliveryAddress'] != null) {
      final addr = user!['lastDeliveryAddress'];
      _streetController.text = addr['street'] ?? '';
      _landmarkController.text = addr['landmark'] ?? '';
      _cityController.text = addr['city'] ?? '';
      setState(() => _selectedArea = addr['area']);
    }
  }

  void _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an area')),
      );
      return;
    }

    setState(() => _saving = true);

    final coords = _presets[_selectedArea!]!;
    final addressText =
        '\${_streetController.text.trim()}, \${_selectedArea!}, \${_cityController.text.trim()}';

    final addressData = {
      'street': _streetController.text.trim(),
      'landmark': _landmarkController.text.trim(),
      'city': _cityController.text.trim(),
      'area': _selectedArea,
      'fullAddress': addressText,
      'lat': coords['lat'],
      'lng': coords['lng'],
    };

    final user = await Session.getUser();
    if (user != null) {
      user['lastDeliveryAddress'] = addressData;
      await Session.saveUser(user);
    }

    await (
      coords['lat'] as double,
      coords['lng'] as double,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, addressData);
  }

  @override
  void dispose() {
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Delivery Address'),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBlue.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: _kBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter your delivery address so we can calculate the delivery fee.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Area selector
              const Text('Area',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedArea != null
                        ? _kBlue
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedArea,
                    isExpanded: true,
                    hint: const Text('Select your area'),
                    items: _presets.keys
                        .map((area) => DropdownMenuItem(
                              value: area,
                              child: Text(area),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedArea = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Street address'),
              const SizedBox(height: 8),
              _textField(
                controller: _streetController,
                hint: 'e.g. 12 Allen Avenue',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _label('Landmark (optional)'),
              const SizedBox(height: 8),
              _textField(
                controller: _landmarkController,
                hint: 'e.g. Near Access Bank, opposite Total filling station',
                validator: (_) => null,
              ),
              const SizedBox(height: 16),

              _label('City'),
              const SizedBox(height: 8),
              _textField(
                controller: _cityController,
                hint: 'e.g. Lagos',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Address',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}