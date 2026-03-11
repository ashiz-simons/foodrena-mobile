import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/vendor_service.dart';

const _kBg      = Color(0xFFF0FAFA);
const _kCard    = Color(0xFFFFFFFF);
const _kCardAlt = Color(0xFFE0F7F7);
const _kTeal    = Color(0xFF00B4B4);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B8A8A);

class VendorBankScreen extends StatefulWidget {
  const VendorBankScreen({super.key});

  @override
  State<VendorBankScreen> createState() => _VendorBankScreenState();
}

class _VendorBankScreenState extends State<VendorBankScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _bankName     = TextEditingController();
  final _accountNumber = TextEditingController();
  final _accountName  = TextEditingController();

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  @override
  void dispose() {
    _bankName.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    super.dispose();
  }

  Future<void> _loadBank() async {
    try {
      final data = await VendorService.getBank();
      if (data != null) {
        _bankName.text      = data["bankName"]      ?? "";
        _accountNumber.text = data["accountNumber"] ?? "";
        _accountName.text   = data["accountName"]   ?? "";
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await VendorService.saveBank({
        "bankName":      _bankName.text.trim(),
        "accountNumber": _accountNumber.text.trim(),
        "accountName":   _accountName.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bank details saved"),
          backgroundColor: _kTeal,
        ),
      );
      Navigator.pop(context); // ← critical: return to wallet screen
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save bank details"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: _kText),
        title: const Text(
          "Bank Details",
          style: TextStyle(
              color: _kText, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: _kTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _kTeal.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: _kTeal, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Withdrawals will be sent to this account.",
                              style: TextStyle(
                                  color: _kTeal.withOpacity(0.85),
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _field(
                      label: "Bank Name",
                      controller: _bankName,
                      hint: "e.g. First Bank",
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: "Account Number",
                      controller: _accountNumber,
                      hint: "10-digit account number",
                      icon: Icons.numbers_rounded,
                      inputType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Required";
                        if (v.length != 10) return "Must be 10 digits";
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: "Account Name",
                      controller: _accountName,
                      hint: "Name on the account",
                      icon: Icons.person_outline_rounded,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _saving ? null : _save,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _saving
                                ? _kTeal.withOpacity(0.5)
                                : _kTeal,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text(
                                    "Save Bank Details",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? inputType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 14, color: _kText),
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        prefixIcon: Icon(icon, color: _kTeal, size: 18),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: _kTeal.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}