import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/promo_service.dart';

const _kTeal = Color(0xFF00B4B4);

class VendorPromosScreen extends StatefulWidget {
  const VendorPromosScreen({super.key});

  @override
  State<VendorPromosScreen> createState() => _VendorPromosScreenState();
}

class _VendorPromosScreenState extends State<VendorPromosScreen> {
  bool _loading = true;
  List _promos  = [];

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg   => _dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
  Color get _card => _dark ? const Color(0xFF0F2828) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A1A);
  Color get _muted => _dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);
  Color get _border => _dark ? Colors.teal.withOpacity(0.18) : Colors.teal.withOpacity(0.12);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await PromoService.getVendorPromos();
      if (mounted) setState(() { _promos = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete promo?", style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        content: Text("This code will no longer work for customers.",
            style: TextStyle(color: _muted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: _muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PromoService.deleteVendorPromo(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")),
              backgroundColor: Colors.red));
      }
    }
  }

  void _showCreateDialog() {
    final codeCtrl    = TextEditingController();
    final percentCtrl = TextEditingController();
    final minCtrl     = TextEditingController();
    String type       = "percent";
    bool firstOnly    = false;
    DateTime? expiry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text("Create Promo Code",
                  style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),

              // Code
              _inputField(codeCtrl, "Promo Code (e.g. SAVE20)",
                  inputType: TextInputType.text,
                  onChanged: (v) => codeCtrl.text = v.toUpperCase()),

              const SizedBox(height: 12),

              // Type selector
              Text("Discount Type", style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _typeChip("percent", "% Off", type, (v) => setModalState(() => type = v)),
                  const SizedBox(width: 8),
                  _typeChip("free_delivery", "Free Delivery", type, (v) => setModalState(() => type = v)),
                ],
              ),

              if (type == "percent") ...[
                const SizedBox(height: 12),
                _inputField(percentCtrl, "Discount % (1–100)",
                    inputType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly]),
              ],

              const SizedBox(height: 12),
              _inputField(minCtrl, "Min. Order Amount (₦, leave blank for none)",
                  inputType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly]),

              const SizedBox(height: 12),
              // Expiry date picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (_, child) => Theme(
                      data: ThemeData(colorSchemeSeed: _kTeal),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModalState(() => expiry = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _dark ? const Color(0xFF163535) : const Color(0xFFE0F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kTeal.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _kTeal, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        expiry != null
                            ? "Expires: ${expiry!.toIso8601String().substring(0, 10)}"
                            : "Set expiry date (optional)",
                        style: TextStyle(color: expiry != null ? _text : _muted, fontSize: 13),
                      ),
                      if (expiry != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setModalState(() => expiry = null),
                          child: Icon(Icons.close, size: 14, color: _muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // First order only toggle
              GestureDetector(
                onTap: () => setModalState(() => firstOnly = !firstOnly),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: firstOnly ? _kTeal : Colors.transparent,
                        border: Border.all(color: firstOnly ? _kTeal : _muted.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: firstOnly
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text("First order only", style: TextStyle(color: _text, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    if (type == "percent") {
                      final p = int.tryParse(percentCtrl.text);
                      if (p == null || p < 1 || p > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Enter a valid discount % (1-100)"),
                              backgroundColor: Colors.red));
                        return;
                      }
                    }
                    try {
                      await PromoService.createVendorPromo({
                        "code":          code,
                        "type":          type,
                        if (type == "percent") "discountPercent": int.parse(percentCtrl.text),
                        "minOrder":      int.tryParse(minCtrl.text) ?? 0,
                        "firstOrderOnly": firstOnly,
                        if (expiry != null) "expiresAt": expiry!.toIso8601String(),
                      });
                      if (mounted) Navigator.pop(context);
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll("Exception: ", "")),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _kTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text("Create Promo",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

  Widget _typeChip(String value, String label, String current, ValueChanged<String> onTap) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _kTeal : _muted.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint,
      {TextInputType? inputType,
      List<TextInputFormatter>? formatters,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      inputFormatters: formatters,
      style: TextStyle(color: _text, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _dark ? const Color(0xFF163535) : const Color(0xFFE0F7F7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
      ),
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
        systemOverlayStyle: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Promo Codes",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add_circle_outline, color: _kTeal, size: 18),
            label: const Text("New", style: TextStyle(color: _kTeal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              color: _kTeal,
              onRefresh: _load,
              child: _promos.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.discount_outlined, size: 48, color: _muted.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              Text("No promo codes yet", style: TextStyle(color: _muted, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text("Tap New to create one", style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _promos.length,
                      itemBuilder: (_, i) => _promoCard(_promos[i]),
                    ),
            ),
    );
  }

  Widget _promoCard(Map p) {
    final code     = p["code"] ?? "";
    final type     = p["type"] ?? "";
    final pct      = p["discountPercent"];
    final minOrder = (p["minOrder"] ?? 0) as num;
    final firstOnly = p["firstOrderOnly"] == true;
    final expires  = p["expiresAt"] != null
        ? p["expiresAt"].toString().substring(0, 10)
        : null;

    final label = type == "percent" ? "$pct% off" : "Free delivery";
    final labelColor = type == "percent" ? Colors.purple : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.discount_rounded, color: _kTeal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(code,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _text,
                            letterSpacing: 1.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: labelColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(label,
                          style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (minOrder > 0)
                      Text("Min ₦$minOrder", style: TextStyle(fontSize: 11, color: _muted)),
                    if (firstOnly)
                      Text("First order", style: TextStyle(fontSize: 11, color: _muted)),
                    if (expires != null)
                      Text("Expires $expires", style: TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => _delete(p["_id"]),
          ),
        ],
      ),
    );
  }
}