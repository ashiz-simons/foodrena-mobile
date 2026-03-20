import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/verification_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  final Color accentColor;
  final VoidCallback? onVerified;

  const IdentityVerificationScreen({
    super.key,
    required this.accentColor,
    this.onVerified,
  });

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  String _selectedType = "nin";
  final _numberCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _successName;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);
  Color get _card => _dark ? const Color(0xFF1A1A1A) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _hint  => _dark ? Colors.grey.shade600 : Colors.grey.shade400;
  Color get _accent => widget.accentColor;

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final number = _numberCtrl.text.trim();
    if (number.isEmpty) {
      setState(() => _error = "Please enter your ID number");
      return;
    }

    final minLength = _selectedType == "nin" ? 11 : 8;
    if (number.length < minLength) {
      setState(() => _error =
          "${_selectedType == 'nin' ? 'NIN' : 'License'} must be at least $minLength characters");
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final res = await VerificationService.verifyIdentity(
        type:   _selectedType,
        number: number,
      );
      if (mounted) {
        setState(() {
          _successName = res["fullName"] ?? "Verified";
          _submitting  = false;
        });
        widget.onVerified?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error      = e.toString().replaceAll("Exception: ", "");
          _submitting = false;
        });
      }
    }
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
        title: Text("Identity Verification",
            style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user_rounded,
                        color: _accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Verify your identity",
                            style: TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          "We need to verify your identity to ensure the safety of our platform.",
                          style: TextStyle(
                              color: _muted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Success state ─────────────────────────────────
            if (_successName != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text("Identity Verified!",
                        style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(_successName!,
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Done",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── ID type selector ──────────────────────────────
              Text("Select ID Type",
                  style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _typeCard(
                    type: "nin",
                    label: "NIN",
                    subtitle: "National ID Number",
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(width: 12),
                  _typeCard(
                    type: "drivers_license",
                    label: "Driver's License",
                    subtitle: "FRSC issued license",
                    icon: Icons.drive_eta_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Number input ──────────────────────────────────
              Text(
                _selectedType == "nin"
                    ? "Enter your NIN"
                    : "Enter your License Number",
                style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numberCtrl,
                keyboardType: _selectedType == "nin"
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: _selectedType == "nin"
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ]
                    : [LengthLimitingTextInputFormatter(20)],
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                    fontSize: 16,
                    color: _text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: _selectedType == "nin"
                      ? "00000000000"
                      : "e.g. ABC123456789",
                  hintStyle: TextStyle(
                      color: _hint,
                      fontSize: 14,
                      letterSpacing: 1,
                      fontWeight: FontWeight.normal),
                  prefixIcon: Icon(
                    _selectedType == "nin"
                        ? Icons.numbers_rounded
                        : Icons.credit_card_rounded,
                    color: _accent,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: _accent.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: _accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),

              const SizedBox(height: 12),

              // ── Helper text ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _accent.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: _muted, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedType == "nin"
                            ? "Your 11-digit NIN from your National ID card or NIMC slip."
                            : "Your Driver's License number as printed on your FRSC card.",
                        style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Error ─────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          "Verify ${_selectedType == 'nin' ? 'NIN' : 'License'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeCard({
    required String type,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedType = type;
          _numberCtrl.clear();
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? _accent.withOpacity(0.08) : _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? _accent.withOpacity(0.5)
                  : _accent.withOpacity(0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  color: isSelected ? _accent : _muted, size: 22),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? _accent : _text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}