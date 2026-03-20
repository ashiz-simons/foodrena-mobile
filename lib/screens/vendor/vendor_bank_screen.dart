import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/vendor_service.dart';
import '../../services/api_service.dart';

const _kTeal = Color(0xFF00B4B4);

class VendorBankScreen extends StatefulWidget {
  const VendorBankScreen({super.key});

  @override
  State<VendorBankScreen> createState() => _VendorBankScreenState();
}

class _VendorBankScreenState extends State<VendorBankScreen> {
  final _accountNumberCtrl = TextEditingController();

  bool _loadingBanks    = true;
  bool _verifying       = false;
  bool _saving          = false;
  bool _loading         = true;

  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filteredBanks = [];
  Map<String, dynamic>? _selectedBank;
  String? _resolvedAccountName;
  String? _verifyError;
  final _bankSearchCtrl = TextEditingController();

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
  Color get _card => _dark ? const Color(0xFF0F2828) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);
  Color get _hint  => _dark ? Colors.grey.shade600 : const Color(0xFFBBBBBB);

  @override
  void initState() {
    super.initState();
    _init();
    _accountNumberCtrl.addListener(_onAccountNumberChanged);
  }

  @override
  void dispose() {
    _accountNumberCtrl.removeListener(_onAccountNumberChanged);
    _accountNumberCtrl.dispose();
    _bankSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadBanks(), _loadExisting()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBanks() async {
    try {
      final res = await ApiService.get("/payments/banks");
      if (res is List) {
        _banks = res.map((b) => Map<String, dynamic>.from(b)).toList();
        _filteredBanks = List.from(_banks);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingBanks = false);
  }

  void _filterBanks(String query) {
    setState(() {
      _filteredBanks = query.isEmpty
          ? List.from(_banks)
          : _banks
              .where((b) => b["name"]
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> _loadExisting() async {
    try {
      final data = await VendorService.getBank();
      if (data != null && data["accountNumber"] != null) {
        _accountNumberCtrl.text = data["accountNumber"] ?? "";
        _resolvedAccountName    = data["accountName"];
        // Pre-select bank if it matches
        if (_banks.isNotEmpty && data["bankName"] != null) {
          _selectedBank = _banks.firstWhere(
            (b) => b["name"] == data["bankName"],
            orElse: () => {"name": data["bankName"], "code": ""},
          );
        }
      }
    } catch (_) {}
  }

  void _showBankPicker() {
    _bankSearchCtrl.clear();
    _filteredBanks = List.from(_banks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: _card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text("Select Bank",
                    style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _bankSearchCtrl,
                  autofocus: true,
                  style: TextStyle(color: _text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search banks...",
                    hintStyle:
                        TextStyle(color: _hint, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _kTeal, size: 18),
                    filled: true,
                    fillColor: _dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (q) {
                    setSheet(() {
                      _filteredBanks = q.isEmpty
                          ? List.from(_banks)
                          : _banks
                              .where((b) => b["name"]
                                  .toString()
                                  .toLowerCase()
                                  .contains(q.toLowerCase()))
                              .toList();
                    });
                  },
                ),
              ),
              // Bank list
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredBanks.length,
                  itemBuilder: (_, i) {
                    final bank = _filteredBanks[i];
                    final isSelected =
                        _selectedBank?["code"] == bank["code"];
                    return ListTile(
                      title: Text(bank["name"],
                          style: TextStyle(
                              color: isSelected ? _kTeal : _text,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: _kTeal, size: 18)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedBank        = bank;
                          _resolvedAccountName = null;
                          _verifyError         = null;
                        });
                        Navigator.pop(ctx);
                        if (_accountNumberCtrl.text.length == 10) {
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

  void _onAccountNumberChanged() {
    final val = _accountNumberCtrl.text;
    if (val.length == 10 && _selectedBank != null) {
      _verifyAccount();
    } else if (val.length < 10) {
      setState(() {
        _resolvedAccountName = null;
        _verifyError = null;
      });
    }
  }

  Future<void> _verifyAccount() async {
    if (_selectedBank == null) return;
    final accountNumber = _accountNumberCtrl.text.trim();
    if (accountNumber.length != 10) return;

    setState(() {
      _verifying           = true;
      _resolvedAccountName = null;
      _verifyError         = null;
    });

    try {
      final res = await ApiService.get(
        "/payments/verify-account?account_number=$accountNumber&bank_code=${_selectedBank!["code"]}",
      );
      if (mounted) {
        setState(() {
          _resolvedAccountName = res["accountName"];
          _verifying           = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifyError = e.toString().replaceAll("Exception: ", "");
          _verifying   = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedBank == null) {
      _showError("Please select a bank");
      return;
    }
    if (_accountNumberCtrl.text.length != 10) {
      _showError("Account number must be 10 digits");
      return;
    }
    if (_resolvedAccountName == null) {
      _showError("Please verify your account number first");
      return;
    }

    setState(() => _saving = true);
    try {
      await VendorService.saveBank({
        "bankName":      _selectedBank!["name"],
        "accountNumber": _accountNumberCtrl.text.trim(),
        "accountName":   _resolvedAccountName,
        "bankCode":      _selectedBank!["code"],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Bank details saved"),
            backgroundColor: _kTeal),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: _text),
        title: Text("Bank Details",
            style: TextStyle(
                color: _text, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: _kTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kTeal.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _kTeal, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Your account will be verified automatically.",
                            style: TextStyle(
                                color: _kTeal.withOpacity(0.85),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bank selector ──────────────────────────────
                  Text("Bank",
                      style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _loadingBanks ? null : _showBankPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kTeal.withOpacity(
                                _dark ? 0.25 : 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              color: _kTeal, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _loadingBanks
                                ? Row(children: [
                                    const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _kTeal)),
                                    const SizedBox(width: 10),
                                    Text("Loading banks...",
                                        style: TextStyle(
                                            color: _hint, fontSize: 13)),
                                  ])
                                : Text(
                                    _selectedBank?["name"] ??
                                        "Select your bank",
                                    style: TextStyle(
                                        color: _selectedBank != null
                                            ? _text
                                            : _hint,
                                        fontSize: 13),
                                  ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: _muted, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Account number ─────────────────────────────
                  Text("Account Number",
                      style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _accountNumberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: TextStyle(fontSize: 14, color: _text),
                    decoration: InputDecoration(
                      hintText: "10-digit account number",
                      hintStyle:
                          TextStyle(color: _hint, fontSize: 13),
                      prefixIcon: const Icon(Icons.numbers_rounded,
                          color: _kTeal, size: 18),
                      suffixIcon: _verifying
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kTeal),
                              ),
                            )
                          : _resolvedAccountName != null
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 20)
                              : null,
                      filled: true,
                      fillColor: _card,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _kTeal.withOpacity(
                                _dark ? 0.25 : 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _kTeal, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Resolved account name ──────────────────────
                  if (_resolvedAccountName != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Account Verified",
                                    style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(_resolvedAccountName!,
                                    style: TextStyle(
                                        color: _text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_verifyError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_verifyError!,
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: _verifyAccount,
                            child: const Text("Retry",
                                style: TextStyle(
                                    color: _kTeal, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // ── Save button ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _resolvedAccountName != null
                              ? _kTeal
                              : _kTeal.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text("Save Bank Details",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}