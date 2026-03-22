import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

const bool MAPS_ENABLED = false;
const String _kGoogleApiKey = 'YOUR_GOOGLE_API_KEY';
const _kTeal = Color(0xFF00B4B4);

class VendorOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback? onLeave;

  const VendorOnboardingScreen({
    super.key,
    required this.onCompleted,
    this.onLeave,
  });

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final businessCtrl       = TextEditingController();
  final streetCtrl         = TextEditingController();
  final cityCtrl           = TextEditingController();
  final stateCtrl          = TextEditingController();
  final countryCtrl        = TextEditingController();
  final accountNumberCtrl  = TextEditingController();
  final locationSearchCtrl = TextEditingController();

  // ── Bank verification state ──────────────────────────────────────────────
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filteredBanks = [];
  String? _selectedBankName;
  String? _selectedBankCode;
  String? _resolvedAccountName;
  bool _verifying = false;
  bool _verified  = false;
  String _bankError = '';

  // ── Places state ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _searchingPlaces = false;
  double? _selectedLat;
  double? _selectedLng;
  String _selectedPlaceLabel = '';

  bool loading = false;
  String error = '';

  bool get _dark  => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
  Color get _card => _dark ? const Color(0xFF0F2828) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted    => _dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);
  Color get _readOnly => _dark ? const Color(0xFF0A1E1E) : const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadBanks();
    accountNumberCtrl.addListener(_onAccountNumberChanged);
  }

  @override
  void dispose() {
    businessCtrl.dispose(); streetCtrl.dispose(); cityCtrl.dispose();
    stateCtrl.dispose(); countryCtrl.dispose();
    accountNumberCtrl.dispose(); locationSearchCtrl.dispose();
    super.dispose();
  }

  // ── Bank loading & verification ──────────────────────────────────────────
  Future<void> _loadBanks() async {
    try {
      final res = await ApiService.get("/payments/banks");
      if (res is List) {
        setState(() {
          _banks = List<Map<String, dynamic>>.from(res);
          _filteredBanks = _banks;
        });
      }
    } catch (_) {}
  }

  void _onAccountNumberChanged() {
    final num = accountNumberCtrl.text.trim();
    if (_verified) setState(() { _verified = false; _resolvedAccountName = null; });
    if (num.length == 10 && _selectedBankCode != null) {
      _verifyAccount();
    }
  }

  Future<void> _verifyAccount() async {
    final number = accountNumberCtrl.text.trim();
    if (number.length != 10 || _selectedBankCode == null) return;

    setState(() { _verifying = true; _bankError = ''; _resolvedAccountName = null; _verified = false; });

    try {
      final res = await ApiService.get(
          "/payments/verify-account?accountNumber=$number&bankCode=$_selectedBankCode");
      if (res["accountName"] != null) {
        setState(() {
          _resolvedAccountName = res["accountName"];
          _verified = true;
          _verifying = false;
        });
      } else {
        setState(() {
          _bankError = res["message"] ?? "Could not verify account";
          _verifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _bankError = e.toString().replaceAll("Exception: ", "");
        _verifying = false;
      });
    }
  }

  void _showBankPicker() {
    final searchCtrl = TextEditingController();
    setState(() => _filteredBanks = _banks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: _text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search bank...",
                    hintStyle: TextStyle(color: _muted),
                    prefixIcon: Icon(Icons.search, color: _muted),
                    filled: true,
                    fillColor: _dark
                        ? const Color(0xFF163535)
                        : const Color(0xFFE0F7F7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (q) {
                    setSheet(() {
                      _filteredBanks = _banks
                          .where((b) => (b["name"] ?? "")
                              .toString()
                              .toLowerCase()
                              .contains(q.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredBanks.length,
                  itemBuilder: (_, i) {
                    final bank = _filteredBanks[i];
                    return ListTile(
                      title: Text(bank["name"] ?? "",
                          style: TextStyle(color: _text, fontSize: 14)),
                      onTap: () {
                        setState(() {
                          _selectedBankName = bank["name"];
                          _selectedBankCode = bank["code"];
                          _verified = false;
                          _resolvedAccountName = null;
                          _bankError = '';
                        });
                        Navigator.pop(context);
                        if (accountNumberCtrl.text.trim().length == 10) {
                          _verifyAccount();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Places ────────────────────────────────────────────────────────────────
  Future<bool> _confirmLeave() async {
    if (loading) return false;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Leave onboarding?",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          "Your progress won't be saved. You can complete this later from your profile.",
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Stay",
                style: TextStyle(color: _kTeal, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _handleLeave() {
    if (widget.onLeave != null) {
      widget.onLeave!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _searchPlaces(String input) async {
    if (input.length < 3) { setState(() => _placeSuggestions = []); return; }
    setState(() => _searchingPlaces = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_kGoogleApiKey'
        '&components=country:ng',
      );
      final res  = await http.get(url);
      final data = json.decode(res.body);
      if (data['status'] == 'OK') {
        setState(() {
          _placeSuggestions = List<Map<String, dynamic>>.from(
            data['predictions'].map((p) => {
              'placeId':     p['place_id'],
              'description': p['description'],
            }),
          );
        });
      } else {
        setState(() => _placeSuggestions = []);
      }
    } catch (_) {
      setState(() => _placeSuggestions = []);
    } finally {
      setState(() => _searchingPlaces = false);
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    setState(() {
      _placeSuggestions = [];
      locationSearchCtrl.text = description;
      _selectedPlaceLabel = description;
    });
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,address_components'
        '&key=$_kGoogleApiKey',
      );
      final res  = await http.get(url);
      final data = json.decode(res.body);
      if (data['status'] == 'OK') {
        final result     = data['result'];
        final lat        = result['geometry']['location']['lat'];
        final lng        = result['geometry']['location']['lng'];
        final components = result['address_components'] as List;
        String street = '', city = '', state = '', country = '';
        for (final c in components) {
          final types = List<String>.from(c['types']);
          if (types.contains('route'))                       street  = c['long_name'];
          if (types.contains('locality'))                    city    = c['long_name'];
          if (types.contains('administrative_area_level_1')) state   = c['long_name'];
          if (types.contains('country'))                     country = c['long_name'];
        }
        setState(() {
          _selectedLat    = lat.toDouble();
          _selectedLng    = lng.toDouble();
          streetCtrl.text  = street.isNotEmpty ? street : description;
          cityCtrl.text    = city;
          stateCtrl.text   = state;
          countryCtrl.text = country;
        });
      }
    } catch (_) {}
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> submit() async {
    if (businessCtrl.text.trim().isEmpty ||
        streetCtrl.text.trim().isEmpty ||
        cityCtrl.text.trim().isEmpty) {
      setState(() => error = "Please fill in all required fields");
      return;
    }
    if (_selectedBankCode == null) {
      setState(() => error = "Please select a bank");
      return;
    }
    if (accountNumberCtrl.text.trim().length != 10) {
      setState(() => error = "Enter a valid 10-digit account number");
      return;
    }
    if (!_verified) {
      setState(() => error = "Please verify your account number first");
      return;
    }
    if (MAPS_ENABLED && _selectedLat == null) {
      setState(() => error = "Please search and select your business location");
      return;
    }

    setState(() { loading = true; error = ''; });
    try {
      final body = {
        "businessName":  businessCtrl.text.trim(),
        "street":        streetCtrl.text.trim(),
        "city":          cityCtrl.text.trim(),
        "state":         stateCtrl.text.trim(),
        "country":       countryCtrl.text.trim(),
        "bankName":      _selectedBankName ?? "",
        "bankCode":      _selectedBankCode ?? "",
        "accountNumber": accountNumberCtrl.text.trim(),
        "accountName":   _resolvedAccountName ?? "",
        if (_selectedLat != null) "lat": _selectedLat,
        if (_selectedLng != null) "lng": _selectedLng,
      };
      final res = await ApiService.post("/vendors/onboard", body);
      if (!mounted) return;
      setState(() => loading = false);
      if (res["vendor"] != null || res["message"] == "Onboarding completed") {
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onCompleted();
      } else {
        setState(() => error = res["message"] ?? "Failed");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final leave = await _confirmLeave();
        if (leave && mounted) _handleLeave();
        return false;
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle:
              _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
            onPressed: () async {
              final leave = await _confirmLeave();
              if (leave && mounted) _handleLeave();
            },
          ),
          title: Text("Vendor Onboarding",
              style: TextStyle(
                  color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _kTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kTeal.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: _kTeal, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Fill in your business details to start receiving orders.",
                        style: TextStyle(color: _kTeal.withOpacity(0.85), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionHeader("Business Info", Icons.storefront_outlined),
              _field("Business Name *", businessCtrl),

              _sectionHeader("Address", Icons.location_on_outlined),
              if (MAPS_ENABLED) ...[
                _placesSearchField(),
                if (_selectedPlaceLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kTeal.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kTeal.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: _kTeal, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_selectedPlaceLabel,
                              style: const TextStyle(fontSize: 12, color: _kTeal))),
                        ],
                      ),
                    ),
                  ),
                _field("Street", streetCtrl, readOnly: true),
                _field("City", cityCtrl, readOnly: true),
                _field("State", stateCtrl, readOnly: true),
                _field("Country", countryCtrl, readOnly: true),
              ] else ...[
                _field("Street *", streetCtrl),
                _field("City *", cityCtrl),
                _field("State", stateCtrl),
                _field("Country", countryCtrl),
              ],

              // ── Bank Details ───────────────────────────────────────────────
              _sectionHeader("Bank Details", Icons.account_balance_outlined),

              // Bank selector
              GestureDetector(
                onTap: _banks.isEmpty ? null : _showBankPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedBankName ?? "Select bank *",
                          style: TextStyle(
                            color: _selectedBankName != null ? _text : _muted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _banks.isEmpty
                          ? SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _muted))
                          : Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                    ],
                  ),
                ),
              ),

              // Account number
              TextField(
                controller: accountNumberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                style: TextStyle(color: _text, fontSize: 14),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "Account Number *",
                  labelStyle: TextStyle(color: _muted, fontSize: 13),
                  counterText: "",
                  filled: true,
                  fillColor: _card,
                  suffixIcon: _verifying
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kTeal)),
                        )
                      : _verified
                          ? const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 20)
                          : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _verified
                          ? Colors.green.withOpacity(0.4)
                          : Colors.teal.withOpacity(0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _verified ? Colors.green : _kTeal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Resolved account name
              if (_resolvedAccountName != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_resolvedAccountName!,
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                ),

              // Bank error
              if (_bankError.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_bankError,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              if (error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _dark
                        ? Colors.red.withOpacity(0.12)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _dark
                            ? Colors.red.withOpacity(0.4)
                            : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: loading ? null : submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading ? _kTeal.withOpacity(0.5) : _kTeal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("Complete Onboarding",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placesSearchField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          TextField(
            controller: locationSearchCtrl,
            style: TextStyle(color: _text, fontSize: 14),
            onChanged: _searchPlaces,
            decoration: InputDecoration(
              labelText: "Search business location *",
              labelStyle: TextStyle(color: _muted, fontSize: 13),
              filled: true,
              fillColor: _card,
              suffixIcon: _searchingPlaces
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kTeal)),
                    )
                  : Icon(Icons.search, color: _muted),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.teal.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kTeal, width: 1.5),
              ),
            ),
          ),
          if (_placeSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.15)),
              ),
              child: Column(
                children: _placeSuggestions.map((place) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        color: _kTeal, size: 18),
                    title: Text(place['description'],
                        style: TextStyle(fontSize: 13, color: _text)),
                    onTap: () =>
                        _selectPlace(place['placeId'], place['description']),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? inputType, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        readOnly: readOnly,
        style: TextStyle(color: readOnly ? _muted : _text, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _muted, fontSize: 13),
          filled: true,
          fillColor: readOnly ? _readOnly : _card,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kTeal, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kTeal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kTeal, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}