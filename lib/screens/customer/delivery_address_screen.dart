import 'package:flutter/material.dart';
import '../../utils/session.dart';
import '../../core/theme/app_theme.dart';

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _streetController  = TextEditingController();
  final _landmarkController= TextEditingController();
  final _cityController    = TextEditingController();
  bool _saving = false;

  static const _presets = {
    'Ikeja':           {'lat': 6.6059, 'lng': 3.3491},
    'Lekki Phase 1':   {'lat': 6.4698, 'lng': 3.5852},
    'Yaba':            {'lat': 6.5095, 'lng': 3.3711},
    'Surulere':        {'lat': 6.4969, 'lng': 3.3486},
    'Ajah':            {'lat': 6.4690, 'lng': 3.6218},
    'Victoria Island': {'lat': 6.4281, 'lng': 3.4219},
    'Ikoyi':           {'lat': 6.4550, 'lng': 3.4376},
    'Ojota':           {'lat': 6.5833, 'lng': 3.3833},
    'Magodo':          {'lat': 6.6167, 'lng': 3.3833},
    'Gbagada':         {'lat': 6.5500, 'lng': 3.3833},
  };

  String? _selectedArea;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool   get _dark  => Theme.of(context).brightness == Brightness.dark;
  Color  get _bg    => _dark ? const Color(0xFF1A0808) : const Color(0xFFF7F7F7);
  Color  get _card  => _dark ? const Color(0xFF2C1010) : Colors.white;
  Color  get _text  => _dark ? Colors.white            : const Color(0xFF1A1A1A);
  Color  get _muted => _dark ? Colors.grey.shade400    : Colors.grey.shade600;
  Color  get _border=> _dark ? Colors.grey.shade700    : Colors.grey.shade300;
  Color  get _primary => CustomerColors.primary; // DC2626 red

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
      _streetController.text   = addr['street']   ?? '';
      _landmarkController.text = addr['landmark'] ?? '';
      _cityController.text     = addr['city']     ?? '';
      setState(() => _selectedArea = addr['area']);
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an area')),
      );
      return;
    }

    setState(() => _saving = true);

    final coords      = _presets[_selectedArea!]!;
    final addressText =
        '${_streetController.text.trim()}, $_selectedArea, ${_cityController.text.trim()}';

    final addressData = {
      'street':      _streetController.text.trim(),
      'landmark':    _landmarkController.text.trim(),
      'city':        _cityController.text.trim(),
      'area':        _selectedArea,
      'fullAddress': addressText,
      'lat':         coords['lat'],
      'lng':         coords['lng'],
    };

    final user = await Session.getUser();
    if (user != null) {
      user['lastDeliveryAddress'] = addressData;
      await Session.saveUser(user);
    }

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _dark ? const Color(0xFF2C1010) : _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Delivery Address',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info banner ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(_dark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter your delivery address so we can calculate the delivery fee.',
                        style: TextStyle(fontSize: 13, color: _text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Area selector ─────────────────────────────────────────────
              _label('Area'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedArea != null ? _primary : _border,
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedArea,
                    isExpanded: true,
                    dropdownColor: _card,
                    style: TextStyle(color: _text, fontSize: 14),
                    hint: Text('Select your area',
                        style: TextStyle(color: _muted)),
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
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Address',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600, fontSize: 14, color: _text));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: _text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}